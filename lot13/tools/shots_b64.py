"""CI helper: prints screenshots from --shots as compact base64 so they can be read back from the job log.
python3 tools/shots_b64.py <dir> [names...]   (decode with tools/shots_decode.py)"""
import base64
import io
import os
import sys
from PIL import Image

d = sys.argv[1]
only = set(sys.argv[2:])
for f in sorted(os.listdir(d)):
    if not f.endswith(".png") or (only and f[:-4] not in only):
        continue
    img = Image.open(os.path.join(d, f)).convert("RGB").quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    b = base64.b64encode(buf.getvalue()).decode()
    print(f"=====SHOT {f} {len(b)}")
    for i in range(0, len(b), 3000):
        print(b[i:i + 3000])
    print("=====END")
