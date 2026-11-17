"""Draws assets/fonts/JungleSymbols.ttf: the few symbols the game writes that neither Silkscreen nor
Fredoka has (the coin ◈, the level pips ● ○, the stars ★, the turn arrow ↻, the minus sign −).

A browser or a PC finds them in a system font; Godot in a browser or on a phone has none to look in.
They are drawn here on Silkscreen's own grid (8 pixels to the em, 125 units each, capitals 5 pixels
tall), so they stay as sharp as its letters. main.gd gives this font to both typefaces as a fallback.

    python tools/make_symbols.py
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

PX = 125                # one pixel of the grid, in font units (Silkscreen: 1000 to the em, 8 pixels)

# Each picture: rows from the top; '#' is a pixel. `top` is the row of the top line, in pixels above the
# baseline (5 = the top of a capital letter).
GLYPHS = {
    '◈': (6, [
        '...#...',
        '..#.#..',
        '.#.#.#.',
        '#.###.#',
        '.#.#.#.',
        '..#.#..',
        '...#...',
    ]),
    '●': (5, [
        '.###.',
        '#####',
        '#####',
        '#####',
        '.###.',
    ]),
    '○': (5, [
        '.###.',
        '#...#',
        '#...#',
        '#...#',
        '.###.',
    ]),
    '★': (6, [
        '...#...',
        '..###..',
        '#######',
        '.#####.',
        '..###..',
        '.##.##.',
        '.#...#.',
    ]),
    '↻': (6, [
        '..###.#',
        '.#...##',
        '#...###',
        '#......',
        '#.....#',
        '.#...#.',
        '..###..',
    ]),
    '−': (3, [
        '#####',
    ]),
}


def draw(rows, top):
    pen = TTGlyphPen(None)
    for r, line in enumerate(rows):
        y1 = (top - r) * PX                       # top edge of this row
        y0 = y1 - PX
        c = 0
        while c < len(line):                       # one rectangle per run of pixels
            if line[c] != '#':
                c += 1
                continue
            start = c
            while c < len(line) and line[c] == '#':
                c += 1
            x0, x1 = (start + 1) * PX, (c + 1) * PX   # one pixel of side bearing, as Silkscreen
            pen.moveTo((x0, y0))
            pen.lineTo((x0, y1))
            pen.lineTo((x1, y1))
            pen.lineTo((x1, y0))
            pen.closePath()
    return pen.glyph()


def main():
    order = ['.notdef', 'space'] + ['uni%04X' % ord(ch) for ch in GLYPHS]
    glyphs = {'.notdef': TTGlyphPen(None).glyph(), 'space': TTGlyphPen(None).glyph()}
    metrics = {'.notdef': (500, 0), 'space': (375, 0)}
    cmap = {32: 'space'}
    for ch, (top, rows) in GLYPHS.items():
        name = 'uni%04X' % ord(ch)
        glyphs[name] = draw(rows, top)
        metrics[name] = ((len(rows[0]) + 2) * PX, PX)
        cmap[ord(ch)] = name
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=1030, descent=-250)
    fb.setupNameTable({'familyName': 'Jungle Symbols', 'styleName': 'Regular'})
    fb.setupOS2(sTypoAscender=1030, sTypoDescender=-250, usWinAscent=1030, usWinDescent=250)
    fb.setupPost()
    out = Path(__file__).resolve().parent.parent / 'assets' / 'fonts' / 'JungleSymbols.ttf'
    fb.save(str(out))
    print('written', out)


if __name__ == '__main__':
    main()
