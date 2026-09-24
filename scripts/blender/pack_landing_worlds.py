"""Pack aligned Blender passes. Uses the already-installed Pillow; no downloads."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('/tmp/gigacouch-world-renders')
OUT = ROOT / 'crates/platform/site/worlds'
OUT.mkdir(parents=True, exist_ok=True)
for name in ('jet', 'car', 'wizard'):
    images = [Image.open(SOURCE / f'{name}-{stage}.png').convert('RGBA') for stage in ('wire', 'clay', 'final')]
    assert all(i.size == images[0].size for i in images)
    boxes = [i.getchannel('A').getbbox() for i in images]
    # One shared crop maintains alignment through every scan; a transparent gutter
    # prevents linear filtering from bleeding between neighboring atlas cells.
    bounds = (max(0, min(b[0] for b in boxes)-8), max(0, min(b[1] for b in boxes)-8),
              min(images[0].width, max(b[2] for b in boxes)+8), min(images[0].height, max(b[3] for b in boxes)+8))
    cells = [i.crop(bounds) for i in images]
    w, h = cells[0].size
    # Keep the complete atlas within WebGL 1's minimum 2048px texture limit.
    if w > 672:
        h = round(h*672/w); w = 672
        cells = [i.resize((w, h), Image.Resampling.LANCZOS) for i in cells]
    atlas = Image.new('RGBA', (w*3, h))
    for index, cell in enumerate(cells): atlas.paste(cell, (index*w, 0))
    atlas.save(OUT / f'{name}.png', optimize=True)
    print(name, atlas.size, (OUT / f'{name}.png').stat().st_size)
