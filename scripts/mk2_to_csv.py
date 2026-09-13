#!/usr/bin/env python3
"""Convert a Shredometer Mk2 binary log (MK2_NNN.BIN) to the CSV format
the existing analysis reads, so analyze_log.py and the reports run on the
new data unchanged.

    python3 scripts/mk2_to_csv.py data/MK2_000.BIN            # writes data/MK2_000.TXT
    python3 scripts/mk2_to_csv.py data/MK2_000.BIN -o out.csv
    python3 scripts/mk2_to_csv.py data/MK2_000.BIN --smooth 4 --offset 0.31,0.27,-0.38

Rows are the ADXL375 samples at the sensor's own rate. Gyro columns carry
the most recent LSM6DS3 reading (about 104 Hz), held between readings.
Magnetometer columns are zero: Mk2 has none. "Peak |a|" is the magnitude
of the row itself and "Burst Samples" is 1, since nothing is oversampled
any more; the per-row peak the Mk1 firmware computed is now just the data.

--smooth N averages the accelerometer over N consecutive samples before
writing, which cuts the ADXL375's noise by about sqrt(N) at the cost of
bandwidth. --offset x,y,z (in g) subtracts a zero-g trim.
"""
import argparse
import math
import os
import struct
import sys

HEADER = struct.Struct("<8sHHHHfffffI")
REC = struct.Struct("<BBhhh")
REC_ADXL, REC_GYRO, REC_IMUACC, REC_TIME = 0, 1, 2, 3
G = 9.80665
COLUMNS = [
    "Time Elapsed (ms)",
    "Accel X (m/s^2)", "Accel Y (m/s^2)", "Accel Z (m/s^2)",
    "Mag X (uT)", "Mag Y (uT)", "Mag Z (uT)",
    "Gyro X (rad/s)", "Gyro Y (rad/s)", "Gyro Z (rad/s)",
    "Peak |a| (m/s^2)", "Burst Samples",
]


def parse(path):
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 512:
        sys.exit(f"{path}: too short to be a log")
    magic, version, rec_size, sector_size, _, odr, g_lsb, dps_lsb, imu_g_lsb, imu_hz, start_ms = HEADER.unpack_from(data, 0)
    if magic.rstrip(b"\0") != b"SHRDMK2":
        sys.exit(f"{path}: bad magic {magic!r}")
    if rec_size != REC.size:
        sys.exit(f"{path}: record size {rec_size}, expected {REC.size}")
    info = dict(version=version, odr=odr, g_per_lsb=g_lsb, dps_per_lsb=dps_lsb,
                imuacc_g_per_lsb=imu_g_lsb, imu_hz=imu_hz, start_ms=start_ms)

    samples = []          # (t_ms, ax, ay, az) in g
    gyro = []             # (t_ms, gx, gy, gz) in dps
    imuacc = []           # (t_ms, x, y, z) in g
    overruns = 0
    expected_seq = 0
    sectors = 0
    n = len(data) // sector_size
    for s in range(1, n):
        base = s * sector_size
        t, flags, a, b, c = REC.unpack_from(data, base)
        if t != REC_TIME:
            break                      # ran into pre-allocated space
        sec_ms = (a & 0xFFFF) | ((b & 0xFFFF) << 16)
        seq = c & 0xFFFF
        if seq != expected_seq:
            break                      # stale data from an older log
        expected_seq = (seq + 1) & 0xFFFF
        overruns += flags
        sectors += 1
        k = 0                          # ADXL samples since the marker
        for r in range(1, sector_size // rec_size):
            t, flags, a, b, c = REC.unpack_from(data, base + r * rec_size)
            if t == REC_ADXL:
                t_ms = sec_ms + k * 1000.0 / odr
                k += 1
                samples.append((t_ms, a * g_lsb, b * g_lsb, c * g_lsb))
            elif t == REC_GYRO:
                gyro.append((sec_ms + k * 1000.0 / odr, a * dps_lsb, b * dps_lsb, c * dps_lsb))
            elif t == REC_IMUACC:
                imuacc.append((sec_ms + k * 1000.0 / odr, a * imu_g_lsb, b * imu_g_lsb, c * imu_g_lsb))
            elif t == REC_TIME:
                break
            # zero padding at the end of a final, partial sector: type 0 with
            # all-zero payload is indistinguishable from a sample, but the
            # logger drops all-zero samples, so treat them as padding.
    samples = [x for x in samples if not (x[1] == 0 and x[2] == 0 and x[3] == 0)]
    info.update(sectors=sectors, overruns=overruns)
    return info, samples, gyro, imuacc


def write_csv(out, info, samples, gyro, smooth, offset):
    t0 = samples[0][0] if samples else 0
    gi = 0
    last_g = (0.0, 0.0, 0.0)
    window = []
    with open(out, "w", newline="") as f:
        f.write(",".join(COLUMNS) + "\n")
        for (t, ax, ay, az) in samples:
            ax -= offset[0]; ay -= offset[1]; az -= offset[2]
            if smooth > 1:
                window.append((ax, ay, az))
                if len(window) > smooth:
                    window.pop(0)
                ax = sum(w[0] for w in window) / len(window)
                ay = sum(w[1] for w in window) / len(window)
                az = sum(w[2] for w in window) / len(window)
            while gi < len(gyro) and gyro[gi][0] <= t:
                last_g = gyro[gi][1:]
                gi += 1
            mx, my, mz = ax * G, ay * G, az * G
            mag = math.sqrt(mx * mx + my * my + mz * mz)
            gx, gy, gz = (math.radians(v) for v in last_g)
            f.write(f"{t - t0:.3f},{mx:.4f},{my:.4f},{mz:.4f},0,0,0,{gx:.5f},{gy:.5f},{gz:.5f},{mag:.4f},1\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log")
    ap.add_argument("-o", "--out")
    ap.add_argument("--smooth", type=int, default=1, help="moving average length in samples (default 1, raw)")
    ap.add_argument("--offset", default="0,0,0", help="zero-g trim to subtract, in g, as x,y,z")
    args = ap.parse_args()
    offset = tuple(float(v) for v in args.offset.split(","))
    if len(offset) != 3:
        sys.exit("--offset needs three values")
    out = args.out or os.path.splitext(args.log)[0] + ".TXT"

    info, samples, gyro, imuacc = parse(args.log)
    if not samples:
        sys.exit(f"{args.log}: no samples")
    dur = (samples[-1][0] - samples[0][0]) / 1000.0
    print(f"{args.log}: {info['sectors']} sectors, {len(samples)} accel samples over {dur:.1f} s "
          f"({len(samples) / dur if dur else 0:.0f} Hz), {len(gyro)} gyro samples, "
          f"{info['overruns']} FIFO overruns")
    write_csv(out, info, samples, gyro, args.smooth, offset)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
