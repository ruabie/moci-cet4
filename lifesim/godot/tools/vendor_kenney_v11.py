#!/usr/bin/env python3
"""Vendored CC0 Kenney assets, pinned to a specific upstream commit.

This script is run in CI only. End users never download third-party assets at
game startup. Binary glTF files and the provenance ledger are committed.
"""
import hashlib, json, struct, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

REV = "3ddcc695adbba9fb918cf31b7c139b3f95b76910"
REMOTE = "https://raw.githubusercontent.com/Hidencod/tge-assets/" + REV + "/"
ROOT = Path(__file__).resolve().parents[1]
GROUPS = {
 "furniture-kit": "kitchenbar kitchencoffeemachine kitchensink kitchenfridgesmall bookcaseopen plantsmall1 tableround chaircushion chair loungesofa rugrectangle pottedplant lamproundfloor computerkeyboard computerscreen kitchenfridgelarge kitchenmicrowave trashcan beddouble desk chairdesk laptop tablecoffee bookcaseopenlow plantsmall2 rugrounded lamproundtable bookcaseclosedwide".split(),
 "food-kit": "croissant cake donut cup-coffee soda-can soda-bottle sandwich bread burger carton-small".split(),
 "city-kit-suburban": "building-type-a building-type-g building-type-c building-type-l planter".split(),
 "city-kit-commercial": "building-k building-g".split(),
 "city-kit-roads": "light-square light-curved road-sign-object-stop dumpster".split(),
}

def fetch_model(item):
    pack, name = item
    source = "packs/%s/%s.glb" % (pack,name)
    target = ROOT / "art" / "third_party" / "kenney" / pack / (name + ".glb")
    target.parent.mkdir(parents=True, exist_ok=True)
    last_error = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(REMOTE + source,headers={"User-Agent":"LifeSim-CC0-Asset-Vendor/0.11"})
            with urllib.request.urlopen(req,timeout=45) as response:
                data=response.read()
            if len(data)<512 or data[:4]!=b"glTF" or struct.unpack_from("<I",data,4)[0]!=2 or struct.unpack_from("<I",data,8)[0]!=len(data):
                raise ValueError("invalid GLB: "+source)
            target.write_bytes(data)
            blob_sha=hashlib.sha1(b"blob "+str(len(data)).encode()+b"\\x00"+data).hexdigest()
            return {"file":str(target.relative_to(ROOT)).replace("\\","/"),"upstream_path":source,"source_git_blob_sha1":blob_sha,"sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data)}
        except (OSError,ValueError) as error:
            last_error=error
            time.sleep(1+attempt*2)
    raise RuntimeError("Could not fetch: %s: %s" % (source,last_error))

def main():
    tasks=[(p,n) for p,names in GROUPS.items() for n in names]
    with ThreadPoolExecutor(max_workers=7) as pool:
        manifest=[f.result() for f in as_completed([pool.submit(fetch_model,item) for item in tasks])]
    manifest.sort(key=lambda x:x["file"])
    result={"creator":"Kenney","license":"CC0-1.0",
      "distribution_repository":"https://github.com/Hidencod/tge-assets",
      "repository_commit":REV,"assets":manifest}
    dst=ROOT/"credits"/"KENNEY_ASSETS_V11.json"
    dst.parent.mkdir(parents=True,exist_ok=True)
    dst.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\\n",encoding="utf8")
    print("V11 VENDORED %d LICENSED GLB ASSETS (%d bytes)" % (len(manifest),sum(m["bytes"] for m in manifest)))

if __name__=="__main__":
    main()
