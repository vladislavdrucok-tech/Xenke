"""Decodes screenshots printed by tools/shots_b64.py from a saved CI log.  python3 tools/shots_decode.py log.txt out_dir"""
import base64
import os
import re
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
os.makedirs(sys.argv[2], exist_ok=True)
for m in re.finditer(r"=====SHOT (\S+) \d+\n(.*?)=====END", text, re.S):
    data = "".join(re.sub(r"^\S*Z ", "", line).strip() for line in m.group(2).splitlines())
    with open(os.path.join(sys.argv[2], m.group(1)), "wb") as f:
        f.write(base64.b64decode(data))
    print("decoded", m.group(1))
