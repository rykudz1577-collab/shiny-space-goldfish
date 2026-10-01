"""Preview server — chạy UI Antares trong TRÌNH DUYỆT không cần pywebview.

Dựng mock bridge (window.pywebview.api) + kênh đẩy event /events để xem toàn bộ
UIX (dashboard v2, sidebar, console, profiles, skins...) với dữ liệu mẫu.

Chạy:  python scripts/preview_server.py [port]     (mặc định 8765)
Mở:    http://localhost:8765
"""
from __future__ import annotations

import json
import math
import random
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "frontend"
EVENT_CLIENTS: list = []
EVENT_LOCK = threading.Lock()

# ------------------------------------------------------------------
# Dữ liệu mẫu
# ------------------------------------------------------------------

_INSTANCES = [
    {"id": "inst001", "name": "Survival 1.21", "loader": "fabric",
     "minecraftVersion": "1.21.8", "version": "1.21.8", "memory": {"maxMb": 4096}},
    {"id": "inst002", "name": "PvP Arena", "loader": "forge",
     "minecraftVersion": "1.20.1", "version": "1.20.1", "memory": {"maxMb": 6144}},
    {"id": "inst003", "name": "Create Megabase", "loader": "neoforge",
     "minecraftVersion": "1.21.1", "version": "1.21.1", "memory": {"maxMb": 8192}},
    {"id": "inst004", "name": "Skyblock Chill", "loader": "quilt",
     "minecraftVersion": "1.21.4", "version": "1.21.4", "memory": {"maxMb": 3072}},
    {"id": "inst005", "name": "Vanilla Pure", "loader": "vanilla",
     "minecraftVersion": "1.21.11", "version": "1.21.11", "memory": {"maxMb": 2048}},
]

_ACCOUNTS = [
    {"id": "acc-1", "displayName": "Steve_Miner", "type": "offline"},
    {"id": "acc-2", "displayName": "AlexBuilds", "type": "ely"},
    {"id": "acc-3", "displayName": "CreeperHunter", "type": "offline"},
]

_PROFILES = [
    {"id": "prof-1", "name": "PvP Setup", "active": True,
     "spec": {"account": {"id": "acc-1"}, "instance": {"id": "inst002"},
              "game": {"gamma": "1.0", "fov": "0.0", "guiScale": "3",
                       "renderDistance": "12", "maxFps": "260"},
              "launch": {"server": "mc.hypixel.net"}}},
    {"id": "prof-2", "name": "Low-end Survival", "active": False,
     "spec": {"instance": {"id": "inst001"},
              "game": {"renderDistance": "6", "particles": "0",
                       "simulationDistance": "5"}}},
    {"id": "prof-3", "name": "Screenshot Mode", "active": False,
     "spec": {"instance": {"id": "inst003"},
              "game": {"gamma": "1.0", "renderDistance": "32",
                       "simulationDistance": "12", "mipmapLevels": "4"}}},
]

_SKINS = [
    {"id": "sk1", "kind": "skin", "name": "steve_classic", "width": 64,
     "height": 64, "sha256": "aa11", "converted": False},
    {"id": "sk2", "kind": "skin", "name": "shadow_ninja", "width": 64,
     "height": 64, "sha256": "bb22", "converted": False},
    {"id": "sk3", "kind": "cape", "name": "hero_cape", "width": 92,
     "height": 64, "sha256": "cc33", "converted": False},
]

_LOG_LINES = [
    "2026-09-26 09:00:01 INFO antares.app Antares Launcher 3.0 ready",
    "2026-09-26 09:00:02 INFO antares.instances Loaded 5 instances",
    "2026-09-26 09:00:03 INFO antares.java Found Java 21 (runtime)",
    "2026-09-26 09:00:05 WARNING antares.optimization Heap 8GB exceeds safe 50% of 16GB",
    "2026-09-26 09:00:08 INFO antares.resources Built pack crosshair-v2.zip (12 assets)",
    "2026-09-26 09:00:11 ERROR antares.mods DuplicateModsFoundException: sodium vs optifine",
    "2026-09-26 09:00:12 INFO antares.minecraft Launching Survival 1.21 (fabric)",
    "2026-09-26 09:00:14 INFO antares.minecraft Game started pid=4821",
]


def _png_b64(width: int, height: int, rgb: tuple) -> str:
    """PNG 8-bit RGBA thật (dùng cùng encoder chuẩn của dự án)."""
    import struct
    import zlib

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    row = b"\x00" + bytes(rgb + (255,)) * width
    raw = row * height
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    import base64
    return "data:image/png;base64," + base64.b64encode(png).decode()


def _skins_with_preview() -> dict:
    out = {"skins": [], "capes": []}
    colors = {"sk1": (92, 148, 90), "sk2": (40, 44, 60), "sk3": (60, 84, 200)}
    for item in _SKINS:
        entry = dict(item)
        key = "skins" if item["kind"] == "skin" else "capes"
        out[key].append(entry)
        entry["preview"] = _png_b64(item["width"], item["height"], colors[item["id"]])
    return out


# ------------------------------------------------------------------
# Mock bridge API — cùng shape {ok, data/error} như AntaresApi
# ------------------------------------------------------------------

def _ok(data=None) -> dict:
    return {"ok": True, "data": data or {}}


def mock_api(command: str, *args) -> dict:
    if command == "app_get_state":
        return _ok({
            "app": {"name": "Antares Launcher", "version": "3.0-preview"},
            "selectedInstance": "inst001",
            "selectedAccount": "acc-1",
            "accountsSummary": _ACCOUNTS,
            "instancesSummary": _INSTANCES,
        })
    if command == "instances_list":
        return _ok({"instances": _INSTANCES})
    if command == "accounts_list":
        return _ok({"accounts": _ACCOUNTS})
    if command == "profiles_list":
        return _ok({"profiles": _PROFILES})
    if command == "skins_list":
        return _ok(_skins_with_preview())
    if command == "skins_preview":
        return _ok({"preview": _png_b64(64, 64, (92, 148, 90))})
    if command == "console_sources":
        return _ok({"sources": [
            {"id": "launcher", "available": True, "bytes": 0, "lines": 8},
            {"id": "minecraft", "available": True, "bytes": 1024 * 37, "lines": 0},
            {"id": "crash", "available": False, "bytes": 0, "count": 0},
        ]})
    if command == "logs_recent":
        return _ok({
            "lines": [
                {"text": l, "level": ("ERROR" if " ERROR " in l else
                                      "WARNING" if " WARNING " in l else "INFO"),
                 "logger": "antares", "ts": None}
                for l in _LOG_LINES
            ],
            "cursor": len(_LOG_LINES),
        })
    if command == "console_read":
        src = args[0] if args else "launcher"
        return _ok({"source": src, "instanceId": None, "truncated": False,
                    "lines": [{"n": i + 1, "text": l}
                              for i, l in enumerate(_LOG_LINES)]})
    if command == "console_analyze":
        return _ok({
            "insights": [
                {"id": "mod_conflict", "count": 1, "severity": "error",
                 "seed": "modConflict", "recommend": "nav.mods",
                 "action": {"kind": "route", "target": "mods"},
                 "firstSeen": None, "lastSeen": None, "sources": ["launcher"],
                 "lines": [{"source": "launcher", "line": 6,
                            "text": _LOG_LINES[5]}]},
                {"id": "heap_warning", "count": 1, "severity": "warning",
                 "seed": "oom", "recommend": "profiles.ramMax",
                 "action": {"kind": "route", "target": "gameOptimization"},
                 "firstSeen": None, "lastSeen": None, "sources": ["launcher"],
                 "lines": [{"source": "launcher", "line": 4,
                            "text": _LOG_LINES[3]}]},
            ],
            "errorCount": 1, "warnCount": 1,
        })
    if command == "system_overview":
        vm_used = 9.2 * 1024 * 1024 * 1024
        return _ok({
            "hardware": {
                "ramTotalMb": 16 * 1024, "cpuThreads": 12,
                "ramUsedMb": int(vm_used / (1024 * 1024)), "ramPercent": 57.4,
            },
            "power": {"plan": "balanced"},
            "cleanupPreview": {},
        })
    if command == "performance_snapshot":
        now = time.time()
        history = []
        for i in range(90):
            ts = now - (90 - i) * 2
            history.append({
                "ts": ts,
                "cpu": round(18 + 11 * math.sin(i / 7) + random.uniform(-3, 3), 1),
                "ram": {"percent": round(52 + 6 * math.sin(i / 11) + random.uniform(-1.5, 1.5), 1),
                        "used": 8.7 * 1024**3, "total": 16 * 1024**3},
                "launcher": {"cpu": round(random.uniform(0.2, 1.4), 1), "rss": 180 * 1024**2},
            })
        return _ok({"latest": history[-1], "history": history, "gameMode": False})
    if command == "events_stats":
        return _ok({"stats": {}, "pending": 0, "pushing": True})
    if command == "events_drain":
        return _ok({"events": [], "pushing": True})
    if command == "events_sync_log_cursor":
        return _ok({"synced": True})
    if command == "java_list":
        return _ok({"javas": [{"version": "21.0.4", "vendor": "Eclipse Temurin",
                               "path": "/usr/lib/jvm/temurin-21"}]})
    if command in ("versions_list", "optimization_scan", "resource_list",
                   "asset_list", "backups_list", "notifications_list",
                   "plugins_list", "runtime_sessions", "visual_presets",
                   "visual_totem_presets", "visual_hud_widgets", "visual_fx_defaults",
                   "plugins_registry", "servers_list", "tasks_list",
                   "notifications_unread_count"):
        return _ok({"items": [], "versions": [], "plugins": [], "snapshots": [],
                    "notifications": [], "servers": [], "tasks": [],
                    "unread": 0, "assets": [], "projects": [], "sessions": []})
    # Mặc định: ok rỗng để UI vào được tối đa các tab
    return _ok({})


# ------------------------------------------------------------------
# Event stream (SSE) — giả lập performance.telemetry + log.lines
# ------------------------------------------------------------------

def _event_pump() -> None:
    """Đẩy telemetry mỗi 2s + log mỗi 6s tới mọi client SSE."""
    i = 0
    while True:
        time.sleep(2)
        i += 1
        sample = {
            "event": "performance.telemetry",
            "payload": {
                "ts": time.time(),
                "cpu": round(22 + 12 * math.sin(i / 5) + random.uniform(-4, 4), 1),
                "ram": {"percent": round(55 + 5 * math.sin(i / 8), 1),
                        "used": 9 * 1024**3, "total": 16 * 1024**3},
                "launcher": {"cpu": round(random.uniform(0.2, 1.2), 1), "rss": 180 * 1024**2},
            },
        }
        batch = [sample]
        if i % 3 == 0:
            batch.append({
                "event": "log.lines",
                "payload": {"lines": [{
                    "text": f"2026-09-26 09:{(i // 3) % 60:02d}:{i % 60:02d} "
                            f"INFO antares.minecraft Tick {i * 20} — world running",
                    "level": "INFO", "logger": "antares.minecraft", "ts": None,
                }], "count": 1},
            })
        with EVENT_LOCK:
            for q in list(EVENT_CLIENTS):
                q.put(batch)


threading.Thread(target=_event_pump, daemon=True).start()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # im lặng
        pass

    def _serve_file(self, rel: str, ctype: str) -> None:
        path = (ROOT / rel).resolve()
        if not str(path).startswith(str(ROOT.resolve())) or not path.is_file():
            self.send_error(404)
            return
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._serve_index()
        elif path == "/events":
            self._serve_events()
        elif path.endswith(".css"):
            self._serve_file(path.lstrip("/"), "text/css; charset=utf-8")
        elif path.endswith(".js"):
            self._serve_file(path.lstrip("/"), "text/javascript; charset=utf-8")
        elif path.endswith(".json"):
            self._serve_file(path.lstrip("/"), "application/json; charset=utf-8")
        elif path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
        else:
            self.send_error(404)

    def _serve_index(self) -> None:
        """index.html + chèn shim TRƯỚC module script (mock bridge + SSE)."""
        path = ROOT / "index.html"
        if not path.is_file():
            self.send_error(404)
            return
        html = path.read_text(encoding="utf-8").replace(
            '<script type="module" src="app/bootstrap.js"></script>',
            '<script src="app/preview-shim.js"></script>\n'
            '  <script type="module" src="app/bootstrap.js"></script>')
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_events(self) -> None:
        """SSE: mỗi client 1 queue; pump thread đẩy batch vào queue."""
        import queue as _q
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        q: _q.Queue = _q.Queue()
        with EVENT_LOCK:
            EVENT_CLIENTS.append(q)
        try:
            while True:
                try:
                    batch = q.get(timeout=15)
                    data = json.dumps(batch).encode()
                    self.wfile.write(b"data: " + data + b"\n\n")
                except _q.Empty:
                    self.wfile.write(b": ping\n\n")
                self.wfile.flush()
        except Exception:
            pass
        finally:
            with EVENT_LOCK:
                if q in EVENT_CLIENTS:
                    EVENT_CLIENTS.remove(q)

    def do_POST(self) -> None:
        if self.path != "/bridge":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length") or 0)
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
            command = str(payload.get("command") or "")
            result = mock_api(command, *payload.get("args", []))
        except Exception as e:
            result = {"ok": False, "error": {"code": "MOCK_ERROR", "message": str(e)}}
        body = json.dumps(result).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Antares UIX preview: http://localhost:{port}  (Ctrl+C để dừng)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
