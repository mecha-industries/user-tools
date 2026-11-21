#!/usr/bin/env python3
"""Servo sweep test, driven over the kernel's PWM-chip sysfs interface
(/sys/class/pwm/pwmchip<N>/pwm<M>/...) - mirrors mecha10-work's own
packages/drivers/servo/src/pwm_chip.rs exactly, so this is the real hardware-PWM path, not
lgpio's software-timed pulse train. Requires the PWM channel's device-tree overlay to already be
enabled (e.g. `dtoverlay=pwm-2chan` in /boot/firmware/config.txt on a Pi) and each pwm<M> to be
unexported before this runs.
"""

import argparse
import itertools
import time
from pathlib import Path

MID_US = 1500
PERIOD_NS = 20_000_000


class PwmChannel:
    def __init__(self, chip: int, channel: int):
        self.chip_path = Path(f"/sys/class/pwm/pwmchip{chip}")
        self.channel_path = self.chip_path / f"pwm{channel}"
        self.channel = channel

    def start(self):
        if not self.channel_path.exists():
            (self.chip_path / "export").write_text(str(self.channel))
            for _ in range(50):
                if self.channel_path.exists():
                    break
                time.sleep(0.01)
        (self.channel_path / "period").write_text(str(PERIOD_NS))
        (self.channel_path / "duty_cycle").write_text("0")
        (self.channel_path / "enable").write_text("1")

    def set_pulse_us(self, pulse_us: int):
        (self.channel_path / "duty_cycle").write_text(str(pulse_us * 1000))

    def stop(self):
        try:
            (self.channel_path / "enable").write_text("0")
        finally:
            (self.chip_path / "unexport").write_text(str(self.channel))


def parse_channel(spec: str) -> tuple[int, int]:
    chip, channel = spec.split(":")
    return int(chip), int(channel)


def main():
    p = argparse.ArgumentParser(description="Servo sweep test over real hardware PWM: mid -> max -> min -> mid")
    p.add_argument(
        "--channels",
        type=parse_channel,
        nargs="+",
        default=[(0, 0), (0, 1)],
        metavar="CHIP:CHANNEL",
        help="pwmchip:channel pairs, e.g. 0:0 0:1 (default matches GPIO12/13 under the pwm-2chan overlay)",
    )
    p.add_argument("--min-us", type=int, default=600)
    p.add_argument("--max-us", type=int, default=2400)
    p.add_argument("--duration", type=float, default=2.0)
    p.add_argument("--tick", type=float, default=0.02)
    p.add_argument("--settle", type=float, default=0.3)
    args = p.parse_args()

    channels = [PwmChannel(chip, channel) for chip, channel in args.channels]
    for ch in channels:
        ch.start()

    def move(us):
        for ch in channels:
            ch.set_pulse_us(us)

    targets = [MID_US, args.max_us, args.min_us, MID_US]
    segment = args.duration / (len(targets) - 1)
    ticks = max(1, int(segment / args.tick))
    try:
        print(f"channels {args.channels} -> {MID_US}us")
        move(MID_US)
        time.sleep(args.settle)
        for start, end in itertools.pairwise(targets):
            print(f"channels {args.channels} -> {end}us")
            for i in range(1, ticks + 1):
                move(round(start + (end - start) * i / ticks))
                time.sleep(segment / ticks)
        time.sleep(args.settle)
    finally:
        for ch in channels:
            ch.stop()


if __name__ == "__main__":
    main()
