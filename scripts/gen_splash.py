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

# --- Splash (xxxhdpi) 320x320, logo on transparent background ---
splash_size = 320
splash = img.resize((splash_size, splash_size), Image.LANCZOS)
splash.save(os.path.join(base, "drawable-xxxhdpi", "splash.png"), "PNG")
print("  splash 320x320 OK")

# --- Notification icon (white silhouette) ---
# Convert to grayscale, threshold to make white icon on transparent bg
def make_notif_icon(size):
    small = img.resize((size, size), Image.LANCZOS)
    r, g, b, a = small.split()
    # Grayscale from color channels
    gray = Image.merge("RGB", (r, g, b)).convert("L")
    # Create white icon: where logo is bright (non-background), white pixel
    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels_gray = gray.load()
    pixels_alpha = a.load()
    pixels_out = result.load()
    for y in range(size):
        for x in range(size):
            brightness = pixels_gray[x, y]
            # Background is dark (near black) - treat as transparent
            # Logo elements are bright (blue/cyan/white) - treat as white
            if brightness > 40:
                opacity = min(255, int((brightness - 40) * 1.5))
                pixels_out[x, y] = (255, 255, 255, opacity)
    return result

hdpi_notif = make_notif_icon(72)
mdpi_notif = make_notif_icon(48)

hdpi_notif.save(os.path.join(base, "drawable-hdpi", "ic_stat_logo.png"), "PNG")
mdpi_notif.save(os.path.join(base, "drawable-mdpi", "ic_stat_logo.png"), "PNG")
print("  ic_stat_logo hdpi/mdpi OK")

print("Done")
