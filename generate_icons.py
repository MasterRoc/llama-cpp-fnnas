#!/usr/bin/env python3
"""
Generate icons for the Fnnos llama.cpp application package.

If a custom source icon is provided by placing a file named
``ICON_SOURCE.PNG`` (or ``ICON_SOURCE.png``) in the package directory,
it will be used as the source and resized to all required sizes.
Otherwise, a programmatically-generated llama-themed icon is used.

Required output files:
  - ICON.PNG            (64x64,  uppercase, package root)
  - ICON_256.PNG        (256x256, uppercase, package root)
  - app/ui/images/icon_64.png   (64x64, lowercase)
  - app/ui/images/icon_256.png  (256x256, lowercase)
"""

from PIL import Image, ImageDraw
import os
import sys

# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------

PACKAGE_DIR = os.path.dirname(os.path.abspath(__file__))

# Candidate names for a user-supplied custom icon (checked in order).
CUSTOM_SOURCE_NAMES = [
    "ICON_SOURCE.PNG",
    "ICON_SOURCE.png",
    "ICON_SOURCE",
]

# Required output icons: (filename, size)
OUTPUT_ICONS = [
    ("ICON.PNG", 64),
    ("ICON_256.PNG", 256),
    ("app/ui/images/icon_64.png", 64),
    ("app/ui/images/icon_256.png", 256),
]


# ----------------------------------------------------------------------------
# Programmatic fallback icon (llama-themed)
# ----------------------------------------------------------------------------

def create_llama_icon(size):
    """Create a llama-themed icon of the given size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background gradient (deep navy to purple-blue)
    for y in range(size):
        ratio = y / size
        r = int(30 + (60 - 30) * ratio)
        g = int(30 + (50 - 30) * ratio)
        b = int(80 + (140 - 80) * ratio)
        draw.rectangle([(0, y), (size, y)], fill=(r, g, b))

    # Llama face - using simple geometric shapes
    margin = size * 0.12
    center_x = size / 2
    center_y = size / 2

    # Scale factor
    s = size / 256

    # Face base (rounded rectangle / ellipse)
    face_w = 140 * s
    face_h = 120 * s
    face_top = center_y - face_h * 0.3
    draw.ellipse(
        [(center_x - face_w / 2, face_top),
         (center_x + face_w / 2, face_top + face_h)],
        fill=(240, 220, 190)  # Tan/beige fur color
    )

    # Snout (lighter area)
    snout_w = 70 * s
    snout_h = 60 * s
    snout_top = center_y + 10 * s
    draw.ellipse(
        [(center_x - snout_w / 2, snout_top),
         (center_x + snout_w / 2, snout_top + snout_h)],
        fill=(255, 240, 220)
    )

    # Eyes
    eye_spacing = 35 * s
    eye_y = center_y - 20 * s
    eye_r = 10 * s

    # Left eye
    draw.ellipse(
        [(center_x - eye_spacing - eye_r, eye_y - eye_r),
         (center_x - eye_spacing + eye_r, eye_y + eye_r)],
        fill=(40, 30, 30)
    )
    # Eye highlight
    hl_r = 4 * s
    draw.ellipse(
        [(center_x - eye_spacing - hl_r, eye_y - eye_r),
         (center_x - eye_spacing + hl_r, eye_y - eye_r + hl_r * 2)],
        fill=(255, 255, 255)
    )

    # Right eye
    draw.ellipse(
        [(center_x + eye_spacing - eye_r, eye_y - eye_r),
         (center_x + eye_spacing + eye_r, eye_y + eye_r)],
        fill=(40, 30, 30)
    )
    draw.ellipse(
        [(center_x + eye_spacing - hl_r, eye_y - eye_r),
         (center_x + eye_spacing + hl_r, eye_y - eye_r + hl_r * 2)],
        fill=(255, 255, 255)
    )

    # Nostrils
    nostril_y = center_y + 30 * s
    nostril_spacing = 15 * s
    nostril_r = 4 * s
    for ns_x in [center_x - nostril_spacing, center_x + nostril_spacing]:
        draw.ellipse(
            [(ns_x - nostril_r, nostril_y - nostril_r),
             (ns_x + nostril_r, nostril_y + nostril_r)],
            fill=(180, 150, 130)
        )

    # Mouth (gentle smile)
    mouth_y = nostril_y + 12 * s
    draw.arc(
        [(center_x - 18 * s, mouth_y - 10 * s),
         (center_x + 18 * s, mouth_y + 10 * s)],
        start=0, end=180,
        fill=(140, 100, 80),
        width=max(1, int(2.5 * s))
    )

    # Ears
    ear_w = 28 * s
    ear_h = 55 * s
    ear_top = center_y - 85 * s

    # Left ear
    draw.ellipse(
        [(center_x - 55 * s, ear_top),
         (center_x - 55 * s + ear_w, ear_top + ear_h)],
        fill=(220, 195, 165)
    )
    # Inner ear
    draw.ellipse(
        [(center_x - 50 * s, ear_top + 8 * s),
         (center_x - 50 * s + ear_w * 0.5, ear_top + ear_h * 0.8)],
        fill=(255, 180, 160)
    )

    # Right ear
    draw.ellipse(
        [(center_x + 55 * s - ear_w, ear_top),
         (center_x + 55 * s, ear_top + ear_h)],
        fill=(220, 195, 165)
    )
    draw.ellipse(
        [(center_x + 50 * s - ear_w * 0.5, ear_top + 8 * s),
         (center_x + 50 * s, ear_top + ear_h * 0.8)],
        fill=(255, 180, 160)
    )

    # Neck
    neck_w = 80 * s
    neck_h = 50 * s
    draw.rectangle(
        [(center_x - neck_w / 2, center_y + 55 * s),
         (center_x + neck_w / 2, size + 5)],
        fill=(220, 195, 165)
    )

    # AI sparkle / neural network emblem in the corner
    sparkle_x = size - 42 * s
    sparkle_y = 30 * s
    sparkle_r = 16 * s

    # Glow circle
    for i in range(3):
        glow_r = sparkle_r + i * 3 * s
        alpha = 100 - i * 30
        draw.ellipse(
            [(sparkle_x - glow_r, sparkle_y - glow_r),
             (sparkle_x + glow_r, sparkle_y + glow_r)],
            fill=(100, 220, 255, alpha)
        )

    # AI chip symbol
    chip_size = sparkle_r * 1.2
    draw.rounded_rectangle(
        [(sparkle_x - chip_size / 2, sparkle_y - chip_size / 2),
         (sparkle_x + chip_size / 2, sparkle_y + chip_size / 2)],
        radius=max(1, int(4 * s)),
        fill=(80, 200, 255)
    )

    # Chip inner lines
    line_c = sparkle_x
    draw.line([(line_c, sparkle_y - chip_size * 0.3), (line_c, sparkle_y + chip_size * 0.3)],
              fill=(255, 255, 255), width=max(1, int(2 * s)))
    draw.line([(line_c - chip_size * 0.3, sparkle_y), (line_c + chip_size * 0.3, sparkle_y)],
              fill=(255, 255, 255), width=max(1, int(2 * s)))

    return img


# ----------------------------------------------------------------------------
# Custom icon loading and resizing
# ----------------------------------------------------------------------------

def find_custom_source():
    """Look for a user-supplied custom icon in the package directory."""
    for name in CUSTOM_SOURCE_NAMES:
        path = os.path.join(PACKAGE_DIR, name)
        if os.path.isfile(path):
            return path
    return None


def generate_from_custom(source_path):
    """Load a custom 256x256 (or larger) PNG and resize to all required sizes."""
    img = Image.open(source_path).convert('RGBA')
    orig_w, orig_h = img.size
    print(f"  -> Using custom source: {source_path} ({orig_w}x{orig_h})")

    results = {}
    for filename, size in OUTPUT_ICONS:
        out = img.resize((size, size), Image.LANCZOS)
        out_path = os.path.join(PACKAGE_DIR, filename)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        out.save(out_path, 'PNG')
        results[filename] = out_path
        print(f"  -> {out_path} ({size}x{size})")

    return results


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

def main():
    print("=" * 40)
    print("  Icon Generation")
    print("=" * 40)

    # Check for custom source icon
    custom_source = find_custom_source()
    if custom_source:
        print("Custom source icon found!")
        generate_from_custom(custom_source)
        print("\nAll icons generated from custom source.")
        return

    # Fall back to programmatic llama icon
    print("No custom icon found. Generating programmatic llama icon.")
    print("(Place ICON_SOURCE.PNG in the package directory to use a custom icon.)")
    print()

    # Generate 64x64 icon
    print("Generating ICON.PNG (64x64)...")
    icon_64 = create_llama_icon(64)
    icon_64_path = os.path.join(PACKAGE_DIR, 'ICON.PNG')
    icon_64.save(icon_64_path, 'PNG')
    print(f"  -> {icon_64_path}")

    # Generate 256x256 icon
    print("Generating ICON_256.PNG (256x256)...")
    icon_256 = create_llama_icon(256)
    icon_256_path = os.path.join(PACKAGE_DIR, 'ICON_256.PNG')
    icon_256.save(icon_256_path, 'PNG')
    print(f"  -> {icon_256_path}")

    # Also save copies in app/ui/images/ for the UI entry
    images_dir = os.path.join(PACKAGE_DIR, 'app', 'ui', 'images')
    os.makedirs(images_dir, exist_ok=True)

    for name, img in [('icon_64.png', icon_64), ('icon_256.png', icon_256)]:
        img_path = os.path.join(images_dir, name)
        img.save(img_path, 'PNG')
        print(f"  -> {img_path}")

    print("\nIcons generated successfully!")


if __name__ == '__main__':
    main()
