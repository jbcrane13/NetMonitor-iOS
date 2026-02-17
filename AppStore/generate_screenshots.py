#!/usr/bin/env python3
"""
Generate App Store screenshot compositions for NetMonitor.

USAGE:
1. Save your 10 best screenshots to AppStore/source/ with these names:
   - dashboard.png      (Dashboard with all panels loaded)
   - network-map.png    (Network Map showing discovered devices)
   - tools-grid.png     (Tools tab showing all 10 tools)
   - ping.png           (Ping tool with live results/graph)
   - port-scanner.png   (Port Scanner with scan results)
   - dns-lookup.png     (DNS Lookup with query results)
   - traceroute.png     (Traceroute with hop visualization)
   - speed-test.png     (Speed Test with results)
   - bonjour-wol.png    (Bonjour Discovery or Wake on LAN)
   - privacy-hero.png   (Dashboard or any view for the "Zero Tracking" slide)

2. Run: python3 generate_screenshots.py

Output goes to AppStore/Screenshots/ at 1320x2868 (iPhone 16 Pro Max).
"""

from PIL import Image, ImageDraw, ImageFont
import os
import sys

# === Configuration ===
CANVAS_W = 1284
CANVAS_H = 2778

# Screenshot placement
SCREENSHOT_SCALE = 0.82
SCREENSHOT_Y_OFFSET = 780

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_DIR = os.path.join(SCRIPT_DIR, "source")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "Screenshots")

os.makedirs(SOURCE_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Colors
ACCENT_BLUE = (10, 132, 255)
ACCENT_TEAL = (48, 209, 188)
ACCENT_GREEN = (48, 209, 88)
ACCENT_ORANGE = (255, 159, 10)
ACCENT_RED = (255, 69, 58)
ACCENT_PURPLE = (175, 82, 222)
TEXT_WHITE = (255, 255, 255)
TEXT_GRAY = (174, 174, 178)

# The 10 App Store slides
SLIDES = [
    {
        "source": "dashboard.png",
        "headline": "Your Network\nat a Glance",
        "subhead": "Real-time status, WiFi details,\ngateway latency & ISP info",
        "gradient_top": (10, 35, 78),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_BLUE,
        "output": "01-dashboard.png",
    },
    {
        "source": "network-map.png",
        "headline": "Discover Every\nDevice",
        "subhead": "Concurrent TCP probing finds\nevery host on your network",
        "gradient_top": (8, 52, 48),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_TEAL,
        "output": "02-network-map.png",
    },
    {
        "source": "tools-grid.png",
        "headline": "10 Pro Tools.\nOne App.",
        "subhead": "Ping, scan, trace, lookup, wake —\neverything you need on the go",
        "gradient_top": (45, 20, 65),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_PURPLE,
        "output": "03-tools.png",
    },
    {
        "source": "ping.png",
        "headline": "Live Latency\nMonitoring",
        "subhead": "Streaming TCP ping with real-time\ngraphs and statistics",
        "gradient_top": (10, 50, 20),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_GREEN,
        "output": "04-ping.png",
    },
    {
        "source": "port-scanner.png",
        "headline": "Port Scanner",
        "subhead": "Fast TCP connect scanning\nwith service identification",
        "gradient_top": (60, 30, 8),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_ORANGE,
        "output": "05-port-scanner.png",
    },
    {
        "source": "dns-lookup.png",
        "headline": "DNS Lookup",
        "subhead": "Query A, AAAA, MX, TXT, CNAME,\nNS, SOA & PTR records",
        "gradient_top": (10, 35, 78),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_BLUE,
        "output": "06-dns-lookup.png",
    },
    {
        "source": "traceroute.png",
        "headline": "Trace the Path",
        "subhead": "Hop-by-hop route visualization\nwith per-hop latency",
        "gradient_top": (50, 10, 10),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_RED,
        "output": "07-traceroute.png",
    },
    {
        "source": "speed-test.png",
        "headline": "Speed Test",
        "subhead": "Measure download & upload\nbandwidth instantly",
        "gradient_top": (8, 52, 48),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_TEAL,
        "output": "08-speed-test.png",
    },
    {
        "source": "bonjour-wol.png",
        "headline": "Wake on LAN\n& Bonjour",
        "subhead": "Magic packets & mDNS discovery\nfor your local network",
        "gradient_top": (45, 20, 65),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_PURPLE,
        "output": "09-bonjour-wol.png",
    },
    {
        "source": "privacy-hero.png",
        "headline": "Zero Tracking.\nZero Ads.",
        "subhead": "100% on-device. No accounts.\nYour network data stays yours.",
        "gradient_top": (10, 35, 78),
        "gradient_bottom": (12, 12, 14),
        "accent": ACCENT_BLUE,
        "output": "10-privacy.png",
    },
]


def create_gradient(width, height, color_top, color_bottom):
    """Create a vertical gradient image with ease-in curve."""
    img = Image.new('RGB', (width, height))
    pixels = img.load()
    for y in range(height):
        t = (y / max(height - 1, 1)) ** 2  # ease-in
        r = int(color_top[0] + (color_bottom[0] - color_top[0]) * t)
        g = int(color_top[1] + (color_bottom[1] - color_top[1]) * t)
        b = int(color_top[2] + (color_bottom[2] - color_top[2]) * t)
        for x in range(width):
            pixels[x, y] = (r, g, b)
    return img


def create_rounded_mask(size, radius):
    """Create a rounded rectangle mask."""
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (size[0]-1, size[1]-1)], radius=radius, fill=255)
    return mask


def get_font(size, bold=False):
    """Get best available font."""
    candidates = [
        # macOS
        "/System/Library/Fonts/SFProDisplay-Bold.otf" if bold else "/System/Library/Fonts/SFProDisplay-Regular.otf",
        "/System/Library/Fonts/Helvetica.ttc",
        # Linux
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def create_slide(config):
    """Create a single App Store screenshot composition."""
    source_path = os.path.join(SOURCE_DIR, config["source"])
    if not os.path.exists(source_path):
        return None, f"Missing: {config['source']}"

    screenshot = Image.open(source_path).convert('RGBA')

    # Create gradient canvas
    canvas = create_gradient(
        CANVAS_W, CANVAS_H,
        config["gradient_top"],
        config["gradient_bottom"]
    ).convert('RGBA')

    # Subtle accent glow at top
    glow = Image.new('RGBA', (CANVAS_W, 400), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    accent = config["accent"]
    for y in range(400):
        alpha = int(25 * (1 - y / 400))
        glow_draw.line([(0, y), (CANVAS_W, y)], fill=accent + (alpha,))
    canvas = Image.alpha_composite(canvas, Image.new('RGBA', canvas.size, (0, 0, 0, 0)))
    canvas.paste(glow, (0, 0), glow)

    # Scale and frame the screenshot
    target_w = int(CANVAS_W * SCREENSHOT_SCALE)
    ratio = target_w / screenshot.width
    target_h = int(screenshot.height * ratio)
    max_h = CANVAS_H - SCREENSHOT_Y_OFFSET - 40
    if target_h > max_h:
        target_h = max_h
        ratio = target_h / screenshot.height
        target_w = int(screenshot.width * ratio)

    scaled = screenshot.resize((target_w, target_h), Image.LANCZOS)

    # Device frame
    pad = 16
    frame_w, frame_h = target_w + pad * 2, target_h + pad * 2
    frame = Image.new('RGBA', (frame_w, frame_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=44, fill=(38, 38, 40, 255), outline=(58, 58, 62, 255), width=3
    )

    # Round corners on screenshot
    mask = create_rounded_mask((target_w, target_h), 36)
    rounded = Image.new('RGBA', (target_w, target_h), (0, 0, 0, 0))
    rounded.paste(scaled, mask=mask)
    frame.paste(rounded, (pad, pad), rounded)

    # Center and place
    frame_x = (CANVAS_W - frame_w) // 2
    canvas.paste(frame, (frame_x, SCREENSHOT_Y_OFFSET), frame)

    # Draw headline text
    draw = ImageDraw.Draw(canvas)
    headline_font = get_font(96, bold=True)
    y_pos = 140

    for line in config["headline"].split("\n"):
        bbox = draw.textbbox((0, 0), line, font=headline_font)
        text_w = bbox[2] - bbox[0]
        x = (CANVAS_W - text_w) // 2
        # Shadow
        draw.text((x + 2, y_pos + 2), line, font=headline_font, fill=(0, 0, 0, 80))
        draw.text((x, y_pos), line, font=headline_font, fill=TEXT_WHITE)
        y_pos += 120

    # Draw subhead
    y_pos += 20
    subhead_font = get_font(48)
    for line in config["subhead"].split("\n"):
        bbox = draw.textbbox((0, 0), line, font=subhead_font)
        text_w = bbox[2] - bbox[0]
        x = (CANVAS_W - text_w) // 2
        draw.text((x, y_pos), line, font=subhead_font, fill=TEXT_GRAY)
        y_pos += 64

    # Accent divider line
    line_y = y_pos + 20
    line_w = 120
    line_x = (CANVAS_W - line_w) // 2
    draw.rounded_rectangle(
        [(line_x, line_y), (line_x + line_w, line_y + 4)],
        radius=2, fill=config["accent"]
    )

    # Save
    output_path = os.path.join(OUTPUT_DIR, config["output"])
    canvas.convert('RGB').save(output_path, "PNG", quality=95)
    return output_path, None


def main():
    print("=" * 60)
    print("NetMonitor — App Store Screenshot Generator")
    print("=" * 60)
    print(f"\nSource folder: {SOURCE_DIR}")
    print(f"Output folder: {OUTPUT_DIR}")
    print(f"Canvas size:   {CANVAS_W} x {CANVAS_H} (iPhone 16 Pro Max)\n")

    # Check which source files exist
    missing = []
    for s in SLIDES:
        path = os.path.join(SOURCE_DIR, s["source"])
        if not os.path.exists(path):
            missing.append(s["source"])

    if missing:
        print(f"WARNING: {len(missing)} source screenshot(s) missing from {SOURCE_DIR}/")
        for m in missing:
            print(f"  - {m}")
        print(f"\nSave your screenshots with these names to {SOURCE_DIR}/")
        print("Then re-run this script.\n")

    created = 0
    for i, slide in enumerate(SLIDES):
        label = slide["headline"].split("\n")[0]
        result, err = create_slide(slide)
        if result:
            print(f"  [{i+1:2d}/10] ✓ {label:<25s} → {slide['output']}")
            created += 1
        else:
            print(f"  [{i+1:2d}/10] ✗ {label:<25s}   ({err})")

    print(f"\nGenerated {created}/10 screenshots.")
    if created < 10:
        print(f"Add missing source images to: {SOURCE_DIR}/")
    else:
        print(f"All screenshots ready in: {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
