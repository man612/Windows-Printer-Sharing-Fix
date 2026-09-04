from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets"
W, H = 1280, 640

BG = "#0d1117"
PANEL = "#161b22"
BORDER = "#30363d"
TEXT = "#f0f6fc"
MUTED = "#8b949e"
BLUE = "#58a6ff"
GREEN = "#3fb950"
YELLOW = "#d29922"

SEGOE = Path(r"C:\Windows\Fonts\segoeui.ttf")
SEGOE_BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")
CONSOLA = Path(r"C:\Windows\Fonts\consola.ttf")
CONSOLA_BOLD = Path(r"C:\Windows\Fonts\consolab.ttf")


def font(path: Path, size: int):
    if not path.exists():
        raise FileNotFoundError(f"Required font not found: {path}")
    return ImageFont.truetype(str(path), size)


def text(draw, xy, value, fill, face):
    draw.text(xy, value, fill=fill, font=face)


def assert_fits(draw, value, face, x, max_x, label):
    box = draw.textbbox((x, 0), value, font=face)
    if box[2] > max_x:
        raise RuntimeError(f"{label} exceeds layout boundary: {box[2]} > {max_x}")


def build_artwork():
    image = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(image)

    draw.line((0, 1, W, 1), fill=BORDER, width=2)

    left_x = 112
    left_max_x = 606
    panel_x, panel_y = 650, 86
    panel_w, panel_h = 548, 472
    panel_right = panel_x + panel_w

    title = font(SEGOE_BOLD, 48)
    subtitle = font(SEGOE, 21)
    body = font(SEGOE, 18)
    small = font(SEGOE, 16)
    mono = font(CONSOLA, 18)
    mono_bold = font(CONSOLA_BOLD, 18)

    text(draw, (left_x, 136), "Windows Printer", TEXT, title)
    text(draw, (left_x, 188), "Sharing Fix", BLUE, title)

    sub1 = "Diagnosis-first PowerShell TUI for"
    sub2 = "Windows printer-sharing troubleshooting."
    assert_fits(draw, sub1, subtitle, left_x, left_max_x, "subtitle line 1")
    assert_fits(draw, sub2, subtitle, left_x, left_max_x, "subtitle line 2")
    text(draw, (left_x, 280), sub1, MUTED, subtitle)
    text(draw, (left_x, 310), sub2, MUTED, subtitle)

    flow = "Diagnose -> smallest repair -> verify / restore"
    assert_fits(draw, flow, small, left_x, left_max_x, "workflow line")
    text(draw, (left_x, 364), flow, GREEN, small)
    text(draw, (left_x, 408), "Windows 10  |  Windows 11  |  Windows Server", MUTED, small)
    text(draw, (left_x, 520), "PowerShell 5.1+  |  MIT  |  EN / ID", MUTED, small)

    draw.rounded_rectangle(
        (panel_x, panel_y, panel_right, panel_y + panel_h),
        radius=4, fill=PANEL, outline=BORDER, width=2
    )

    px = panel_x + 38
    py = panel_y + 36
    text(draw, (px, py), "WINDOWS PRINTER SHARING FIX  v4.0.2", BLUE, mono_bold)
    text(draw, (px, py + 34), "Diagnosis-first repair utility", MUTED, mono)
    draw.line((px, py + 76, panel_right - 38, py + 76), fill=BORDER, width=2)

    menu_y = py + 104
    menu = [
        ("[1] Diagnose this PC   <RECOMMENDED>", GREEN, mono_bold),
        ("[2] Safe Repair", TEXT, mono),
        ("[3] Compatibility Repair (Advanced)", TEXT, mono),
        ("[4] Legacy Compatibility (High Risk)", YELLOW, mono),
        ("[5] Restore latest managed changes", TEXT, mono),
        ("[6] Tools and Logs", TEXT, mono),
        ("[7] Guide   [8] Language   [9] Exit", TEXT, mono),
    ]
    for i, (line, color, face) in enumerate(menu):
        assert_fits(draw, line, face, px, panel_right - 34, f"terminal line {i + 1}")
        text(draw, (px, menu_y + i * 36), line, color, face)

    footer = "Safe Repair never lowers Windows security protections."
    footer_face = font(SEGOE, 15)
    assert_fits(draw, footer, footer_face, px, panel_right - 34, "terminal footer")
    text(draw, (px, panel_y + panel_h - 56), footer, MUTED, footer_face)

    OUT.mkdir(parents=True, exist_ok=True)
    hero = OUT / "hero-v2.png"
    preview = OUT / "social-preview.png"
    image.save(hero, optimize=True)
    image.save(preview, optimize=True)
    print(f"Wrote {hero}")
    print(f"Wrote {preview}")


if __name__ == "__main__":
    build_artwork()
