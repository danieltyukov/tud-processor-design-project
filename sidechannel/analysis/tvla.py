#!/usr/bin/env python3
"""
tvla.py - Test Vector Leakage Assessment (Welch t-test) on simulated leakage.

Reads a CSV produced by tb_zkne_leak.sv in TVLA mode (+tvla=1), which tags each
trace as group 0 (random plaintext) or group 1 (fixed plaintext). Performs the
non-specific fixed-vs-random Welch t-test on the power column. |t| > 4.5 is the
conventional threshold for "leakage detected" (ISO/IEC 17825, TVLA).

This is the metric we use before/after DOM: the unprotected module should blow
past 4.5; the DOM-protected module should stay under it.

Examples:
    python3 tvla.py --csv ../out/tvla.csv
    python3 tvla.py --csv ../out/tvla.csv --model hw --noise 2.0 --out ../out/tvla
"""
import argparse
import numpy as np
from scipy import stats


def load_csv(path):
    return np.genfromtxt(path, delimiter=",", names=True, dtype=None, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--csv", required=True, help="TVLA trace CSV (tb run with +tvla=1)")
    ap.add_argument("--model", choices=["hw", "hd"], default="hw")
    ap.add_argument("--noise", type=float, default=2.0,
                    help="Gaussian noise sigma added to power (default 2.0)")
    ap.add_argument("--threshold", type=float, default=4.5)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--out", default=None, help="PNG prefix for the t-curve plot")
    args = ap.parse_args()

    d = load_csv(args.csv)
    group = np.asarray(d["group"], dtype=int)
    power = np.asarray(d[args.model], dtype=np.float64)
    n = len(group)

    if set(np.unique(group).tolist()) != {0, 1}:
        raise SystemExit("CSV has no fixed/random groups - run the TB with +tvla=1")

    rng = np.random.default_rng(args.seed)
    if args.noise > 0:
        power = power + rng.normal(0.0, args.noise, size=n)

    rand = power[group == 0]
    fixed = power[group == 1]
    t, p = stats.ttest_ind(fixed, rand, equal_var=False)  # Welch
    leak = abs(t) > args.threshold

    print(f"loaded {n} traces ({len(fixed)} fixed, {len(rand)} random)  model={args.model}")
    print(f"Welch t = {t:+.3f}  (|t| {'>' if leak else '<='} {args.threshold})")
    print("RESULT: " + ("LEAKAGE DETECTED ✗ (design is NOT first-order secure)"
                        if leak else "no first-order leakage detected ✓"))

    # ---- |t| vs number-of-traces curve (how fast leakage appears) ----
    checkpoints = np.unique(np.geomspace(max(50, n // 200), n, num=40).astype(int))
    tcurve = []
    for cp in checkpoints:
        g = group[:cp]; pw = power[:cp]
        f = pw[g == 1]; r = pw[g == 0]
        if len(f) > 1 and len(r) > 1:
            tc, _ = stats.ttest_ind(f, r, equal_var=False)
            tcurve.append(abs(tc))
        else:
            tcurve.append(0.0)

    if args.out:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(9, 4))
        ax.plot(checkpoints, tcurve, color="tab:blue", label="|t|")
        ax.axhline(args.threshold, color="tab:red", linestyle="--",
                   label=f"threshold {args.threshold}")
        ax.set_xscale("log")
        ax.set_xlabel("number of traces"); ax.set_ylabel("|Welch t|")
        ax.set_title(f"TVLA fixed-vs-random (model={args.model}, noise σ={args.noise})")
        ax.legend()
        fig.tight_layout(); fig.savefig(f"{args.out}_tcurve.png", dpi=130)
        print(f"wrote {args.out}_tcurve.png")


if __name__ == "__main__":
    main()
