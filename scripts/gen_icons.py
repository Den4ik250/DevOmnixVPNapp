from PIL import Image, ImageDraw
import os

src = r"C:\Users\user\StudioProjects\DevOmnixVPNapp\Logo\Screenshot 2026-05-19 000617.png"
base = r"C:\Users\user\StudioProjects\DevOmnixVPNapp\android\app\src\main\res"

img = Image.open(src).convert("RGBA")

# Center-crop to square
w, h = img.size
side = min(w, h)
left = (w - side) // 2
top = (h - side) // 2
img = img.crop((left, top, left + side, top + side))

def make_icon(size, add_round=False):
    icon = img.resize((size, size), Image.LANCZOS)
    if add_round:
        mask = Image.new("L", (size, size), 0)
        draw = ImageDraw.Draw(mask)
        draw.ellipse((0, 0, size, size), fill=255)
        result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        result.paste(icon, mask=mask)
        return result
    return icon

sizes = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

for folder, size in sizes.items():
    path = os.path.join(base, folder)
    os.makedirs(path, exist_ok=True)
    make_icon(size).save(os.path.join(path, "ic_launcher.webp"), "WEBP", quality=95)
    make_icon(size, add_round=True).save(os.path.join(path, "ic_launcher_round.webp"), "WEBP", quality=95)
    print(f"  {folder}: {size}x{size} OK")

print("Done")
