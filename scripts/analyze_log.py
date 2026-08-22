#!/usr/bin/env python3
"""Plot and summarize a Shredometer datalog CSV (DL_N.TXT) from the SD card."""

import argparse
import sys

import matplotlib.pyplot as plt
import pandas as pd

G = 9.8  # matches the firmware's shred score calculation


def load_log(path):
    df = pd.read_csv(path, skipinitialspace=True)
    df.columns = df.columns.str.strip()
    df["Time (s)"] = df["Time Elapsed (ms)"] / 1000.0
    df["Shred Score"] = (
        df["Accel X (m/s^2)"] ** 2
        + df["Accel Y (m/s^2)"] ** 2
        + df["Accel Z (m/s^2)"] ** 2
    ) ** 0.5 / G
    return df


def summarize(df):
    duration = df["Time (s)"].iloc[-1] - df["Time (s)"].iloc[0]
    print(f"Samples:        {len(df)}")
    print(f"Duration:       {duration:.1f} s ({duration / 60:.1f} min)")
    print(f"Sample rate:    {len(df) / duration:.1f} Hz" if duration > 0 else "")
    print(f"Max shred score: {df['Shred Score'].max():.2f} g")
    print(f"Mean shred score: {df['Shred Score'].mean():.2f} g")


def plot(df, output=None, show=False):
    fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True, figsize=(10, 6))

    ax1.plot(df["Time (s)"], df["Accel X (m/s^2)"], label="X")
    ax1.plot(df["Time (s)"], df["Accel Y (m/s^2)"], label="Y")
    ax1.plot(df["Time (s)"], df["Accel Z (m/s^2)"], label="Z")
    ax1.set_ylabel("Acceleration (m/s^2)")
    ax1.legend(loc="upper right")
    ax1.set_title("Acceleration")

    ax2.plot(df["Time (s)"], df["Shred Score"], color="tab:red")
    ax2.set_ylabel("Shred score (g)")
    ax2.set_xlabel("Time (s)")
    ax2.set_title("Shred score")

    fig.tight_layout()

    if output:
        fig.savefig(output, dpi=150)
        print(f"Saved plot to {output}")
    if show or not output:
        plt.show()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logfile", help="Path to a DL_N.TXT log file")
    parser.add_argument("-o", "--output", help="Save plot to this file instead of/as well as showing it")
    parser.add_argument("--show", action="store_true", help="Show the plot even if --output is given")
    args = parser.parse_args()

    try:
        df = load_log(args.logfile)
    except FileNotFoundError:
        sys.exit(f"No such file: {args.logfile}")

    summarize(df)
    plot(df, output=args.output, show=args.show)


if __name__ == "__main__":
    main()
