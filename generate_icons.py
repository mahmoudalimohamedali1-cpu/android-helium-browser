#!/usr/bin/env python3
"""Generate Sneptuob launcher icons (S letter with gradient background) for all densities."""
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Installing Pillow...")
    os.system(f"{sys.executable} -m pip install Pillow")
    from PIL import Image, ImageDraw, ImageFont

def create_gradient(width, height):
    """Create diagonal gradient: cyan -> green -> orange (matching SmartWeb original)."""
    img = Image.new('RGBA', (width, height))
    for y in range(height):
        for x in range(width):
            # Diagonal progress from top-left to bottom-right
            t = (x / width + y / height) / 2.0
            if t < 0.5:
                # Cyan (#00BCD4) to Green (#66BB6A)
                t2 = t * 2
                r = int(0x00 + (0x66 - 0x00) * t2)
                g = int(0xBC + (0xBB - 0xBC) * t2)
                b = int(0xD4 + (0x6A - 0xD4) * t2)
            else:
                # Green (#66BB6A) to Orange (#FF9800)
                t2 = (t - 0.5) * 2
                r = int(0x66 + (0xFF - 0x66) * t2)
                g = int(0xBB + (0x98 - 0xBB) * t2)
                b = int(0x6A + (0x00 - 0x6A) * t2)
            img.putpixel((x, y), (r, g, b, 255))
    return img

def draw_s_letter(img, size):
    """Draw a stylish 'S' letter in white, centered."""
    draw = ImageDraw.Draw(img)

    # Try to use a nice font, fallback to default
    font_size = int(size * 0.55)
    font = None

    # Try common font paths
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay-Bold.otf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    ]

    for fp in font_paths:
        if os.path.exists(fp):
            try:
                font = ImageFont.truetype(fp, font_size)
                break
            except:
                continue

    if font is None:
        try:
            font = ImageFont.truetype("DejaVuSans-Bold", font_size)
        except:
            font = ImageFont.load_default()

    # Get text bounding box
    text = "S"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    # Center the text
    x = (size - text_w) / 2 - bbox[0]
    y = (size - text_h) / 2 - bbox[1]

    # Draw white S with slight shadow for depth
    shadow_offset = max(1, size // 100)
    draw.text((x + shadow_offset, y + shadow_offset), text, fill=(0, 0, 0, 40), font=font)
    draw.text((x, y), text, fill=(255, 255, 255, 230), font=font)

    return img

def generate_icon(size, output_path):
    """Generate a single icon at the given size."""
    img = create_gradient(size, size)
    img = draw_s_letter(img, size)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"  Generated: {output_path} ({size}x{size})")

def main():
    if len(sys.argv) < 2:
        print("Usage: generate_icons.py <chromium_src_dir>")
        sys.exit(1)

    src_dir = sys.argv[1]

    # Android mipmap densities for launcher icon
    densities = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    print("Generating Sneptuob launcher icons...")

    # Generate app_icon.png for each density in res_chromium_base
    base_res = os.path.join(src_dir, "chrome/android/java/res_chromium_base")
    for density, size in densities.items():
        output = os.path.join(base_res, density, "app_icon.png")
        generate_icon(size, output)

    # Generate product logos
    for scale, sizes in [("default_100_percent", [32, 48, 64, 128, 256]),
                          ("default_200_percent", [32, 48, 64, 128, 256])]:
        multiplier = 1 if "100" in scale else 2
        for s in sizes:
            actual_size = s * multiplier
            path = os.path.join(src_dir, f"chrome/app/theme/{scale}/chromium/product_logo_{s}.png")
            generate_icon(actual_size, path)

    # Generate component logos
    for scale in ["default_100_percent", "default_200_percent"]:
        multiplier = 1 if "100" in scale else 2
        path = os.path.join(src_dir, f"components/resources/{scale}/chromium/product_logo.png")
        generate_icon(64 * multiplier, path)

    # Generate a large icon for adaptive icon foreground
    large_icon = os.path.join(src_dir, "chrome/android/java/res_chromium_base/drawable-xxxhdpi/chromium_app_icon_fg.xml")
    # We'll handle adaptive icon via XML overlay instead

    print("\nAll icons generated successfully!")
    print("Note: Adaptive icon foreground needs XML/vector changes separately.")

if __name__ == "__main__":
    main()
