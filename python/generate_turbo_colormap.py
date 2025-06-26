from turbo_colormap import turbo_colormap_data as colormap

with open("turbo_colormap.hex", "w") as file:
    for [fr,fg,fb] in colormap:
        r = round(fr * 255)
        g = round(fg * 255)
        b = round(fb * 255)
        file.write(f"{r:02X}{g:02X}{b:02X}\n")
