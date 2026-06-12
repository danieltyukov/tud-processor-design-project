cmake_minimum_required(VERSION 3.20)
project(AESUnroll LANGUAGES CXX)

# Locate the LLVM install. Pass -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
find_package(LLVM REQUIRED CONFIG)
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION} (LLVM_DIR=${LLVM_DIR})")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build the pass as a loadable module (-fpass-plugin / -load-pass-plugin).
add_library(AESUnroll MODULE AESUnroll.cpp)

target_include_directories(AESUnroll SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND "${LLVM_DEFINITIONS}")
target_compile_definitions(AESUnroll PRIVATE ${LLVM_DEFINITIONS_LIST})

# Match LLVM's RTTI setting (upstream/Ubuntu LLVM is built with -fno-rtti).
if(NOT LLVM_ENABLE_RTTI)
  target_compile_options(AESUnroll PRIVATE -fno-rtti)
endif()

# Produce libAESUnroll.so (MODULE libs allow undefined LLVM symbols on Linux;
# they are resolved by the host clang/opt at load time).
set_target_properties(AESUnroll PROPERTIES PREFIX "lib")
