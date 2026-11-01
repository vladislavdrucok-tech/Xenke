#!/bin/sh
# Unpack one 'Afterfall_Rest_PNG_NN.zip' into art/rest and check each PNG against the pack's manifest.
set -e
Z="$1"; T=$(mktemp -d)
unzip -q -o "$Z" -d "$T"
cp -r "$T"/Afterfall_Remaining/* art/rest/
python3 - "$T" <<'PY'
import json,hashlib,os,sys
T=sys.argv[1];m=json.load(open('art/rest/assets_manifest.json'))
for a in m['assets']:
    p=os.path.join(T,a['zip_name'])
    if os.path.exists(p):
        ok=hashlib.sha256(open(p,'rb').read()).hexdigest()==a['sha256']
        print(a['asset_id'],'OK' if ok else 'BAD',f"{a['width']}x{a['height']}",'alpha' if a['alpha'] else 'opaque','|',a['group_label'][:30],'|',a['name'][:60])
PY
rm -rf "$T"
