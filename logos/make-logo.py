#!/usr/bin/env python3
# The dArkMoss boot logo, laid out like oakMOSS's (scripts/make-boot-resource.py logo()): spruce's tree
# (spruce/imgs/tree_sm_close_crop.png) over the name on black, as a full-panel 24-bit BMP for U-Boot and bootlogo.py.
#   make-logo.py <width> <height> <out.bmp> [--rotate-cw]    --rotate-cw: draw landscape, turn 90 degrees clockwise
import os
import sys

from PIL import Image, ImageDraw, ImageFont

TREE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spruce-tree.png")
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def logo(w, h, label="dArkMoss"):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    tree = Image.open(TREE).convert("RGBA")
    tree = tree.resize((tree.width * 2, tree.height * 2), Image.LANCZOS)
    font = ImageFont.truetype(FONTB, 46)
    d = ImageDraw.Draw(im)
    lw = d.textlength(label, font=font)
    asc, desc = font.getmetrics()
    gap = 22
    top = (h - (tree.height + gap + asc + desc)) // 2
    im.alpha_composite(tree, ((w - tree.width) // 2, top))
    d.text(((w - lw) / 2, top + tree.height + gap), label, font=font, fill=(235, 235, 235, 255))
    return im.convert("RGB")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--rotate-cw"]
    if len(args) != 3:
        sys.exit("usage: make-logo.py <width> <height> <out.bmp> [--rotate-cw]")
    w, h, out = int(args[0]), int(args[1]), args[2]
    if "--rotate-cw" in sys.argv:
        logo(h, w).transpose(Image.Transpose.ROTATE_270).save(out, "BMP")
    else:
        logo(w, h).save(out, "BMP")
