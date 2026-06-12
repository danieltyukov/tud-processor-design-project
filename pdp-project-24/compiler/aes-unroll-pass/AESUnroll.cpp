//===- AESUnroll.cpp - Force-unroll the AES round loop --------------------===//
//
// Out-of-tree LLVM plugin (new pass manager).
//
// Finds the AES round loop in the Zkne software and fully unrolls it by calling
// the LLVM UnrollLoop() utility directly. The loop is identified robustly --
// independent of inlining or function names -- as any natural loop whose body
// contains an inline-assembly call (the aes32esmi / aes32esi ".word" encodings
// emitted by hw_aes32esmi() / hw_aes32esi() in main.c).
//
// The pass is registered at the LoopOptimizerEnd extension point, so by the
// time it runs the loop is already in simplified + rotated + LCSSA form with a
// computable constant trip count -- exactly the preconditions UnrollLoop()
// expects. This means we drive the unroll ourselves; the built-in
// LoopFullUnrollPass / -funroll-loops cost model never makes the decision.
//
// IMPORTANT: the loop pipeline and EP callbacks only run at -O1/-O2/-Os, NOT at
// -O0. Compile the target translation unit at -Os (as the project does).
//
//   build:
//     cmake -S . -B build -G Ninja \
//           -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm \
//           -DCMAKE_CXX_COMPILER=clang++
//     cmake --build build
//
//   use:
//     clang ... -Os -fpass-plugin=build/libAESUnroll.so -c main.c -o main.o
//
//===----------------------------------------------------------------------===//

#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/OptimizationRemarkEmitter.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Scalar/LoopPassManager.h"
#include "llvm/Transforms/Utils/UnrollLoop.h"

using namespace llvm;

namespace {

// True if any instruction in the loop body is an inline-asm call. In the Zkne
// AES code this uniquely marks the aes32esmi/aes32esi round loop: the software
// reference loops (SubBytes/ShiftRows/MixColumns/key expansion) contain no
// inline asm, and the final round is straight-line (no loop).
bool loopHasInlineAsm(const Loop &L) {
  for (const BasicBlock *BB : L.blocks())
    for (const Instruction &I : *BB)
      if (const auto *CB = dyn_cast<CallBase>(&I))
        if (CB->isInlineAsm())
          return true;
  return false;
}

struct AESUnrollPass : PassInfoMixin<AESUnrollPass> {
  PreservedAnalyses run(Loop &L, LoopAnalysisManager &AM,
                        LoopStandardAnalysisResults &AR, LPMUpdater &U) {
    Function &F = *L.getHeader()->getParent();

    // Only target the AES round loop.
    if (!loopHasInlineAsm(L))
      return PreservedAnalyses::all();

    // UnrollLoop() requires simplified form and a known constant trip count.
    if (!L.isLoopSimplifyForm())
      return PreservedAnalyses::all();

    unsigned TripCount = AR.SE.getSmallConstantTripCount(&L);
    if (TripCount == 0)
      return PreservedAnalyses::all();

    // Full unroll: Count == trip count, Force past the cost model.
    UnrollLoopOptions ULO;
    ULO.Count = TripCount;
    ULO.Force = true;
    ULO.Runtime = false;
    ULO.AllowExpensiveTripCount = false;
    ULO.UnrollRemainder = false;
    ULO.ForgetAllSCEV = false;

    OptimizationRemarkEmitter ORE(&F);
    Loop *RemainderLoop = nullptr;
    const std::string Name = L.getName().str();

    LoopUnrollResult Res =
        UnrollLoop(&L, ULO, &AR.LI, &AR.SE, &AR.DT, &AR.AC, &AR.TTI, &ORE,
                   /*PreserveLCSSA=*/true, &RemainderLoop, &AR.AA);

    if (Res == LoopUnrollResult::Unmodified)
      return PreservedAnalyses::all();

    errs() << "[AESUnroll] fully unrolled AES loop '" << Name << "' (x"
           << TripCount << ") in function '" << F.getName() << "'\n";

    // On a full unroll the loop no longer exists; tell the loop pass manager.
    if (Res == LoopUnrollResult::FullyUnrolled)
      U.markLoopAsDeleted(L, Name);

    return getLoopPassPreservedAnalyses();
  }
};

} // namespace

llvm::PassPluginLibraryInfo getAESUnrollPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "AESUnroll", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerLoopOptimizerEndEPCallback(
                [](LoopPassManager &LPM, OptimizationLevel /*Level*/) {
                  LPM.addPass(AESUnrollPass());
                });
          }};
}

// Entry point clang/opt look up when loading the plugin.
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getAESUnrollPluginInfo();
}
