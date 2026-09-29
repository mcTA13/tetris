"""assets/icon/icon*.png をまとめて Windows 用の assets/icon/icon.ico を作る（PNG をそのまま格納する形式）。

実行: python tools/pack_ico.py
"""
import pathlib
import struct

ICON_DIR = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon"
SIZES = [256, 128, 64, 48, 32, 16]


def main() -> None:
    images = []
    for size in SIZES:
        name = "icon.png" if size == 256 else f"icon_{size}.png"
        images.append((size, (ICON_DIR / name).read_bytes()))

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)
    entries = b""
    data = b""
    for size, png in images:
        dim = 0 if size >= 256 else size  # 256 は 0 と書く決まり
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset)
        offset += len(png)
        data += png
    (ICON_DIR / "icon.ico").write_bytes(header + entries + data)
    print("wrote", ICON_DIR / "icon.ico")


if __name__ == "__main__":
    main()
