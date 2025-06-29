from turbo_colormap import turbo_colormap_data as colormap
from colormaps import _magma_data, _inferno_data

with open("../src/memory/magma_colormap.hex", "w") as file:
    for [fr,fg,fb] in _magma_data:
        r = round(fr * 255)
        g = round(fg * 255)
        b = round(fb * 255)
        file.write(f"{r:02X}{g:02X}{b:02X}\n")

with open("../src/memory/inferno_colormap.hex", "w") as file:
    for [fr,fg,fb] in _inferno_data:
        r = round(fr * 255)
        g = round(fg * 255)
        b = round(fb * 255)
        file.write(f"{r:02X}{g:02X}{b:02X}\n")

with open("../src/memory/turbo_colormap.hex", "w") as file:
    for [fr,fg,fb] in colormap:
        r = round(fr * 255)
        g = round(fg * 255)
        b = round(fb * 255)
        file.write(f"{r:02X}{g:02X}{b:02X}\n")
