#!/usr/bin/env python3
"""
Generates a Collect app icon matching iOS SF Symbol 'cube.box.fill' —
an open-top 3D box (like a shipping box viewed from above at an angle).
White symbol on blue background.
"""

from PIL import Image, ImageDraw
import os

SIZE = 1024

def draw_icon(size=SIZE):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Solid blue background
    draw.rectangle([0, 0, size, size], fill=(30, 120, 220, 255))

    s = size  # alias for readability

    # cube.box.fill is an open box — like a cardboard box seen from an elevated angle.
    # It has: a front face, two side flaps open, a visible inside bottom.
    # Essentially: a box body (front, left side, right side) with 4 flaps open outward.

    cx = s * 0.50
    cy = s * 0.50

    # Scale factor for the symbol within the icon
    k = s * 0.30

    # ---- BOX BODY ----
    # Bottom-front edge
    body_fl = (cx - k,       cy + k * 0.15)   # front-left
    body_fr = (cx + k,       cy + k * 0.15)   # front-right
    # Bottom-back edge (higher up, perspective)
    body_bl = (cx - k * 0.6, cy - k * 0.35)   # back-left
    body_br = (cx + k * 0.6, cy - k * 0.35)   # back-right
    # Bottom vertices (drop down for depth)
    body_fl_b = (cx - k,       cy + k * 0.95)
    body_fr_b = (cx + k,       cy + k * 0.95)
    body_bl_b = (cx - k * 0.6, cy + k * 0.45)
    body_br_b = (cx + k * 0.6, cy + k * 0.45)

    white = (255, 255, 255, 255)
    white_l = (230, 240, 255, 255)   # left face (slightly shaded)
    white_r = (215, 230, 255, 255)   # right face (more shaded)
    white_inside = (200, 220, 250, 255)  # inside bottom
    blue = (30, 120, 220, 255)
    lw = max(2, int(s * 0.005))

    # Inside bottom of box (visible because open top)
    draw.polygon([body_bl, body_br, body_fr, body_fl], fill=white_inside)

    # Front face
    draw.polygon([body_fl, body_fr, body_fr_b, body_fl_b], fill=white)

    # Left face
    draw.polygon([body_bl, body_fl, body_fl_b, body_bl_b], fill=white_l)

    # Right face
    draw.polygon([body_br, body_fr, body_fr_b, body_br_b], fill=white_r)

    # ---- OPEN FLAPS ----
    flap_h = k * 0.45

    # Front flap (folds down toward viewer)
    ff_tl = body_fl
    ff_tr = body_fr
    ff_bl = (cx - k * 1.05,  cy + k * 0.55)
    ff_br = (cx + k * 1.05,  cy + k * 0.55)
    draw.polygon([ff_tl, ff_tr, ff_br, ff_bl], fill=white)

    # Back flap (folds away, partially visible)
    bf_bl = body_bl
    bf_br = body_br
    bf_tl = (cx - k * 0.65,  cy - k * 0.80)
    bf_tr = (cx + k * 0.65,  cy - k * 0.80)
    draw.polygon([bf_bl, bf_br, bf_tr, bf_tl], fill=white_l)

    # Left flap (folds outward left)
    lf_tr = body_fl
    lf_br = body_bl
    lf_tl = (cx - k * 1.35,  cy - k * 0.05)
    lf_bl = (cx - k * 0.95,  cy - k * 0.55)
    draw.polygon([lf_tr, lf_br, lf_bl, lf_tl], fill=white_l)

    # Right flap (folds outward right)
    rf_tl = body_fr
    rf_bl = body_br
    rf_tr = (cx + k * 1.35,  cy - k * 0.05)
    rf_br = (cx + k * 0.95,  cy - k * 0.55)
    draw.polygon([rf_tl, rf_bl, rf_br, rf_tr], fill=white_r)

    # ---- EDGE OUTLINES (subtle, matching background blue) ----
    edge = (20, 100, 200, 120)
    ew = max(3, int(s * 0.008))

    # Box body edges
    draw.line([body_fl, body_fr], fill=edge, width=ew)
    draw.line([body_fl, body_bl], fill=edge, width=ew)
    draw.line([body_fr, body_br], fill=edge, width=ew)
    draw.line([body_fl_b, body_fr_b], fill=edge, width=ew)
    draw.line([body_fl, body_fl_b], fill=edge, width=ew)
    draw.line([body_fr, body_fr_b], fill=edge, width=ew)
    draw.line([body_bl, body_bl_b], fill=edge, width=ew)
    draw.line([body_br, body_br_b], fill=edge, width=ew)

    # Flap edges
    draw.line([ff_tl, ff_bl, ff_br, ff_tr], fill=edge, width=ew)
    draw.line([bf_bl, bf_tl, bf_tr, bf_br], fill=edge, width=ew)
    draw.line([lf_tr, lf_tl, lf_bl, lf_br], fill=edge, width=ew)
    draw.line([rf_tl, rf_tr, rf_br, rf_bl], fill=edge, width=ew)

    return img


def main():
    out_dir = "Collect/Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(out_dir, exist_ok=True)

    master = draw_icon(SIZE)
    master.save(os.path.join(out_dir, "Icon-1024.png"))
    print("✓ Master 1024")

    for s in [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180]:
        master.resize((s, s), Image.LANCZOS).save(os.path.join(out_dir, f"Icon-{s}.png"))
        print(f"  {s}×{s}")

    # Also update AppLogo
    logo_dir = "Collect/Resources/Assets.xcassets/AppLogo.imageset"
    os.makedirs(logo_dir, exist_ok=True)
    master.save(os.path.join(logo_dir, "AppLogo.png"))
    print("✓ AppLogo synced")


if __name__ == "__main__":
    main()
