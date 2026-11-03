import os, re, subprocess, html as H

CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe"
CSS = open("C:/Users/pc/Desktop/FVH/Dokumentacija/_rad/stil.css", encoding="utf-8").read()
CSS += """
  .fig-sans text { font-family: Arial, Helvetica, sans-serif; }
  td code, th code { font-size: 9pt; }
  .stanje-ok { font-weight: bold; }
  .stanje-ceka { font-style: italic; }
"""

FONT = "Arial, Helvetica, sans-serif"


def esc(s):
    return H.escape(s, quote=False)


# ------------------------------------------------------------------ SVG pomocnici
class Svg:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.el = []

    def box(self, x, y, w, h, lines, fill="#ffffff", bold_first=False, dash=False,
            size=11, stroke="#000", sw=1, rx=3, align="middle", valign="middle", label=None):
        d = ' stroke-dasharray="5,3"' if dash else ""
        self.el.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
                       f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
        if isinstance(lines, str):
            lines = [lines]
        lh = size * 1.25
        if valign == "top":
            y0 = y + size + 5
        else:
            y0 = y + h / 2 - (len(lines) - 1) * lh / 2 + size * 0.36
        if align == "middle":
            tx = x + w / 2
        else:
            tx = x + 8
        for i, t in enumerate(lines):
            fw = "bold" if (bold_first and i == 0) else "normal"
            fs = size if i == 0 or not bold_first else size - 1
            self.el.append(f'<text x="{tx}" y="{y0 + i * lh:.1f}" font-size="{fs}" '
                           f'font-weight="{fw}" text-anchor="{"middle" if align == "middle" else "start"}">{esc(t)}</text>')

    def text(self, x, y, t, size=11, anchor="start", bold=False, italic=False, rot=None, fill="#000", halo=False):
        a = f' transform="rotate({rot} {x} {y})"' if rot else ""
        if halo:
            a += ' stroke="#fff" stroke-width="4" paint-order="stroke"'
        st = ' font-style="italic"' if italic else ""
        self.el.append(f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" '
                       f'font-weight="{"bold" if bold else "normal"}"{st} fill="{fill}"{a}>{esc(t)}</text>')

    def line(self, pts, arrow=True, back=False, dash=False, sw=1.1, color="#000"):
        p = " ".join(f"{x},{y}" for x, y in pts)
        m = ' marker-end="url(#strelica)"' if arrow else ""
        b = ' marker-start="url(#strelica_poc)"' if back else ""
        d = ' stroke-dasharray="5,3"' if dash else ""
        self.el.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{sw}"{m}{b}{d}/>')

    def raw(self, s):
        self.el.append(s)

    def svg(self):
        defs = ('<defs>'
                '<marker id="strelica" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
                '<path d="M0,0 L10,5 L0,10 z" fill="#000"/></marker>'
                '<marker id="strelica_poc" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
                '<path d="M10,0 L0,5 L10,10 z" fill="#000"/></marker>'
                '</defs>')
        return (f'<svg xmlns="http://www.w3.org/2000/svg" class="fig-sans" viewBox="0 0 {self.w} {self.h}" '
                f'width="{self.w}" height="{self.h}" font-family="{FONT}">'
                f'<rect x="0" y="0" width="{self.w}" height="{self.h}" fill="#fff"/>' + defs + "".join(self.el) + "</svg>")


# ------------------------------------------------------------------ tabele
def tabela(broj, naslov, zaglavlje, redovi, poravnanje=None):
    """redovi: lista listi celija (vec HTML). poravnanje: lista '', 'c', 'n' po koloni."""
    if poravnanje is None:
        poravnanje = [""] * len(zaglavlje)
    th = "".join(f'<th>{z}</th>' for z in zaglavlje)
    tr = []
    for r in redovi:
        cls = ""
        if isinstance(r, tuple):   # (red, 'sep')
            r, cls = r
        tds = "".join(f'<td class="{poravnanje[i]}">{c}</td>' for i, c in enumerate(r))
        tr.append(f'<tr class="{cls}">{tds}</tr>')
    return (f'<table><caption><b>Tabela {broj}.</b> {naslov}</caption>'
            f'<thead><tr>{th}</tr></thead><tbody>{"".join(tr)}</tbody></table>')


# ------------------------------------------------------------------ renderovanje
def _url(p):
    return "file:///" + p.replace("\\", "/")


def snimi_png(sadrzaj, png, sirina=760):
    tmp = png[:-4] + "__tmp.html"
    page = ('<!doctype html><html><head><meta charset="utf-8"><style>' + CSS +
            f' body{{margin:0;padding:14px;width:{sirina - 28}px;background:#fff}}'
            ' table{margin-top:0}</style></head><body>' + sadrzaj +
            '<script>document.title=String(Math.ceil(document.body.getBoundingClientRect().height))</script>'
            '</body></html>')
    open(tmp, "w", encoding="utf-8").write(page)
    r = subprocess.run([CHROME, "--headless", "--disable-gpu", "--dump-dom", _url(tmp)],
                       capture_output=True, text=True, encoding="utf-8", timeout=120)
    m = re.search(r"<title>(\d+)</title>", r.stdout)
    h = int(m.group(1)) if m else 1000
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=2", f"--window-size={sirina},{h}",
                    f"--screenshot={png}", _url(tmp)], capture_output=True, timeout=120)
    os.remove(tmp)


def snimi_pdf(html_fajl, pdf):
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                    "--print-to-pdf-no-header", f"--print-to-pdf={pdf}", _url(html_fajl)],
                   capture_output=True, timeout=180)


# ------------------------------------------------------------------ dokument
class Dokument:
    def __init__(self, izlaz, ime):
        self.izlaz = izlaz
        self.ime = ime
        os.makedirs(os.path.join(izlaz, "slike"), exist_ok=True)
        os.makedirs(os.path.join(izlaz, "tabele"), exist_ok=True)
        self.delovi = []
        self.toc = []
        self.n_sl = 0
        self.n_tab = 0
        self.slike = []
        self.tabele = []

    def h1(self, t, first=False):
        self.toc.append(("l1", t))
        self.delovi.append(f'<h1{" class=\"first\"" if first else ""}>{t}</h1>')

    def h2(self, t):
        self.toc.append(("l2", t))
        self.delovi.append(f"<h2>{t}</h2>")

    def h3(self, t):
        self.delovi.append(f"<h3>{t}</h3>")

    def p(self, t, noind=False):
        self.delovi.append(f'<p{" class=\"noind\"" if noind else ""}>{t}</p>')

    def html(self, t):
        self.delovi.append(t)

    def pre(self, t):
        self.delovi.append(f"<pre>{esc(t)}</pre>")

    def note(self, t):
        self.delovi.append(f'<div class="note"><p>{t}</p></div>')

    def ul(self, stavke):
        self.delovi.append('<ul class="plain">' + "".join(f"<li>{s}</li>" for s in stavke) + "</ul>")

    def slika(self, svg_obj, ime, opis):
        self.n_sl += 1
        n = self.n_sl
        svg = svg_obj.svg()
        osnova = os.path.join(self.izlaz, "slike", f"slika_{n:02d}_{ime}")
        open(osnova + ".svg", "w", encoding="utf-8").write(svg)
        cap = f"<figcaption><b>Slika {n}.</b> {opis}</figcaption>"
        self.slike.append((osnova, svg, cap, svg_obj.w))
        self.delovi.append(f"<figure>{svg}{cap}</figure>")
        return n

    def slika_fajl(self, putanja, ime, opis, sirina="100%"):
        """Gotova slika ekrana (PNG): kopira se u slike/ i ubacuje u dokument."""
        import shutil
        self.n_sl += 1
        n = self.n_sl
        naziv = f"slika_{n:02d}_{ime}.png"
        shutil.copyfile(putanja, os.path.join(self.izlaz, "slike", naziv))
        cap = f"<figcaption><b>Slika {n}.</b> {opis}</figcaption>"
        self.delovi.append(f'<figure><img src="slike/{naziv}" style="width:{sirina};border:1px solid #999">{cap}</figure>')
        return n

    def tabela(self, ime, naslov, zaglavlje, redovi, poravnanje=None):
        self.n_tab += 1
        n = self.n_tab
        t = tabela(n, naslov, zaglavlje, redovi, poravnanje)
        self.tabele.append((os.path.join(self.izlaz, "tabele", f"tabela_{n:02d}_{ime}.png"), t))
        self.delovi.append(t)
        return n

    def sledeca_slika(self):
        return self.n_sl + 1

    def sledeca_tabela(self):
        return self.n_tab + 1

    def napravi(self, naslov_html, naslovna):
        toc = '<div class="toc"><h1>Sadržaj</h1><ul>' + "".join(
            f'<li class="{c}">{t}</li>' for c, t in self.toc) + "</ul></div>"
        doc = ('<!doctype html><html lang="sr"><head><meta charset="utf-8"><title>' + naslov_html +
               "</title><style>" + CSS + "</style></head><body>" + naslovna + toc +
               "".join(self.delovi) + "</body></html>")
        hf = os.path.join(self.izlaz, self.ime + ".html")
        open(hf, "w", encoding="utf-8").write(doc)
        snimi_pdf(hf, os.path.join(self.izlaz, self.ime + ".pdf"))
        for osnova, svg, cap, w in self.slike:
            snimi_png(f"<figure style='margin:0'>{svg}{cap}</figure>", osnova + ".png", sirina=w + 40)
        for png, t in self.tabele:
            snimi_png(t, png, sirina=760)
