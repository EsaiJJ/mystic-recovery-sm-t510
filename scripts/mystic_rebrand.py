#!/usr/bin/env python3
"""
Mystic Recovery rebranding worker.

Safe mode only edits user-facing strings, XML text nodes, theme colours and
the PBRP tool payload paths. Build identifiers (PB_* make variables,
pbrp_* targets, C++ symbols and resource filenames) are deliberately left
alone so the PBRP engine keeps working.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

TEXT_SUFFIXES = {
    ".awk",
    ".bp",
    ".c",
    ".cc",
    ".conf",
    ".cpp",
    ".fc",
    ".fstab",
    ".h",
    ".hpp",
    ".java",
    ".json",
    ".md",
    ".mk",
    ".prop",
    ".py",
    ".rc",
    ".sh",
    ".te",
    ".txt",
    ".xml",
    ".yml",
    ".yaml",
}

TEXT_NAMES = {"update-binary", "updater-script", "recovery.fstab", "twrp.fstab"}

SKIP_DIRS = {".git", ".repo", "out", "out2", "prebuilts", "prebuilt", "images"}

# Order matters: longest / most specific first.
DISPLAY_MAP = [
    ("PitchBlack Recovery ProjectP", "Mystic Recovery"),
    ("PitchBlack Recovery Project", "Mystic Recovery"),
    ("PitchBlack Recovery Profeject", "Mystic Recovery"),
    ("PitchBlack Recovery", "Mystic Recovery"),
    ("PitchBlack", "Mystic"),
]

# /sdcard/PBRP must be replaced before the shorter /sdcard/PB prefix.
PATH_MAP = [
    ("/sdcard/PBRP", "/sdcard/Mystic"),
    ("/sdcard/PB", "/sdcard/Mystic"),
    ("$tmp/PBRP", "$tmp/Mystic"),
    ("PBRP/tools", "Mystic/tools"),
    ("PBRP/theme", "Mystic/theme"),
    ("PBRP/fonts", "Mystic/fonts"),
    ("PBRP-", "Mystic-"),
    ("PB-", "Mystic-"),
    ("PB/", "Mystic/"),
    ("pbrp.info", "mystic.info"),
    ("pbrp-install", "mystic-install"),
]

LICENSE_MARKERS = (
    "copyright",
    "spdx-license",
    "licensed under",
    "license",
    "apache",
    "gnu general public",
    "this file is part of",
)


def is_text_file(path: Path) -> bool:
    if path.name in TEXT_NAMES:
        return True
    if path.suffix.lower() in TEXT_SUFFIXES:
        return True
    return False


def iter_text_files(root: Path):
    if not root.exists():
        return
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            p = Path(dirpath) / name
            if is_text_file(p):
                try:
                    if p.stat().st_size <= 4 * 1024 * 1024:
                        yield p
                except OSError:
                    continue


def is_license_line(line: str) -> bool:
    low = line.lower()
    return any(marker in low for marker in LICENSE_MARKERS)


def replace_paths(text: str) -> str:
    for src, dst in PATH_MAP:
        text = text.replace(src, dst)
    return text


URL_RE = re.compile(r'https?://[^\s"\'<>]+')


def protect_upstream(text: str) -> tuple[str, list[str]]:
    preserved: list[str] = []

    def hold(value: str) -> str:
        preserved.append(value)
        return f"\x00MYSTIC_KEEP_{len(preserved) - 1}\x00"

    text = URL_RE.sub(lambda m: hold(m.group(0)), text)
    text = text.replace("PitchBlackRecoveryProject", hold("PitchBlackRecoveryProject"))
    return text, preserved


def restore_upstream(text: str, preserved: list[str]) -> str:
    for i, value in enumerate(preserved):
        text = text.replace(f"\x00MYSTIC_KEEP_{i}\x00", value)
    return text


def replace_display(text: str) -> str:
    text, preserved = protect_upstream(text)
    for src, dst in DISPLAY_MAP:
        text = text.replace(src, dst)
    text = text.replace("PBRP", "Mystic")
    return restore_upstream(text, preserved)


def replace_colors(text: str, accent: str) -> str:
    accent = accent.lstrip("#")
    return re.sub(
        r"#0090CA([0-9a-fA-F]{2})?",
        lambda m: "#" + accent + (m.group(1) or ""),
        text,
        flags=re.IGNORECASE,
    )


def replace_xml_line(line: str, accent: str) -> str:
    line = replace_paths(line)
    line = replace_colors(line, accent)
    if is_license_line(line):
        return line

    # Localised XML display strings look like {@string_key=Visible text}.
    # Rewrite only the visible part after '='; never the key.
    line = re.sub(
        r"(\{@[^=}\s]+\s*=\s*)([^}]*)(\})",
        lambda m: m.group(1) + replace_display(m.group(2)) + m.group(3),
        line,
    )

    # Text nodes: >display text<
    line = re.sub(
        r"(?<=>)([^<>]+)(?=<)",
        lambda m: replace_display(m.group(1)),
        line,
    )

    # Display-bearing attributes only. Never rename name=/id=/filename=.
    line = re.sub(
        r'(\b(?:value|title|text|description|author)\s*=\s*")([^"]*)(")',
        lambda m: m.group(1) + replace_display(m.group(2)) + m.group(3),
        line,
    )
    return line


def replace_code_strings(text: str) -> str:
    # Only rewrite double-quoted C/C++ string literals, never identifiers.
    pattern = re.compile(r'"(?:[^"\\]|\\.)*"')

    def repl(match: re.Match[str]) -> str:
        return replace_display(match.group(0))

    return pattern.sub(repl, text)


def replace_plain(text: str, path: Path) -> str:
    text, preserved = protect_upstream(text)
    text = replace_paths(text)
    out_lines = []
    targeted = path.name in ("update-binary", "pbrp.mk", "updater-script")
    for line in text.splitlines(keepends=True):
        if is_license_line(line):
            out_lines.append(line)
            continue
        line = line.replace("PitchBlack Recovery ProjectP", "Mystic Recovery")
        line = line.replace("PitchBlack Recovery Project", "Mystic Recovery")
        line = line.replace("PitchBlack Recovery", "Mystic Recovery")
        line = line.replace("PitchBlack", "Mystic")
        if targeted:
            line = line.replace("PBRP", "Mystic")
        out_lines.append(line)
    return restore_upstream("".join(out_lines), preserved)


def rebrand_file(path: Path, accent: str, dry_run: bool) -> bool:
    try:
        # newline="" preserves the file's existing CRLF/LF convention.
        with open(path, "r", encoding="utf-8", newline="") as fh:
            original = fh.read()
    except (UnicodeDecodeError, OSError):
        return False

    suffix = path.suffix.lower()
    if suffix == ".xml":
        updated = "".join(replace_xml_line(line, accent) for line in original.splitlines(keepends=True))
    elif suffix in (".c", ".cc", ".cpp", ".h", ".hpp", ".java"):
        updated = replace_paths(original)
        updated = replace_code_strings(updated)
        updated = replace_colors(updated, accent)
    else:
        updated = replace_plain(original, path)

    if updated == original:
        return False
    if dry_run:
        print(f"[dry-run] would edit {path}")
    else:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(updated)
        print(f"[edit] {path}")
    return True


def rename_payload(root: Path, dry_run: bool) -> bool:
    old = root / "vendor" / "utils" / "PBRP"
    new = root / "vendor" / "utils" / "Mystic"
    if not old.is_dir() or new.exists():
        return False
    if dry_run:
        print(f"[dry-run] would rename {old} -> {new}")
    else:
        old.rename(new)
        print(f"[rename] {old} -> {new}")
    return True


def is_non_display_line(line: str, suffix: str) -> bool:
    s = line.lstrip()
    if suffix in (".c", ".cc", ".cpp", ".h", ".hpp", ".java"):
        return s.startswith(("//", "/*", "*"))
    if suffix in (".mk", ".sh", ".py", ".conf", ".prop", ".rc", ".bp", ".te", ".fc", ".fstab"):
        return s.startswith("#")
    if suffix == ".xml":
        return s.startswith("<!--") or s.startswith("-->")
    if suffix in (".json", ".md", ".txt", ".py", ".yml", ".yaml"):
        return True
    return False


def verify(root: Path) -> int:
    suspects = []
    targets = [
        root / "bootable" / "recovery",
        root / "vendor" / "utils" / "updater",
        root / "vendor" / "utils" / "build" / "tasks",
        root / "vendor" / "pb" / "config",
        root / "device" / "samsung" / "gta3xlwifi",
    ]
    for rel in ("vendor/utils/PBRP", "vendor/utils/Mystic"):
        target = root / rel
        if target.is_dir():
            targets.append(target)
    for target in targets:
        for p in iter_text_files(target):
            try:
                text = p.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for i, line in enumerate(text.splitlines(), 1):
                if is_license_line(line) or is_non_display_line(line, p.suffix.lower()):
                    continue
                if "PitchBlack" in line or "PBRP" in line:
                    suspects.append(f"{p}:{i}: {line.strip()[:160]}")
    if suspects:
        print("\nRemaining user-facing brand references (review manually):")
        for entry in suspects[:200]:
            print(entry)
        print(f"\nTotal: {len(suspects)}")
        return 1
    print("No remaining user-facing PitchBlack/PBRP references found.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Rebrand a PBRP source tree as Mystic Recovery")
    ap.add_argument("--root", default=".", help="Android source root")
    ap.add_argument("--accent", default="7C4DFF", help="accent colour hex without #")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--check", action="store_true", help="only scan for leftovers")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not (root / "bootable" / "recovery").is_dir():
        print(f"error: {root} does not look like an Android/PBRP source tree", file=sys.stderr)
        return 2

    if args.check:
        return verify(root)

    changed = 0
    for rel in ("bootable/recovery", "vendor/pb", "vendor/utils", "device/samsung/gta3xlwifi"):
        for p in iter_text_files(root / rel):
            if rebrand_file(p, args.accent, args.dry_run):
                changed += 1

    if rename_payload(root, args.dry_run):
        changed += 1

    print(f"\n{'Would change' if args.dry_run else 'Changed'} {changed} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
