#!/usr/bin/env python3
"""Report which NMEA 0183 and NMEA 2000 message parsers can supply each Property enum value.

Reads the per-message parser files in lib/state/parsing/0183 and lib/state/parsing/2000,
finds every reference to a Property enum value, and determines the tier at which it is
supplied (the optional `tier:` argument of the bound value functions, defaulting to 1).
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PARSER_DIRS = [
    REPO_ROOT / "lib/state/parsing/0183",
    REPO_ROOT / "lib/state/parsing/2000",
]
COMMON_DART = REPO_ROOT / "lib/state/common.dart"

PROPERTY_RE = re.compile(r"Property\.(\w+)")
BOUND_CALL_RE = re.compile(
    r"\b(?:boundSingleValue|boundDoubleValue|_parseSingleValue|optionalBoundSingleValue)\s*\("
)
TIER_RE = re.compile(r"\btier:\s*(\d+)")
TYPE_RE = re.compile(r"final\s+type\s*=\s*'(\w+)'")
PGN_RE = re.compile(r"final\s+pgn\s*=\s*(\d+)")

TIER_COLORS = {1: "\033[32m", 2: "\033[93m", 3: "\033[38;5;208m"}
RESET = "\033[0m"


def strip_comments(text):
    return re.sub(r"//[^\n]*", "", text)


def matching_paren(text, open_index):
    """Return the index of the ')' matching the '(' at open_index, or len(text)."""
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return len(text)


def bound_call_spans(text):
    """Return (start, end) spans of the argument lists of bound value calls."""
    spans = []
    for match in BOUND_CALL_RE.finditer(text):
        open_index = text.index("(", match.start())
        spans.append((open_index, matching_paren(text, open_index)))
    return spans


def tier_for_span(text, span):
    match = TIER_RE.search(text, span[0], span[1])
    return int(match.group(1)) if match else 1


def parser_name(text, path):
    match = TYPE_RE.search(text) or PGN_RE.search(text)
    return match.group(1) if match else path.stem


def scan_parser(text):
    """Return {property_name: set of tiers} for one parser file."""
    spans = bound_call_spans(text)
    tiers = defaultdict(set)
    for match in PROPERTY_RE.finditer(text):
        enclosing = [s for s in spans if s[0] < match.start() < s[1]]
        if enclosing:
            span = min(enclosing, key=lambda s: s[1] - s[0])
        else:
            # Property was stored in a variable; use the next bound call, which
            # is where the variable gets passed with its tier.
            following = [s for s in spans if s[0] > match.end()]
            span = min(following, default=None)
        tiers[match.group(1)].add(tier_for_span(text, span) if span else 1)
    return tiers


def read_property_enum():
    text = COMMON_DART.read_text()
    match = re.search(r"enum Property \{(.*?)\n\}", text, re.DOTALL)
    if not match:
        sys.exit(f"Could not find Property enum in {COMMON_DART}")
    return re.findall(r"^  (\w+)\(", strip_comments(match.group(1)), re.MULTILINE)


def main():
    properties = read_property_enum()
    support = defaultdict(list)
    for dir_index, directory in enumerate(PARSER_DIRS):
        for path in sorted(directory.glob("*.dart")):
            if path.name == "common.dart":
                continue
            text = strip_comments(path.read_text())
            name = parser_name(text, path)
            for prop, tiers in scan_parser(text).items():
                for tier in tiers:
                    support[prop].append((dir_index, name, tier))

    for prop in properties:
        directories = {entry[0] for entry in support[prop]}
        if not directories:
            note = ' (no network input)'
        elif directories == {0}:
            note = ' (NMEA0183 only)'
        elif directories == {1}:
            note = ' (NMEA2000 only)'
        else:
            note = ''
        print(f'{prop}{note}')
        for _, name, tier in sorted(support[prop], key=lambda e: (e[0], e[2])):
            color = TIER_COLORS.get(tier, "")
            print(f'    {color}{name} (tier {tier}){RESET if color else ""}')

    unknown = set(support) - set(properties)
    if unknown:
        print(
            f'\nWARNING: parsers referenced unknown properties: {", ".join(sorted(unknown))}'
        )


if __name__ == "__main__":
    main()
