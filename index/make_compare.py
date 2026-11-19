"""make_compare.py: before/after figure pairs for the rerun gate.

Run from index/:  /usr/bin/python3 -I make_compare.py ../../paper_equity/.contract/r0/compare
Reads published/<name>.png (as-published snapshot) and test/<name>.png (rerun), flattens
transparency onto white, resizes to 1400 px wide and writes <name>_before.png / _after.png
plus figures.json.
"""
import json, os, sys
from datetime import datetime
from PIL import Image

NAMES = ["lines_overall", "twoway_bars", "bars_race", "bars_income", "bars_age", "bars_edu",
         "slopes_by_type", "sensitivity_distance", "sensitivity_scatterplot",
         "sensitivity_distance_pollutant", "map", "plot"]

def flat(path):
    im = Image.open(path)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        bg = Image.new("RGB", im.size, "white")
        bg.paste(im, mask=im.split()[-1])
        return bg
    return im.convert("RGB")

def main(out):
    os.makedirs(out, exist_ok=True)
    rows = []
    for n in NAMES:
        rec = {"name": n}
        for tag, src in (("before", f"published/{n}.png"), ("after", f"test/{n}.png")):
            im = flat(src)
            rec[f"{tag}_wh"] = list(im.size)
            rec[f"{tag}_mtime"] = datetime.fromtimestamp(os.path.getmtime(src)).isoformat(timespec="seconds")
            w = 1400
            im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
            dst = f"{n}_{tag}.png"
            im.save(os.path.join(out, dst), optimize=True)
            rec[tag] = dst
        rows.append(rec)
    json.dump(rows, open(os.path.join(out, "figures.json"), "w"), indent=1)
    print(f"wrote {len(rows)} pairs to {out}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "../../paper_equity/.contract/r0/compare")
