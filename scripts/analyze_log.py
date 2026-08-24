#!/usr/bin/env python3
"""Plot, summarize, and (optionally) build an interactive HTML report from a
Shredometer datalog CSV (DL_N.TXT) pulled off the SD card."""

import argparse
import json
import os
import sys

import matplotlib.pyplot as plt
import pandas as pd

G = 9.8  # matches the firmware's shred score calculation
N_BUCKETS = 2400
TEMPLATE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "report_template.html")


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
    if show:
        plt.show()


def _bucket_rows(df, n_buckets=N_BUCKETS):
    t = df["Time (s)"]
    t0 = t.iloc[0]
    span = float(t.iloc[-1] - t0) or 1.0
    idx = ((t - t0) / span * n_buckets).astype(int).clip(upper=n_buckets - 1)

    buckets = []
    for _, g in df.groupby(idx):
        buckets.append({
            "t": round(float(g["Time (s)"].mean() - t0), 1),
            "axMin": round(float(g["Accel X (m/s^2)"].min()), 2),
            "axMax": round(float(g["Accel X (m/s^2)"].max()), 2),
            "axMean": round(float(g["Accel X (m/s^2)"].mean()), 2),
            "ayMin": round(float(g["Accel Y (m/s^2)"].min()), 2),
            "ayMax": round(float(g["Accel Y (m/s^2)"].max()), 2),
            "ayMean": round(float(g["Accel Y (m/s^2)"].mean()), 2),
            "azMin": round(float(g["Accel Z (m/s^2)"].min()), 2),
            "azMax": round(float(g["Accel Z (m/s^2)"].max()), 2),
            "azMean": round(float(g["Accel Z (m/s^2)"].mean()), 2),
            "shredMin": round(float(g["Shred Score"].min()), 3),
            "shredMax": round(float(g["Shred Score"].max()), 3),
            "shredMean": round(float(g["Shred Score"].mean()), 3),
        })
    return buckets


def _minute_table(df):
    t = df["Time (s)"]
    minute_idx = ((t - t.iloc[0]) // 60).astype(int)

    table = []
    for minute, g in df.groupby(minute_idx):
        mag = (
            g["Accel X (m/s^2)"] ** 2 + g["Accel Y (m/s^2)"] ** 2 + g["Accel Z (m/s^2)"] ** 2
        ) ** 0.5
        table.append({
            "minute": int(minute),
            "n": int(len(g)),
            "shredMax": round(float(g["Shred Score"].max()), 2),
            "shredMean": round(float(g["Shred Score"].mean()), 2),
            "accelMeanMag": round(float(mag.mean()), 2),
        })
    return table


def build_report_data(df, source_name, accel_range_g):
    t = df["Time (s)"]
    duration = float(t.iloc[-1] - t.iloc[0])
    samples = len(df)
    rate = samples / duration if duration > 0 else 0.0

    peak_idx = df["Shred Score"].idxmax()
    max_shred = float(df["Shred Score"].max())
    peak_time = float(t.loc[peak_idx] - t.iloc[0])
    mean_shred = float(df["Shred Score"].mean())

    clip_ceiling = accel_range_g * G
    clipped = bool(
        (df["Accel X (m/s^2)"].abs() >= clip_ceiling * 0.995).any()
        or (df["Accel Y (m/s^2)"].abs() >= clip_ceiling * 0.995).any()
        or (df["Accel Z (m/s^2)"].abs() >= clip_ceiling * 0.995).any()
    )

    return {
        "meta": {
            "sourceFile": source_name,
            "accelRangeG": accel_range_g,
            "clipped": clipped,
        },
        "summary": {
            "totalSamples": samples,
            "durationS": round(duration, 1),
            "sampleRateHz": round(rate, 2),
            "maxShred": round(max_shred, 3),
            "meanShred": round(mean_shred, 3),
            "peakTimeS": round(peak_time, 1),
        },
        "buckets": _bucket_rows(df),
        "table": _minute_table(df),
    }


def write_html_report(df, logfile, accel_range_g, output_path):
    data = build_report_data(df, os.path.basename(logfile), accel_range_g)
    with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
        template = f.read()
    html = template.replace("%%CHART_DATA%%", json.dumps(data, separators=(",", ":")))
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Saved HTML report to {output_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logfile", help="Path to a DL_N.TXT log file")
    parser.add_argument("-o", "--output", help="Save a static PNG plot to this file")
    parser.add_argument("--show", action="store_true", help="Show the PNG plot in a window")
    parser.add_argument("-H", "--html", help="Write an interactive HTML report to this file")
    parser.add_argument(
        "--accel-range", type=float, default=4.0, dest="accel_range",
        help="Accelerometer full-scale range in g. Used for clip detection and the "
             "HTML report's reference line. Default 4, matching the sketch's "
             "LSM9DS1_ACCELRANGE_4G setting.",
    )
    args = parser.parse_args()

    try:
        df = load_log(args.logfile)
    except FileNotFoundError:
        sys.exit(f"No such file: {args.logfile}")

    summarize(df)

    # Default to the old interactive-window behavior only when nothing else
    # was requested, so `--html` alone doesn't also pop up a plot window.
    show_window = args.show or (not args.output and not args.html)
    if args.output or show_window:
        plot(df, output=args.output, show=show_window)

    if args.html:
        write_html_report(df, args.logfile, args.accel_range, args.html)


if __name__ == "__main__":
    main()
