#!/usr/bin/env python3
"""
cpa.py - Correlation Power Analysis on simulated Zkne S-box leakage.

Reads a CSV produced by tb_zkne_leak.sv (columns: idx,group,pt,hw,hd) and
recovers the hidden key byte by correlating a Hamming-weight leakage hypothesis
HW(sbox[pt ^ guess]) against the simulated power column, for all 256 guesses.

The testbench logs *clean* leakage; realistic measurement noise is added here
(--noise sigma) so we can show a traces-to-disclosure convergence curve rather
than a trivial single-trace break.

Examples:
    python3 cpa.py --csv ../out/cpa.csv --true 0x2b
    python3 cpa.py --csv ../out/cpa.csv --true 0x2b --noise 3.0 --model hw
"""
import argparse
import sys
import numpy as np

# AES forward S-box (FIPS 197) - identical to software/main.c and the RTL.
SBOX = np.array([
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
], dtype=np.uint8)

POPCOUNT = np.array([bin(x).count("1") for x in range(256)], dtype=np.float64)


def hamming_weight(vals):
    return POPCOUNT[np.asarray(vals, dtype=np.uint8)]


def load_csv(path):
    data = np.genfromtxt(path, delimiter=",", names=True, dtype=None, encoding="utf-8")
    return data


def correlate_all_guesses(pt, power):
    """Return |Pearson r| for each of the 256 key guesses (vectorised)."""
    # hypothesis matrix H: (n_traces, 256) = HW(sbox[pt ^ guess])
    guesses = np.arange(256, dtype=np.uint8)
    xored = np.bitwise_xor(pt[:, None].astype(np.uint8), guesses[None, :])  # (n,256)
    H = POPCOUNT[SBOX[xored]]                          # HW(sbox[pt ^ guess]) -> (n,256)
    # Pearson correlation of each column of H against power
    Hc = H - H.mean(axis=0, keepdims=True)
    pc = power - power.mean()
    num = Hc.T @ pc                                   # (256,)
    den = np.sqrt((Hc**2).sum(axis=0) * (pc**2).sum())
    den[den == 0] = np.nan
    return num / den


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--csv", required=True, help="trace CSV from tb_zkne_leak.sv")
    ap.add_argument("--model", choices=["hw", "hd"], default="hw",
                    help="power column to attack (default hw)")
    ap.add_argument("--noise", type=float, default=2.0,
                    help="Gaussian noise sigma added to power (default 2.0)")
    ap.add_argument("--true", default=None,
                    help="true key byte (hex 0x.. or int) for verification")
    ap.add_argument("--seed", type=int, default=0, help="noise RNG seed")
    ap.add_argument("--out", default=None, help="PNG prefix for plots (optional)")
    args = ap.parse_args()

    data = load_csv(args.csv)
    pt = np.asarray(data["pt"], dtype=np.uint8)
    power = np.asarray(data[args.model], dtype=np.float64)
    n = len(pt)
    print(f"loaded {n} traces from {args.csv}  (model={args.model})")

    rng = np.random.default_rng(args.seed)
    if args.noise > 0:
        power = power + rng.normal(0.0, args.noise, size=n)

    corr = correlate_all_guesses(pt, power)
    acorr = np.abs(corr)
    recovered = int(np.nanargmax(acorr))
    order = np.argsort(-acorr)

    print(f"\nRecovered key byte: 0x{recovered:02x}  (|r| = {acorr[recovered]:.4f})")
    print("Top 5 guesses by |correlation|:")
    for g in order[:5]:
        print(f"   0x{g:02x}  |r|={acorr[g]:.4f}  r={corr[g]:+.4f}")

    true = None
    if args.true is not None:
        true = int(args.true, 0)
        rank = int(np.where(order == true)[0][0]) + 1
        status = "RECOVERED ✓" if recovered == true else "NOT recovered ✗"
        print(f"\nTrue key byte: 0x{true:02x}  rank={rank}/256  |r|={acorr[true]:.4f}  -> {status}")

    # ---- traces-to-disclosure convergence ----
    checkpoints = np.unique(np.geomspace(max(50, n // 200), n, num=40).astype(int))
    ttd = None
    conv_true = []
    conv_maxwrong = []
    for cp in checkpoints:
        c = np.abs(correlate_all_guesses(pt[:cp], power[:cp]))
        top = int(np.nanargmax(c))
        if true is not None:
            conv_true.append(c[true])
            wrong = c.copy(); wrong[true] = -1
            conv_maxwrong.append(np.nanmax(wrong))
            if ttd is None and top == true:
                ttd = int(cp)
    if true is not None and ttd is not None:
        print(f"Traces to disclosure (first checkpoint where true is rank 1): ~{ttd}")
    elif true is not None:
        print("Traces to disclosure: not reached within this dataset "
              "(increase --num_traces or lower --noise)")

    if args.out:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, ax = plt.subplots(figsize=(9, 4))
        ax.vlines(range(256), 0, acorr, color="0.7", linewidth=0.8)
        if true is not None:
            ax.vlines(true, 0, acorr[true], color="tab:red", linewidth=2,
                      label=f"true key 0x{true:02x}")
        ax.vlines(recovered, 0, acorr[recovered], color="tab:green", linewidth=1.2,
                  linestyle="--", label=f"recovered 0x{recovered:02x}")
        ax.set_xlabel("key-byte guess"); ax.set_ylabel("|Pearson r|")
        ax.set_title(f"CPA correlation per guess (n={n}, noise σ={args.noise})")
        ax.legend()
        fig.tight_layout(); fig.savefig(f"{args.out}_corr_vs_guess.png", dpi=130)
        print(f"wrote {args.out}_corr_vs_guess.png")

        if true is not None and conv_true:
            fig, ax = plt.subplots(figsize=(9, 4))
            ax.plot(checkpoints[:len(conv_true)], conv_true, color="tab:red",
                    label="true key |r|")
            ax.plot(checkpoints[:len(conv_maxwrong)], conv_maxwrong, color="0.5",
                    label="max wrong-key |r|")
            if ttd:
                ax.axvline(ttd, color="tab:green", linestyle="--",
                           label=f"disclosure ~{ttd}")
            ax.set_xscale("log")
            ax.set_xlabel("number of traces"); ax.set_ylabel("|Pearson r|")
            ax.set_title("CPA convergence (traces to disclosure)")
            ax.legend()
            fig.tight_layout(); fig.savefig(f"{args.out}_convergence.png", dpi=130)
            print(f"wrote {args.out}_convergence.png")

    # exit non-zero if a true key was given and not recovered (handy in scripts)
    if true is not None and recovered != true:
        sys.exit(1)


if __name__ == "__main__":
    main()
