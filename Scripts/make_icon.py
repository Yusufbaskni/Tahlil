#!/usr/bin/env python3
"""1024 px Tahlil ikonu. Köşeleri sistem maskesi keser; şerit ortada durur."""

import struct
import zlib
from pathlib import Path

SIZE = 1024


def write_png(path: Path, pixels: bytearray) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    stride = SIZE * 4
    for y in range(SIZE):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def set_pixel(pixels: bytearray, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        index = (y * SIZE + x) * 4
        pixels[index : index + 4] = bytes(color)


def fill_round_rect(
    pixels: bytearray,
    origin: tuple[int, int],
    size: tuple[int, int],
    radius: int,
    color: tuple[int, int, int, int],
) -> None:
    left, top = origin
    width, height = size
    right = left + width
    bottom = top + height
    for y in range(top, bottom):
        for x in range(left, right):
            inner_x = min(max(x, left + radius), right - radius - 1)
            inner_y = min(max(y, top + radius), bottom - radius - 1)
            dx = x - inner_x
            dy = y - inner_y
            if dx * dx + dy * dy <= radius * radius:
                set_pixel(pixels, x, y, color)


def main() -> None:
    output = Path(sys_path())
    output.parent.mkdir(parents=True, exist_ok=True)
    pixels = bytearray(SIZE * SIZE * 4)
    for y in range(SIZE):
        shade = int(14 + (y / SIZE) * 10)
        row = bytes((shade, 92 + shade // 6, 90, 255))
        start = y * SIZE * 4
        pixels[start : start + SIZE * 4] = row * SIZE

    fill_round_rect(pixels, (390, 150), (244, 760), 36, (244, 240, 232, 255))
    fill_round_rect(pixels, (430, 78), (164, 90), 18, (236, 232, 224, 255))

    pads = [
        (124, 146, 58),
        (246, 224, 170),
        (240, 206, 156),
        (104, 176, 92),
        (238, 198, 78),
        (236, 180, 56),
        (150, 186, 96),
        (236, 150, 164),
        (176, 96, 140),
    ]
    pad_top = 188
    pad_height = 68
    gap = 10
    for index, rgb in enumerate(pads):
        y = pad_top + index * (pad_height + gap)
        fill_round_rect(pixels, (412, y), (200, pad_height), 12, (*rgb, 255))

    write_png(output, pixels)


def sys_path() -> str:
    import sys

    if len(sys.argv) > 1:
        return sys.argv[1]
    return "build/AppIcon-1024.png"


if __name__ == "__main__":
    main()
