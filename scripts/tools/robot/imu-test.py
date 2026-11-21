#!/usr/bin/env python3
"""IMU diagnostic test, reading live data from an MPU6050 over I2C - mirrors mecha10-nodes'
own `imu` crate's real hardware controller defaults exactly (bus `/dev/i2c-1`, address `0x68`,
gyro scale +/-250 deg/s, accel scale +/-2g), so this is the real hardware path, not an
approximation. Requires the `smbus2` package (`pip install smbus2` or the `python3-smbus2`/
`python3-smbus` apt package) and I2C enabled on the Pi (`dtparam=i2c_arm=on` in
/boot/firmware/config.txt, or run `first-boot.sh`). If detection is uncertain, run
`i2c-test.sh` first to confirm the device is seen and on the expected bus/address.

Usage:
    ./scripts/tools/robot/imu-test.py
    ./scripts/tools/robot/imu-test.py --bus 1 --address 0x68 --rate 10 --duration 5
    ./scripts/tools/robot/imu-test.py --duration 0   # run until Ctrl+C
"""

import argparse
import sys
import time

PWR_MGMT_1 = 0x6B
WHO_AM_I = 0x75
ACCEL_XOUT_H = 0x3B
EXPECTED_WHO_AM_I = 0x68

ACCEL_SCALE = 16384.0
GYRO_SCALE = 131.0


def to_signed16(high: int, low: int) -> int:
    value = (high << 8) | low
    return value - 65536 if value & 0x8000 else value


def parse_address(value: str) -> int:
    return int(value, 0)


def main():
    p = argparse.ArgumentParser(description="MPU6050 IMU diagnostic test over I2C")
    p.add_argument("--bus", type=int, default=1, help="I2C bus number, e.g. 1 for /dev/i2c-1 (default: 1)")
    p.add_argument("--address", type=parse_address, default=0x68, help="I2C address, hex or decimal (default: 0x68)")
    p.add_argument("--rate", type=float, default=10, help="samples per second to print (default: 10)")
    p.add_argument("--duration", type=float, default=5, help="seconds to run, 0 = until Ctrl+C (default: 5)")
    args = p.parse_args()

    try:
        from smbus2 import SMBus
    except ImportError:
        print(
            "error: the 'smbus2' package is required but not installed.\n"
            "Install it with: pip install smbus2\n"
            "or on Debian/Raspberry Pi OS: sudo apt install python3-smbus2 (or python3-smbus)",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        bus = SMBus(args.bus)
    except FileNotFoundError:
        print(
            f"error: I2C bus {args.bus} (/dev/i2c-{args.bus}) not found.\n"
            "Check that I2C is enabled (dtparam=i2c_arm=on) and the bus number is correct.\n"
            "Run i2c-test.sh first to confirm detection and the correct bus/address.",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        try:
            bus.write_byte_data(args.address, PWR_MGMT_1, 0x00)
        except OSError:
            print(
                f"error: no device acknowledged at address {hex(args.address)} on bus {args.bus} - "
                "check wiring and run i2c-test.sh first to confirm detection and the correct bus/address.",
                file=sys.stderr,
            )
            sys.exit(1)

        who_am_i = bus.read_byte_data(args.address, WHO_AM_I)
        if who_am_i != EXPECTED_WHO_AM_I:
            print(
                f"warning: WHO_AM_I returned {hex(who_am_i)}, expected {hex(EXPECTED_WHO_AM_I)} "
                "for a genuine MPU6050 - continuing anyway (some clone boards report a different value)",
                file=sys.stderr,
            )

        period = 1.0 / args.rate if args.rate > 0 else 0
        end_time = time.monotonic() + args.duration if args.duration > 0 else None

        print(f"reading MPU6050 on bus {args.bus} at address {hex(args.address)} ({args.rate} Hz)...")

        while end_time is None or time.monotonic() < end_time:
            try:
                data = bus.read_i2c_block_data(args.address, ACCEL_XOUT_H, 14)
            except OSError:
                print(
                    f"error: no device acknowledged at address {hex(args.address)} on bus {args.bus} - "
                    "check wiring and run i2c-test.sh first to confirm detection and the correct bus/address.",
                    file=sys.stderr,
                )
                sys.exit(1)

            accel_x = to_signed16(data[0], data[1]) / ACCEL_SCALE
            accel_y = to_signed16(data[2], data[3]) / ACCEL_SCALE
            accel_z = to_signed16(data[4], data[5]) / ACCEL_SCALE
            temp_raw = to_signed16(data[6], data[7])
            gyro_x = to_signed16(data[8], data[9]) / GYRO_SCALE
            gyro_y = to_signed16(data[10], data[11]) / GYRO_SCALE
            gyro_z = to_signed16(data[12], data[13]) / GYRO_SCALE
            temp_c = temp_raw / 340.0 + 36.53

            print(
                f"accel(g): x={accel_x:+.3f} y={accel_y:+.3f} z={accel_z:+.3f}  "
                f"gyro(deg/s): x={gyro_x:+7.2f} y={gyro_y:+7.2f} z={gyro_z:+7.2f}  "
                f"temp: {temp_c:.1f}C"
            )

            if period:
                time.sleep(period)
    except KeyboardInterrupt:
        print()
    finally:
        bus.close()


if __name__ == "__main__":
    main()
