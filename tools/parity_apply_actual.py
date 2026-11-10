#!/usr/bin/env python3
"""Apply PARITY_ACTUAL lines from a parity job log to the baseline JSON files.

Reads lines of the form:

    PARITY_ACTUAL e0 L7 {...}
    PARITY_ACTUAL e05 L24 {...}

from raw `tools/parity.sh check` stdout, or from a `gh run view --log` file
(GitHub prefixes are stripped). Writes each entry into the matching file
(tools/baseline_1_40.json or tools/baseline_1_40_e05.json), touching only
those level objects. Other entries stay byte-identical.

    python3 tools/parity_apply_actual.py JOBLOG
    python3 tools/parity_apply_actual.py JOBLOG --dir /tmp/baseline-copy
    python3 tools/parity_apply_actual.py JOBLOG --dry-run
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MODE_FILES = {
    "e0": "baseline_1_40.json",
    "e05": "baseline_1_40_e05.json",
}

ACTUAL_RE = re.compile(r"PARITY_ACTUAL\s+(e0|e05)\s+L(\d+)\s+(\{.*\})\s*$")


def format_entry(obj: dict) -> str:
    """Pretty-print one level object in the Godot baseline style.

    The opening '{' is unindented (the file already has four spaces before it);
    every subsequent line is indented by four more spaces than json.dumps.
    """
    body = json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False)
    lines = body.splitlines()
    if not lines:
        return body
    return "\n".join([lines[0]] + ["    " + line for line in lines[1:]])


def iter_level_spans(text: str):
    """Yield (start, end, chunk) for each object in the top-level 'levels' array."""
    key_at = text.find('"levels"')
    if key_at < 0:
        raise ValueError("no \"levels\" array in baseline JSON")
    i = text.find("[", key_at)
    if i < 0:
        raise ValueError("no \"levels\" array in baseline JSON")
    n = len(text)
    j = i + 1
    while j < n:
        while j < n and text[j] in " \t\r\n":
            j += 1
        if j < n and text[j] == "]":
            return
        if j >= n or text[j] != "{":
            raise ValueError("expected a level object in the levels array")
        start = j
        depth = 0
        in_str = False
        esc = False
        while j < n:
            c = text[j]
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
            else:
                if c == '"':
                    in_str = True
                elif c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        j += 1
                        yield start, j, text[start:j]
                        while j < n and text[j] in " \t\r\n":
                            j += 1
                        if j < n and text[j] == ",":
                            j += 1
                        break
            j += 1
        else:
            raise ValueError("unterminated level object in the levels array")


def replace_level(text: str, level: int, entry: dict) -> tuple[str, bool]:
    """Replace the object for `level` in a baseline file. Returns (new_text, found)."""
    for start, end, _chunk in iter_level_spans(text):
        obj = json.loads(_chunk)
        if int(obj["level"]) == int(level):
            formatted = format_entry(entry)
            return text[:start] + formatted + text[end:], True
    return text, False


def strip_log_line(raw: str) -> str:
    """Drop GitHub Actions / ANSI prefixes so PARITY_ACTUAL is at a known place."""
    line = raw.rstrip("\n")
    if "\x1b[" in line:
        line = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line)
    # gh run view --log: "job\\tstep\\tTIMESTAMPZ message"
    if "\t" in line:
        parts = line.split("\t")
        last = parts[-1]
        # "2026-11-10T15:36:50.8833978Z message"
        last = re.sub(
            r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\s+",
            "",
            last,
        )
        line = last
    # notice lines may join records with pipes; search later anyway
    return line


def parse_actuals(text: str) -> dict[tuple[str, int], dict]:
    """Map (mode, level) to the last parsed actual entry in the log."""
    found: dict[tuple[str, int], dict] = {}
    for raw in text.splitlines():
        line = strip_log_line(raw)
        m = ACTUAL_RE.search(line)
        if not m:
            # ##[notice] may squash several records onto one line with |
            if "PARITY_ACTUAL" not in line:
                continue
            for piece in line.split("|"):
                m2 = ACTUAL_RE.search(strip_log_line(piece))
                if m2:
                    mode, level, payload = m2.group(1), int(m2.group(2)), m2.group(3)
                    found[(mode, level)] = json.loads(payload)
            continue
        mode, level, payload = m.group(1), int(m.group(2)), m.group(3)
        found[(mode, level)] = json.loads(payload)
    return found


def apply_actuals(
    actuals: dict[tuple[str, int], dict],
    baseline_dir: Path,
    dry_run: bool = False,
) -> list[str]:
    """Write actuals into the baseline files under baseline_dir. Returns change notes."""
    notes: list[str] = []
    by_mode: dict[str, dict[int, dict]] = {}
    for (mode, level), entry in actuals.items():
        by_mode.setdefault(mode, {})[level] = entry

    for mode, filename in MODE_FILES.items():
        path = baseline_dir / filename
        if mode not in by_mode:
            continue
        if not path.is_file():
            raise FileNotFoundError(f"baseline not found: {path}")
        original = path.read_text(encoding="utf-8")
        text = original
        missing: list[int] = []
        changed: list[int] = []
        identical: list[int] = []
        for level in sorted(by_mode[mode]):
            entry = by_mode[mode][level]
            if "level" in entry and int(entry["level"]) != int(level):
                raise ValueError(
                    f"{mode} L{level} entry has level={entry['level']}"
                )
            new_text, found = replace_level(text, level, entry)
            if not found:
                missing.append(level)
                continue
            if new_text == text:
                identical.append(level)
            else:
                changed.append(level)
            text = new_text
        if missing:
            raise ValueError(
                f"{filename} has no existing entry for levels {missing}; "
                "refusing to insert new levels"
            )
        if not dry_run and text != original:
            path.write_text(text, encoding="utf-8")
        notes.append(
            f"{filename}: changed {changed or 'none'}, "
            f"already-identical {identical or 'none'}"
        )
        # verify only listed entries moved
        if text != original:
            _assert_only_listed_changed(original, text, set(by_mode[mode]))
    return notes


def _assert_only_listed_changed(before: str, after: str, levels: set[int]) -> None:
    before_map = {int(e["level"]): json.dumps(e, sort_keys=True) for e in
                  json.loads(before)["levels"]}
    after_objs = list(iter_level_spans(after))
    after_map = {}
    for start, end, chunk in after_objs:
        obj = json.loads(chunk)
        after_map[int(obj["level"])] = json.dumps(obj, sort_keys=True)
    if set(before_map) != set(after_map):
        raise RuntimeError("level set changed while applying PARITY_ACTUAL entries")
    unexpected = []
    for lv, raw in before_map.items():
        if lv in levels:
            continue
        if after_map[lv] != raw:
            unexpected.append(lv)
        # also byte-check the object span against a re-format of the old object
    # byte-identical check for unlisted spans
    for (s1, e1, c1), (s2, e2, c2) in zip(iter_level_spans(before), after_objs):
        lv = int(json.loads(c1)["level"])
        if lv in levels:
            continue
        if c1 != c2:
            unexpected.append(lv)
    if unexpected:
        raise RuntimeError(f"unlisted entries changed: {sorted(set(unexpected))}")

    # the text outside replaced objects must be identical, so if we stitch
    # the new entries into the old text it should equal `after`.
    rebuilt = before
    # replace from the end so offsets stay valid
    spans = list(iter_level_spans(before))
    for start, end, chunk in reversed(spans):
        lv = int(json.loads(chunk)["level"])
        if lv not in levels:
            continue
        # find the matching new span by level in `after` — already written
        pass
    # leftover character check: drop listed objects from both and compare
    def drop_listed(text: str) -> str:
        pieces = []
        last = 0
        for start, end, chunk in iter_level_spans(text):
            lv = int(json.loads(chunk)["level"])
            if lv in levels:
                pieces.append(text[last:start])
                pieces.append("__ENTRY__")
                last = end
        pieces.append(text[last:])
        return "".join(pieces)

    if drop_listed(before) != drop_listed(after):
        raise RuntimeError("baseline text outside the listed entries changed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="parity.sh stdout or a gh run log")
    parser.add_argument(
        "--dir",
        type=Path,
        default=None,
        help="directory with baseline_1_40.json and baseline_1_40_e05.json "
        "(default: the tools/ directory next to this script)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="parse and report, but do not write files",
    )
    args = parser.parse_args(argv)
    baseline_dir = args.dir if args.dir is not None else Path(__file__).resolve().parent
    log_text = args.log.read_text(encoding="utf-8", errors="replace")
    actuals = parse_actuals(log_text)
    if not actuals:
        print("no PARITY_ACTUAL lines found", file=sys.stderr)
        return 1
    listing = ", ".join(f"{mode} L{lv}" for mode, lv in sorted(actuals, key=lambda t: (t[0], t[1])))
    print(f"found {len(actuals)} actual entr{'y' if len(actuals)==1 else 'ies'}: {listing}")
    notes = apply_actuals(actuals, baseline_dir, dry_run=args.dry_run)
    for line in notes:
        print(("dry-run: " if args.dry_run else "") + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
