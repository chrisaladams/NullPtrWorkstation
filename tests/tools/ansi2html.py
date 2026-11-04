#!/usr/bin/env python3
"""Convert a `tmux capture-pane -e -p` dump (ANSI SGR colours) to an HTML page.
usage: ansi2html.py INPUT.ansi OUTPUT.html [title]   (then: node html2png.js OUTPUT.html OUT.png)"""
import html, re, sys
BG, FG = "#1a1b26", "#c0caf5"
PAL16 = ["#15161e","#f7768e","#9ece6a","#e0af68","#7aa2f7","#bb9af7","#7dcfff","#a9b1d6",
         "#414868","#f7768e","#9ece6a","#e0af68","#7aa2f7","#bb9af7","#7dcfff","#c0caf5"]
def x256(n):
    if n < 16: return PAL16[n]
    if n < 232:
        n -= 16; r, g, b = n // 36, (n // 6) % 6, n % 6
        f = lambda v: 0 if v == 0 else 55 + v * 40
        return "#%02x%02x%02x" % (f(r), f(g), f(b))
    v = 8 + (n - 232) * 10; return "#%02x%02x%02x" % (v, v, v)
def convert(text):
    out, st = [], {"fg": None, "bg": None, "b": False, "i": False, "u": False, "rev": False}
    def span(s):
        if not s: return
        fg, bg = st["fg"], st["bg"]
        if st["rev"]: fg, bg = (bg or BG), (fg or FG)
        css = []
        if fg: css.append("color:%s" % fg)
        if bg: css.append("background:%s" % bg)
        if st["b"]: css.append("font-weight:bold")
        if st["i"]: css.append("font-style:italic")
        if st["u"]: css.append("text-decoration:underline")
        out.append('<span style="%s">%s</span>' % (";".join(css), html.escape(s)))
    pos = 0
    for m in re.finditer(r"\x1b\[([0-9;:]*)m", text):
        span(text[pos:m.start()]); pos = m.end()
        codes = [int(c) if c else 0 for c in re.split("[;:]", m.group(1) or "0")]
        i = 0
        while i < len(codes):
            c = codes[i]
            if c == 0: st.update(fg=None, bg=None, b=False, i=False, u=False, rev=False)
            elif c == 1: st["b"] = True
            elif c == 3: st["i"] = True
            elif c == 4: st["u"] = True
            elif c == 7: st["rev"] = True
            elif c in (22,): st["b"] = False
            elif c == 23: st["i"] = False
            elif c == 24: st["u"] = False
            elif c == 27: st["rev"] = False
            elif 30 <= c <= 37: st["fg"] = PAL16[c - 30]
            elif 90 <= c <= 97: st["fg"] = PAL16[c - 90 + 8]
            elif 40 <= c <= 47: st["bg"] = PAL16[c - 40]
            elif 100 <= c <= 107: st["bg"] = PAL16[c - 100 + 8]
            elif c == 39: st["fg"] = None
            elif c == 49: st["bg"] = None
            elif c in (38, 48) and i + 1 < len(codes):
                key = "fg" if c == 38 else "bg"
                if codes[i + 1] == 2 and i + 4 < len(codes):
                    st[key] = "#%02x%02x%02x" % tuple(codes[i + 2:i + 5]); i += 4
                elif codes[i + 1] == 5 and i + 2 < len(codes):
                    st[key] = x256(codes[i + 2]); i += 2
            i += 1
    span(text[pos:])
    return "".join(out)
src, dst = sys.argv[1], sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else ""
body = convert(open(src, encoding="utf-8", errors="replace").read())
page = f"""<!doctype html><meta charset=utf-8><style>
body{{margin:0;background:{BG}}} .t{{color:#565f89;font:13px 'JetBrainsMono Nerd Font',monospace;padding:6px 10px;border-bottom:1px solid #292e42}}
pre{{margin:0;padding:8px 10px;color:{FG};background:{BG};font:15px/1.25 'JetBrainsMono Nerd Font Mono','JetBrainsMono Nerd Font',monospace;white-space:pre}}
</style>{'<div class=t>'+html.escape(title)+'</div>' if title else ''}<pre>{body}</pre>"""
open(dst, "w", encoding="utf-8").write(page)
print(dst)
