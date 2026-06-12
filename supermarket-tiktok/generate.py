import json
import os
import tempfile
from datetime import date
from pathlib import Path

from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
BG = "#1a1a1a"
WHITE = "#ffffff"
GREEN = "#00c853"
GREY = "#888888"

ASSETS_DIR = Path(__file__).parent / "assets"
FONT_REGULAR = str(ASSETS_DIR / "NotoSansHebrew-Regular.ttf")
FONT_BOLD = str(ASSETS_DIR / "NotoSansHebrew-Bold.ttf")

CATEGORY_ICONS = {
    "מוצרי חלב": "🥛",
    "בשר ועוף": "🍖",
    "ירקות ופירות": "🥦",
    "שתייה": "🧃",
    "לחם ומאפים": "🍞",
    "ניקיון": "🧴",
    "חטיפים": "🍿",
}


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REGULAR
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def _rtl(text: str) -> str:
    return get_display(text)


def _new_slide() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), BG)
    return img, ImageDraw.Draw(img)


def render_opening_slide(category: str, date_str: str) -> Image.Image:
    img, draw = _new_slide()
    icon = CATEGORY_ICONS.get(category, "🛒")
    draw.text((W // 2, 600), icon, font=_font(120), anchor="mm", fill=WHITE)
    draw.text((W // 2, 820), _rtl(category), font=_font(80, bold=True), anchor="mm", fill=WHITE)
    draw.text((W // 2, 960), _rtl("השוואת מחירים"), font=_font(50), anchor="mm", fill=GREY)
    draw.text((W // 2, 1060), _rtl(date_str), font=_font(40), anchor="mm", fill=GREY)
    return img


def render_product_slide(product_name: str, deals: dict) -> Image.Image:
    img, draw = _new_slide()
    draw.text((W // 2, 280), _rtl(product_name), font=_font(60, bold=True), anchor="mm", fill=WHITE)

    if not deals:
        draw.text((W // 2, H // 2), _rtl("אין נתונים"), font=_font(50), anchor="mm", fill=GREY)
        return img

    def effective_price(deal):
        return deal["sale_price"] if deal["sale_price"] is not None else deal["regular_price"]

    sorted_chains = sorted(deals.items(), key=lambda x: effective_price(x[1]))
    cheapest_chain = sorted_chains[0][0]

    row_h = 160
    start_y = 500
    for i, (chain, deal) in enumerate(sorted_chains):
        y = start_y + i * row_h
        is_cheapest = chain == cheapest_chain
        row_color = GREEN if is_cheapest else WHITE

        trophy = " 🏆" if is_cheapest else ""
        draw.text((W - 60, y + 30), _rtl(chain + trophy), font=_font(48, bold=is_cheapest),
                  anchor="ra", fill=row_color)

        ep = effective_price(deal)
        price_text = f"₪{ep:.2f}"
        draw.text((200, y + 30), price_text, font=_font(55, bold=is_cheapest),
                  anchor="la", fill=row_color)

        if deal["sale_price"] is not None and deal["regular_price"] != deal["sale_price"]:
            orig_text = f"₪{deal['regular_price']:.2f}"
            orig_font = _font(36)
            draw.text((330, y + 30), orig_text, font=orig_font, anchor="la", fill=GREY)
            bbox = orig_font.getbbox(orig_text)
            mid_y = y + 30 + (bbox[3] - bbox[1]) // 2
            draw.line([(330, mid_y), (330 + bbox[2], mid_y)], fill=GREY, width=2)

        draw.line([(60, y + row_h - 10), (W - 60, y + row_h - 10)], fill="#333333", width=1)

    return img


def render_closing_slide() -> Image.Image:
    img, draw = _new_slide()
    draw.text((W // 2, 700), "🛒", font=_font(120), anchor="mm", fill=WHITE)
    draw.text((W // 2, 900), _rtl("עקבו לעוד השוואות"), font=_font(65, bold=True), anchor="mm", fill=WHITE)
    draw.text((W // 2, 1020), _rtl("מחירים כל שבוע"), font=_font(50), anchor="mm", fill=GREY)
    return img


def generate_video(category_name: str, products: list[dict], output_path: str):
    today = date.today().isoformat()

    with tempfile.TemporaryDirectory() as tmp:
        frames = []

        def save_frame(img: Image.Image, idx: int) -> str:
            path = os.path.join(tmp, f"frame_{idx:04d}.png")
            img.save(path)
            return path

        frame_idx = 0
        frames.append(save_frame(render_opening_slide(category_name, today), frame_idx))
        frame_idx += 1

        for product in products:
            frames.append(save_frame(render_product_slide(product["name"], product["deals"]), frame_idx))
            frame_idx += 1

        frames.append(save_frame(render_closing_slide(), frame_idx))

        from moviepy import ImageSequenceClip, AudioFileClip

        fps = 1 / 2.5
        clip = ImageSequenceClip(frames, fps=fps)

        music_path = str(ASSETS_DIR / "music.mp3")
        if os.path.exists(music_path):
            audio = AudioFileClip(music_path)
            if audio.duration > clip.duration:
                audio = audio.subclipped(0, clip.duration)
            clip = clip.with_audio(audio)

        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        clip.write_videofile(output_path, fps=24, codec="libx264", audio_codec="aac", logger=None)
        print(f"  Saved: {output_path}")


def main():
    data_dir = Path(__file__).parent / "data"
    out_dir = Path(__file__).parent / "output"
    out_dir.mkdir(exist_ok=True)

    with open(data_dir / "comparison.json", encoding="utf-8") as f:
        comparison = json.load(f)

    today = comparison["generated_at"]

    for category in comparison["categories"]:
        name = category["name"]
        products = category["products"]
        if not products:
            continue

        safe_name = name.replace(" ", "_").replace("/", "-")
        output_path = str(out_dir / f"video_{safe_name}_{today}.mp4")
        print(f"Generating: {name} ({len(products)} products)")
        generate_video(name, products, output_path)

    print("Done. Upload files from output/ to TikTok.")


if __name__ == "__main__":
    main()
