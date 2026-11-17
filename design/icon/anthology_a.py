"""Anthology app icon: our own geometric A (Futura-like proportions, flat apex),
sage gradient on white. Writes final.svg (rounded preview) and art.svg (full-bleed square for the OS to mask)."""
import subprocess
W = 1024
h, Wd = 560.0, 585.0
cx, top = 512.0, (W - h) / 2 + 22
bot = top + h
tw = 0.24 * Wd           # flat apex width
f = 0.255 * Wd           # foot width
TL, TR = (cx - tw / 2, top), (cx + tw / 2, top)
BLo, BRo = (cx - Wd / 2, bot), (cx + Wd / 2, bot)
Li, Ri = (cx - Wd / 2 + f, bot), (cx + Wd / 2 - f, bot)

def x_on(p, d, y):  # x where the line through p with direction d reaches y
    return p[0] + d[0] * (y - p[1]) / d[1]
dl = (TL[0] - BLo[0], TL[1] - BLo[1])
dr = (TR[0] - BRo[0], TR[1] - BRo[1])
# counter apex: intersection of the inner edges
# Li + s*dl = Ri + u*dr  -> solve in x,y
I = (cx, bot - 0.705 * h)
dl = (I[0] - Li[0], I[1] - Li[1]); dr = (I[0] - Ri[0], I[1] - Ri[1])
yb, yt = bot - 0.18 * h, bot - 0.37 * h
p = lambda q: f"{q[0]:.1f},{q[1]:.1f}"
outer = [TL, TR, BRo, Ri, (x_on(Ri, dr, yb), yb), (x_on(Li, dl, yb), yb), Li, BLo]
hole = [(x_on(Li, dl, yt), yt), I, (x_on(Ri, dr, yt), yt)]
D = "M" + " L".join(p(q) for q in outer) + " Z M" + " L".join(p(q) for q in hole) + " Z"

DEFS = f'''
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#EDF1EB"/></linearGradient>
<linearGradient id="fill" x1="0.15" y1="0" x2="0.85" y2="1">
  <stop offset="0" stop-color="#86BE7C"/><stop offset="0.5" stop-color="#4C8445"/><stop offset="1" stop-color="#22461F"/>
</linearGradient>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.28"/><stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
<filter id="cast" filterUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{W}"><feGaussianBlur stdDeviation="24"/></filter>
<clipPath id="clipA"><path d="{D}" fill-rule="evenodd"/></clipPath>
'''
LETTER = (f'<g filter="url(#cast)" opacity="0.26" transform="translate(0,22)"><path d="{D}" fill-rule="evenodd" fill="#1D3A1A"/></g>'
          f'<path d="{D}" fill-rule="evenodd" fill="url(#fill)"/>'
          f'<g clip-path="url(#clipA)"><rect x="0" y="{top-10:.0f}" width="{W}" height="{h+20:.0f}" fill="url(#gloss)"/></g>')

def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}"><defs>{DEFS}</defs>{body}</svg>'
open("art.svg", "w").write(svg(f'<rect width="{W}" height="{W}" fill="url(#bg)"/>' + LETTER))
open("final.svg", "w").write(svg(f'<rect width="{W}" height="{W}" rx="230" fill="url(#bg)"/>' + LETTER))
for n in ("art", "final"):
    subprocess.run(["rsvg-convert", "-w", "1024", f"{n}.svg", "-o", f"{n}.png"], check=True)
print("ok")
