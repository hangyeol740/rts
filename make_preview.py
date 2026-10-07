"""Create an x2 inspection sheet without editing any Tiny Swords source art."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)"
ITEMS = [
    ("Blue Pawn", "Units/Blue Units/Pawn/Pawn_Run Pickaxe.png", (0, 0, 192, 192)),
    ("Red Pawn", "Units/Red Units/Pawn/Pawn_Run Pickaxe.png", (0, 0, 192, 192)),
    ("Blue Warrior", "Units/Blue Units/Warrior/Warrior_Attack1.png", (0, 0, 192, 192)),
    ("Red Archer", "Units/Red Units/Archer/Archer_Idle.png", (0, 0, 192, 192)),
    ("Blue Castle", "Buildings/Blue Buildings/Castle.png", None),
    ("Red Barracks", "Buildings/Red Buildings/Barracks.png", None),
    ("House", "Buildings/Blue Buildings/House1.png", None),
    ("Gold", "Terrain/Resources/Gold/Gold Stones/Gold Stone 1.png", None),
    ("Tree", "Terrain/Resources/Wood/Trees/Tree1.png", (0, 0, 256, 256)),
]
sheet = Image.new("RGBA", (1600, 1040), "#39492a")
draw = ImageDraw.Draw(sheet)
for index, (name, relative, frame) in enumerate(ITEMS):
    image = Image.open(PACK / relative).convert("RGBA")
    if frame: image = image.crop(frame)
    image.thumbnail((280, 270), Image.Resampling.NEAREST)
    x = (index % 3) * 530 + 110; y = (index // 3) * 340 + 55
    sheet.alpha_composite(image, (x + (280 - image.width) // 2, y))
    draw.text((x, y + 280), name, fill="#e5e1d8", stroke_width=2, stroke_fill="#3d2c22")
(ROOT / "preview").mkdir(exist_ok=True)
sheet.save(ROOT / "preview/sprites_x2.png")
