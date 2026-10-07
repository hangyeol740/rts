"""Create replaceable pixel-art placeholder PNG files without overwriting real art."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1] / "assets" / "sprites"
OUTLINE = (61, 44, 34, 255)
COLORS = {
    "unit_worker.png": ((32, 32), (75, 119, 83, 255)), "unit_sword.png": ((32, 32), (94, 79, 64, 255)),
    "unit_archer.png": ((32, 32), (142, 124, 101, 255)), "bld_hall.png": ((96, 96), (202, 187, 166, 255)),
    "bld_barracks.png": ((64, 64), (94, 79, 64, 255)), "bld_house.png": ((64, 64), (142, 124, 101, 255)),
    "res_goldmine.png": ((64, 64), (217, 166, 58, 255)), "res_tree.png": ((32, 32), (57, 73, 42, 255)),
    "tile_grass.png": ((32, 32), (75, 119, 83, 255)), "tile_dirt.png": ((32, 32), (123, 81, 74, 255)),
    "tile_water.png": ((32, 32), (71, 104, 119, 255)), "ui_panel_parchment.png": ((32, 32), (202, 187, 166, 255)),
    "ui_panel_leather.png": ((32, 32), (61, 44, 34, 255)), "ui_button.png": ((32, 32), (168, 50, 45, 255)),
    "icon_gold.png": ((24, 24), (217, 166, 58, 255)), "icon_wood.png": ((24, 24), (94, 79, 64, 255)),
    "icon_pop.png": ((24, 24), (63, 143, 122, 255))
}
def png(size, color):
    w, h = size; rows = []
    for y in range(h):
        row = bytearray([0])
        for x in range(w): row.extend(OUTLINE if x in (0,w-1) or y in (0,h-1) else color)
        rows.append(row)
    def chunk(tag, body): return struct.pack(">I",len(body))+tag+body+struct.pack(">I",zlib.crc32(tag+body)&0xffffffff)
    return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(b"".join(rows)))+chunk(b"IEND",b"")
ROOT.mkdir(parents=True, exist_ok=True)
for name, (size, color) in COLORS.items():
    path = ROOT / name
    if not path.exists(): path.write_bytes(png(size, color))
