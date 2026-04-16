"""
新しい敵スプライトのプレースホルダー画像を生成するスクリプト。
四角形＋シンボル文字で見た目を作る（既存の TileNode フォールバック描画と同じ系統）。
既に存在するファイルは上書きしない。
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "sprites" / "enemies"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SIZE = 32  # タイル相当

# (id, symbol, color rgb) ── enemy_data.gd から抜粋して新規分のみ
PLACEHOLDERS = [
    ("crow",            "c", (51,  51,  64)),
    ("crab",            "x", (217, 77,  51)),
    ("mushroom",        "m", (217, 115, 140)),
    ("wolfen_girl",     "W", (140, 102, 77)),
    ("gnome",           "n", (140, 115, 77)),
    ("dryad",           "d", (102, 191, 115)),
    ("cat_maid_alpha",  "α", (242, 217, 191)),
    ("harpy_girl",      "h", (217, 166, 140)),
    ("dwarf_girl",      "D", (166, 128, 77)),
    ("tentacle_devil",  "t", (140, 77,  166)),
    ("metallic_slime",  "M", (204, 217, 242)),
    ("dancer",          "δ", (140, 89,  166)),
    ("mimic",           "X", (191, 128, 64)),
    ("minotaur",        "T", (140, 97,  38)),
    ("vampire_girl",    "V", (217, 51,  89)),
    ("clown_girl",      "n", (242, 140, 217)),
    ("butler",          "B", (51,  51,  77)),
    ("cat_maid_gamma",  "γ", (242, 191, 242)),
    ("centaur",         "C", (179, 140, 77)),
    ("dark_elf_shaman", "h", (115, 64,  140)),
    ("silver_fox",      "f", (217, 217, 242)),
    ("samurai_girl",    "S", (77,  115, 217)),
    ("scylla",          "y", (77,  140, 166)),
    ("mecha_dragon",    "M", (140, 166, 191)),
    ("dragon_zombie",   "Z", (115, 140, 77)),
    ("lich",            "L", (115, 51,  166)),
    ("inari_hime",      "I", (255, 140, 26)),
    ("death",           "†", (51,  51,  64)),
    ("goddess",         "Ω", (255, 242, 128)),
]

def find_font(size):
    candidates = [
        "C:/Windows/Fonts/yumindb.ttf",      # 游明朝 Demibold
        "C:/Windows/Fonts/YuGothB.ttc",      # 游ゴシック Bold
        "C:/Windows/Fonts/meiryob.ttc",      # メイリオ Bold
        "C:/Windows/Fonts/msgothic.ttc",     # MS ゴシック
        "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def make_placeholder(path, symbol, rgb):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # 背景塗り
    bg = (*rgb, 255)
    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], fill=bg)
    # 縁取り（明るめ）
    edge = (
        min(rgb[0] + 60, 255),
        min(rgb[1] + 60, 255),
        min(rgb[2] + 60, 255),
        255,
    )
    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=edge, width=1)
    # シンボル文字
    font_size = 22
    font = find_font(font_size)
    # 文字色（背景明度で白/黒切替）
    luma = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
    fg = (0, 0, 0, 255) if luma > 160 else (255, 255, 255, 255)
    bbox = draw.textbbox((0, 0), symbol, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = (SIZE - th) // 2 - bbox[1]
    draw.text((tx, ty), symbol, font=font, fill=fg)
    img.save(path)

created = 0
skipped = 0
for eid, sym, rgb in PLACEHOLDERS:
    out = OUT_DIR / f"{eid}.png"
    if out.exists():
        skipped += 1
        continue
    make_placeholder(out, sym, rgb)
    created += 1

print(f"created: {created}, skipped (already exists): {skipped}")
print(f"output dir: {OUT_DIR}")
