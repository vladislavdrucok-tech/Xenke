"""Copy the game's sprite atlases into the Godot project and turn the JS layout modules into JSON.
python3 godot/tools/export_assets.py   (from the repo root)"""
import json,re,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2];dist=root/'dist/assets';out=root/'godot/assets';data=root/'godot/data'
out.mkdir(exist_ok=True);data.mkdir(exist_ok=True)
def mjs(name):return json.loads(re.search(r'export default (\{.*\});',(dist/name).read_text(),re.S).group(1))
for f in ['hero-einstein.webp','hero-mira.webp','props.webp','held.webp','expedition-world.webp','portrait-einstein.webp','portrait-mira.webp','items.webp']:shutil.copy(dist/f,out/f)
heroes=mjs('heroes.mjs');json.dump({'einstein':heroes['einstein'],'mira':heroes['curie']},open(data/'heroes.json','w'))
json.dump(mjs('props-layout.mjs'),open(data/'props.json','w'));json.dump(mjs('held-layout.mjs'),open(data/'held.json','w'));json.dump(mjs('items-layout.mjs'),open(data/'items.json','w'))
print('ok')
