#!/usr/bin/env python3
"""
Isele — portable Voice 2.0 proxy.

The browser (Isele web app) can't call the local w-okada engine directly:
w-okada sends no CORS headers and listens only on localhost. This tiny server
sits in front of w-okada with permissive CORS and exposes the same /v2/*
endpoints the app expects, forwarding to w-okada on 127.0.0.1:18000.

Bandwidth trick (same as VNV Pro): the browser sends int16 mono @16k over the
tunnel; we upsample to float32 @48k for w-okada, then downsample its @48k output
back to int16 @16k — ~6x smaller payload, no quality loss (w-okada is 16k inside).

Only deps beyond the stdlib: numpy, soxr, requests. No torch — so this freezes
to a small, portable exe.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

import numpy as np
import soxr
import requests

WOKADA = "http://127.0.0.1:18000"   # local w-okada (Voice 2.0)
DEFAULT_PORT = 8765


def _cors(h):
    h.send_header("Access-Control-Allow-Origin", "*")
    h.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    h.send_header("Access-Control-Allow-Headers", "*")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass  # quiet

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        _cors(self)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _bytes(self, code, data):
        self.send_response(code)
        _cors(self)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if data:
            self.wfile.write(data)

    def do_OPTIONS(self):
        self.send_response(204)
        _cors(self)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/health":
            return self._json(200, {"ok": True})
        if path == "/v2/health":
            try:
                r = requests.get(f"{WOKADA}/api/hello", timeout=5)
                return self._json(200, {"ok": r.status_code == 200})
            except Exception as e:
                return self._json(503, {"ok": False, "error": str(e)})
        return self._json(404, {"error": "not found"})

    def do_POST(self):
        u = urlparse(self.path)
        path = u.path
        q = parse_qs(u.query)
        clen = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(clen) if clen else b""

        if path == "/v2/set_slot":
            slot = int(q.get("slot", [0])[0])
            try:
                cfg = requests.get(f"{WOKADA}/api/configuration-manager/configuration", timeout=10).json()
                cfg["current_slot_index"] = slot
                r = requests.put(f"{WOKADA}/api/configuration-manager/configuration", json=cfg, timeout=15)
                return self._json(200, {"ok": r.status_code == 200, "slot": slot})
            except Exception as e:
                return self._json(502, {"ok": False, "error": str(e)})

        if path == "/v2/set_pitch":
            slot = int(q.get("slot", [0])[0])
            pitch = int(q.get("pitch", [0])[0])
            try:
                s = requests.get(f"{WOKADA}/api/slot-manager/slots/{slot}", timeout=10).json()
                s["pitch_shift"] = pitch
                r = requests.put(f"{WOKADA}/api/slot-manager/slots/{slot}", json=s, timeout=15)
                return self._json(200, {"ok": r.status_code == 200, "slot": slot, "pitch": pitch})
            except Exception as e:
                return self._json(502, {"ok": False, "error": str(e)})

        if path == "/v2/convert":
            ts = q.get("ts", ["0"])[0]
            if not body:
                return self._bytes(200, b"")
            in16 = np.frombuffer(body, dtype="<i2").astype(np.float32) / 32768.0
            if len(in16) == 0:
                return self._bytes(200, b"")
            up = soxr.resample(in16, 16000, 48000).astype("<f4")
            try:
                files = {"waveform": ("chunk.bin", up.tobytes(), "application/octet-stream")}
                r = requests.post(f"{WOKADA}/api/voice-changer/convert_chunk",
                                  files=files, headers={"x-timestamp": str(ts)}, timeout=30)
            except Exception as e:
                return self._json(502, {"error": "w-okada unreachable", "detail": str(e)})
            if r.status_code != 200:
                return self._json(502, {"error": "convert failed", "detail": r.text[:200]})
            out48 = np.frombuffer(r.content, dtype="<f4")
            if len(out48) == 0:
                return self._bytes(200, b"")
            out16 = soxr.resample(out48, 48000, 16000)
            out16i = np.clip(out16 * 32768.0, -32768, 32767).astype("<i2")
            return self._bytes(200, out16i.tobytes())

        return self._json(404, {"error": "not found"})


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
    print(f"Isele proxy listening on 127.0.0.1:{port}  ->  w-okada {WOKADA}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
