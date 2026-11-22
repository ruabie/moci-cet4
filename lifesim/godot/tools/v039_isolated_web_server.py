#!/usr/bin/env python3
"""Local no-deployment Godot Web preview server with correct Web MIME/COOP/COEP.

Run from the extracted preview directory:
  python serve_preview.py
Then visit http://127.0.0.1:8765/?qa=1 in modern Chromium.
No network requests, analytics, cloud account or publishing. Stop with Ctrl-C.
"""
import argparse
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class LocalGodotHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm":"application/wasm",
        ".js":"text/javascript",
        ".pck":"application/octet-stream",
        ".html":"text/html; charset=utf-8",
        ".json":"application/json",
    }
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy","same-origin")
        self.send_header("Cross-Origin-Embedder-Policy","require-corp")
        self.send_header("Cross-Origin-Resource-Policy","same-origin")
        self.send_header("Cache-Control","no-store")
        super().end_headers()
    def log_message(self,fmt,*args):
        super().log_message(fmt,*args)

def main():
    cli=argparse.ArgumentParser()
    cli.add_argument("--port",type=int,default=8765)
    cli.add_argument("--host",default="127.0.0.1")
    args=cli.parse_args()
    here=Path(__file__).resolve().parent
    required=("index.html","index.js","index.wasm","index.pck")
    missing=[x for x in required if not (here/x).is_file()]
    if missing:
        raise SystemExit("Missing genuine Godot Web files: "+repr(missing))
    os.chdir(here)
    with ThreadingHTTPServer((args.host,args.port),LocalGodotHandler) as server:
        print(f"LifeSim V0.39 isolated HTML5 local preview: http://{args.host}:{args.port}/?qa=1",flush=True)
        print("No public hosting. Press Ctrl+C to stop.",flush=True)
        server.serve_forever()

if __name__=="__main__":
    main()
