"""Regenerates the SalahLK icon, adaptive foreground, splash image and TV banner.

Run from the project root:  python tool/generate_icons.py
Needs Pillow. The SVGs in assets/icon/ are the editable source; this script draws the same
geometry with Pillow so no SVG renderer is required.
"""
from PIL import Image, ImageDraw, ImageFont

GOLD = (0xD4, 0xAF, 0x37, 255)
BG = (0x0A, 0x0A, 0x0F, 255)
SS = 4  # supersampling factor

# Geometry on a 1024 canvas (keep in sync with assets/icon/icon.svg).
OUTER = (512, 512, 330)      # crescent outer circle (cx, cy, r)
CUT = (610, 455, 290)        # circle cut out of it
CLOCK = (625, 500, 125)      # clock face centre + radius
STROKE = 24


def draw_mark(size, scale=1.0, bg=None):
    """Crescent + clock on a size x size canvas; scale shrinks the mark about the centre."""
    n = size * SS
    img = Image.new("RGBA", (n, n), bg or (0, 0, 0, 0))
    k = n / 1024 * scale
    off = n * (1 - scale) / 2

    def p(v):
        return v * k + off

    def circle(d, c, fill):
        cx, cy, r = c
        d.ellipse([p(cx - r), p(cy - r), p(cx + r), p(cy + r)], fill=fill)

    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    circle(md, OUTER, 255)
    circle(md, CUT, 0)
    img.paste(Image.new("RGBA", (n, n), GOLD), (0, 0), mask)

    d = ImageDraw.Draw(img)
    cx, cy, r = CLOCK
    w = STROKE * k
    d.ellipse([p(cx - r), p(cy - r), p(cx + r), p(cy + r)], outline=GOLD, width=round(w))
    # hands: 12 o'clock and ~4 o'clock, round caps
    for end in ((cx, cy - 78), (cx + 56, cy + 32)):
        d.line([p(cx), p(cy), p(end[0]), p(end[1])], fill=GOLD, width=round(w))
        for x, y in ((cx, cy), end):
            d.ellipse([p(x) - w / 2, p(y) - w / 2, p(x) + w / 2, p(y) + w / 2], fill=GOLD)
    return img.resize((size, size), Image.LANCZOS)


def main():
    draw_mark(1024, 1.0, BG).save("assets/icon/icon.png")
    draw_mark(1024, 0.62).save("assets/icon/icon_foreground.png")  # inside adaptive safe zone
    draw_mark(768, 0.8).save("assets/icon/splash.png")

    # TV banner 320x180 (xhdpi): icon left, text right. Drawn at 4x then downsampled.
    w, h, s = 320, 180, 4
    banner = Image.new("RGBA", (w * s, h * s), BG)
    mark = draw_mark(130 * s, 1.0)
    banner.alpha_composite(mark, (22 * s, 25 * s))
    font = ImageFont.truetype("assets/fonts/Poppins-Bold.ttf", 32 * s)
    d = ImageDraw.Draw(banner)
    d.text((160 * s, 90 * s), "SalahLK", font=font, fill=GOLD, anchor="lm")
    banner.resize((w, h), Image.LANCZOS).convert("RGB").save(
        "android/app/src/main/res/drawable-xhdpi/banner.png")
    banner.resize((w, h), Image.LANCZOS).convert("RGB").save("assets/icon/banner.png")


if __name__ == "__main__":
    main()
