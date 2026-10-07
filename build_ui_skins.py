"""Trim Tiny Swords UI sheets into game-ready skins without altering source art."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements"
OUTPUT = ROOT / "assets/generated_ui"
ASSETS = {
    "paper.png": "Papers/RegularPaper.png",
    "paper_special.png": "Papers/SpecialPaper.png",
    "table.png": "Wood Table/WoodTable.png",
    "button_red.png": "Buttons/BigRedButton_Regular.png",
    "button_blue.png": "Buttons/BigBlueButton_Regular.png",
    "ribbons.png": "Ribbons/BigRibbons.png",
}

OUTPUT.mkdir(parents=True, exist_ok=True)
for target, source in ASSETS.items():
    image = Image.open(SOURCE / source).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    image.crop(bounds).save(OUTPUT / target)
