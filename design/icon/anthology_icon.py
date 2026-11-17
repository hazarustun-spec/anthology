"""Anthology app icon — "who wrote it" rows.
Three note lines, each led by a glassy sage disc naming its author: sparkle (AI), pencil (you), check (done).
Outputs full-bleed 1024 art for light / dark / tinted, plus the macOS tile. Run: python3 anthology_icon.py"""
import subprocess

W = 1024
ROWS = [  # (y, line length, disc gradient, glyph)
    (292, 420, ("#5E9C55", "#2E5E2A"), "sparkle"),
    (512, 366, ("#86BE7B", "#4E8A47"), "pencil"),
    (732, 262, ("#B4DAA9", "#7CB571"), "check"),
]
DISC_X, R = 290, 92
LINE_X, LINE_T = 432, 42

def palette(mode):
    if mode == "dark":
        return dict(bg=("#262D25", "#151A14"), line=("#4A5547", "#3D473B"), glyph="#FFFFFF", rim="#000000", hi=0.22)
    if mode == "tinted":  # grayscale; the system tints it
        return dict(bg=("#1A1A1A", "#0D0D0D"), line=("#5A5A5A", "#4A4A4A"), glyph="#FFFFFF", rim="#000000", hi=0.18)
    return dict(bg=("#FFFFFF", "#ECEEEA"), line=("#D3D7CF", "#C5CAC1"), glyph="#FFFFFF", rim="#1E3D1B", hi=0.38)

def disc_colors(mode, pair):
    if mode == "tinted":
        return ("#D9D9D9", "#9A9A9A")
    return pair

def glyph(kind, cx, cy, color):
    if kind == "sparkle":
        r, k = 50, 10
        return (f'<path d="M{cx},{cy-r} C{cx+k},{cy-k} {cx+k},{cy-k} {cx+r},{cy} C{cx+k},{cy+k} {cx+k},{cy+k} {cx},{cy+r} '
                f'C{cx-k},{cy+k} {cx-k},{cy+k} {cx-r},{cy} C{cx-k},{cy-k} {cx-k},{cy-k} {cx},{cy-r} Z" fill="{color}"/>')
    if kind == "pencil":
        # body + tip, rotated 45°
        return (f'<g transform="rotate(-45 {cx} {cy})">'
                f'<rect x="{cx-15}" y="{cy-50}" width="30" height="70" rx="6" fill="{color}"/>'
                f'<path d="M{cx-15},{cy+26} L{cx+15},{cy+26} L{cx},{cy+52} Z" fill="{color}"/>'
                f'<rect x="{cx-15}" y="{cy-32}" width="30" height="6" fill="#000" opacity="0.18"/></g>')
    return (f'<path d="M{cx-36},{cy+2} L{cx-11},{cy+29} L{cx+38},{cy-27}" fill="none" stroke="{color}" '
            f'stroke-width="19" stroke-linecap="round" stroke-linejoin="round"/>')

def art(mode):
    p = palette(mode)
    defs = [f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{p["bg"][0]}"/><stop offset="1" stop-color="{p["bg"][1]}"/></linearGradient>',
            f'<linearGradient id="ln" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{p["line"][0]}"/><stop offset="1" stop-color="{p["line"][1]}"/></linearGradient>',
            '<linearGradient id="hi" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>',
            '<filter id="ds" x="-40%" y="-40%" width="180%" height="190%"><feDropShadow dx="0" dy="8" stdDeviation="9" flood-color="#0F1F0D" flood-opacity="0.22"/></filter>',
            '<filter id="ls" x="-10%" y="-60%" width="120%" height="260%"><feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.06"/></filter>']
    body = [f'<rect width="{W}" height="{W}" fill="url(#bg)"/>']
    for i, (y, ln, pair, kind) in enumerate(ROWS):
        top, bot = disc_colors(mode, pair)
        defs.append(f'<linearGradient id="d{i}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>')
        body.append(f'<g filter="url(#ls)"><rect x="{LINE_X}" y="{y-LINE_T/2}" width="{ln}" height="{LINE_T}" rx="{LINE_T/2}" fill="url(#ln)"/></g>')
        body.append(f'<g filter="url(#ds)"><circle cx="{DISC_X}" cy="{y}" r="{R}" fill="url(#d{i})"/></g>')
        # glass: soft top highlight and a hairline rim
        body.append(f'<ellipse cx="{DISC_X}" cy="{y-R*0.45}" rx="{R*0.72}" ry="{R*0.42}" fill="url(#hi)" opacity="{p["hi"]}"/>')
        body.append(f'<circle cx="{DISC_X}" cy="{y}" r="{R-1}" fill="none" stroke="{p["rim"]}" stroke-opacity="0.18" stroke-width="2"/>')
        body.append(glyph(kind, DISC_X, y, p["glyph"]))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}"><defs>{"".join(defs)}</defs>{"".join(body)}</svg>'

def mac_tile(src_svg):
    inner = src_svg[src_svg.index('</defs>') + 7:src_svg.rindex('</svg>')]
    defs = src_svg[src_svg.index('<defs>') + 6:src_svg.index('</defs>')]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}"><defs>{defs}'
            '<filter id="ts" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.25"/></filter>'
            '<clipPath id="sq"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath></defs>'
            '<g filter="url(#ts)"><rect x="100" y="100" width="824" height="824" rx="185" fill="#fff"/></g>'
            f'<g clip-path="url(#sq)"><g transform="translate(100,100) scale(0.8047)">{inner}</g></g></svg>')

if __name__ == "__main__":
    for mode in ("light", "dark", "tinted"):
        s = art(mode)
        open(f"C-{mode}.svg", "w").write(s)
        subprocess.run(["rsvg-convert", "-w", "1024", f"C-{mode}.svg", "-o", f"C-{mode}.png"], check=True)
    open("C-mac.svg", "w").write(mac_tile(art("light")))
    subprocess.run(["rsvg-convert", "-w", "1024", "C-mac.svg", "-o", "C-mac.png"], check=True)
    print("ok")
