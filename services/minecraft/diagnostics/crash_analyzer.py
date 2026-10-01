"""Crash analyzer — phân tích crash log (mục 290-292).

Port logic từ Spark: regex classification + mod extraction, trả structured result.
"""
from __future__ import annotations

import re
from pathlib import Path

MOD_PATTERNS = [
    re.compile(r"(?im)Mod File:\s*(\S+)"),
    re.compile(r"(?im)Missing Mods?:\s*(.+)$"),
    re.compile(r"(?im)\bmod\s+'([^']+)'"),
]

KNOWN_CAUSES = [
    (("incompatible mods found", "incompatible mod set", "modresolutionexception"),
     "MOD_CONFLICT", "Mod incompatibility or missing dependency.",
     "Remove or update the mods listed."),
    (("unsupportedclassversionerror", "has been compiled by a more recent version"),
     "JAVA_VERSION_TOO_OLD", "Wrong Java version.",
     "Install the required Java version."),
    (("outofmemoryerror", "could not reserve enough space for object heap"),
     "OUT_OF_MEMORY", "The JVM ran out of memory.",
     "Increase RAM allocation in instance settings."),
    (("opengl",),
     "GRAPHICS_ERROR", "Graphics / OpenGL problem.",
     "Update graphics drivers; disable shaders."),
    (("failed to download", "checksum", "invalid sha1"),
     "CORRUPTED_DOWNLOAD", "Corrupted download.",
     "Repair the instance to redownload broken files."),
    (("could not find or load main class",),
     "CORRUPTED_INSTALL", "Corrupted installation.",
     "Reinstall this version."),
]


def find_crash_report(game_dir: Path, *, after_ts: float = 0.0) -> Path | None:
    """Tìm crash report mới nhất sau thời điểm launch."""
    cr_dir = game_dir / "crash-reports"
    best = None
    best_mtime = after_ts
    for f in cr_dir.glob("*.txt") if cr_dir.exists() else ():
        m = f.stat().st_mtime
        if m >= best_mtime and (best is None or m > best.stat().st_mtime):
            best, best_mtime = f, m
    if best:
        return best
    latest = game_dir / "logs" / "latest.log"
    return latest if latest.exists() else None


def analyze(text: str) -> dict:
    """Trả {code, cause, advice, mods, key_lines} — structured (mục 291)."""
    lower = (text or "").lower()

    mods: list[str] = []
    for pat in MOD_PATTERNS:
        for m in pat.finditer(text or ""):
            name = m.group(1).strip().strip("'\"")
            if len(name) >= 2 and name.lower() not in [x.lower() for x in mods]:
                mods.append(name)

    code = "UNKNOWN"
    cause = "Unknown crash"
    advice = "Check the key error lines below."
    for needles, c, cs, adv in KNOWN_CAUSES:
        if any(n in lower for n in needles):
            code, cause, advice = c, cs, adv
            break

    key_lines: list[str] = []
    for line in (text or "").splitlines():
        if re.search(r"(?i)(exception|caused by|error)", line):
            clean = line.strip()[:220]
            if clean and clean not in key_lines:
                key_lines.append(clean)
            if len(key_lines) >= 12:
                break

    return {"code": code, "cause": cause, "advice": advice,
            "mods": mods[:12], "key_lines": key_lines}


def classify_exit(code: int) -> str:
    """Exit classification (mục 289)."""
    if code == 0:
        return "NORMAL"
    if code in (1,):
        return "GAME_CRASH"
    return "UNKNOWN"
