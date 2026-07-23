#!/usr/bin/python3

# Copyright Jody M Sankey 2026
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

"""Extracts sample real payloads for one or more NMEA 2000 PGNs from a Yacht Devices RAW
format recording, formatted ready to paste into test/state/parsing/parsing_2000_test.dart as
a _testHexMsg(...) argument.

Usage:
    # See what PGNs are present in a recording and how often, to find one worth sampling.
    scripts/extract_test_examples.py my_recording.raw

    # Print up to 5 real payloads seen for PGN 130310.
    scripts/extract_test_examples.py my_recording.raw --pgn 130310
"""

from argparse import ArgumentParser
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
import re
from typing import Dict, Iterator, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
PARSER_2000_DIR = REPO_ROOT / "lib/state/parsing/2000"

PGN_RE = re.compile(r"final\s+pgn\s*=\s*(\d+)")
FAST_FRAME_RE = re.compile(r"fastFrame\s*=>\s*true")


def fast_frame_pgns() -> set:
    """Returns the PGNs the app currently reassembles from multiple CAN frames, found by
    scanning the per-message parser files for a `fastFrame => true` override."""
    pgns = set()
    for path in PARSER_2000_DIR.glob("*.dart"):
        text = path.read_text()
        pgn_match = PGN_RE.search(text)
        if pgn_match and FAST_FRAME_RE.search(text):
            pgns.add(int(pgn_match.group(1)))
    return pgns


def header_to_pgn_source(header: str) -> Tuple[int, int]:
    """Decodes an 8 character hex 29-bit CAN header into (pgn, source), mirroring
    _hexHeaderToPgnSource in raw.dart."""
    can_id = int(header, 16)
    data_page = (can_id >> 24) & 0x1
    pdu_format = (can_id >> 16) & 0xFF
    pdu_specific = (can_id >> 8) & 0xFF
    source = can_id & 0xFF
    if pdu_format < 240:
        pgn = (data_page << 16) | (pdu_format << 8)
    else:
        pgn = (data_page << 16) | (pdu_format << 8) | pdu_specific
    return pgn, source


@dataclass
class _Frame:
    """A single decoded line of RAW data."""

    pgn: int
    source: int
    data: List[int]


def read_frames(lines: Iterator[str]) -> Iterator[_Frame]:
    """Parses received (not transmitted) CAN frames out of raw RAW-format lines, skipping
    anything malformed, mirroring the line filtering in YdRawMessageSplitter.read."""
    for line in lines:
        parts = line.split()
        if len(parts) < 4 or len(parts) > 11 or parts[1] != "R":
            continue
        try:
            pgn, source = header_to_pgn_source(parts[2])
            data = [int(b, 16) for b in parts[3:]]
        except ValueError:
            continue
        yield _Frame(pgn, source, data)


class _FastFrameAssembler:
    """Reassembles a single in-progress fast frame message, mirroring _FastFrameMessage."""

    def __init__(self, first_frame: List[int]):
        self.last_counter = first_frame[0]
        if self.last_counter & 0x1F != 0:
            raise ValueError("First frame counter not 0")
        total_length = first_frame[1]
        if total_length == 0:
            raise ValueError("Payload is empty")
        self.payload = bytearray(total_length)
        chunk = first_frame[2:]
        take = min(6, total_length)
        self.payload[0:take] = chunk[:take]
        self.remaining = total_length - take

    def add_frame(self, frame: List[int]) -> None:
        counter = frame[0]
        if counter >> 5 != self.last_counter >> 5:
            raise ValueError("Change in sequence")
        if counter & 0x1F != (self.last_counter & 0x1F) + 1:
            raise ValueError("Out of order counter")
        take = min(7, self.remaining)
        chunk = frame[1:]
        if len(chunk) < take:
            raise ValueError("Frame too short")
        start = len(self.payload) - self.remaining
        self.payload[start : start + take] = chunk[:take]
        self.last_counter = counter
        self.remaining -= take

    def complete(self) -> Optional[bytes]:
        return bytes(self.payload) if self.remaining == 0 else None


def assemble_messages(
    frames: Iterator[_Frame], needs_fast_frame: set
) -> Iterator[Tuple[int, int, bytes]]:
    """Yields (pgn, source, payload) for every complete message, reassembling fast frame
    sequences and silently dropping ones that fail to reassemble, mirroring
    YdRawMessageSplitter._handleFastFrame."""
    partial: Dict[Tuple[int, int], _FastFrameAssembler] = {}

    for frame in frames:
        if frame.pgn not in needs_fast_frame:
            if frame.data:
                yield frame.pgn, frame.source, bytes(frame.data)
            continue

        key = (frame.pgn, frame.source)
        assembler = partial.get(key)
        if assembler is None:
            try:
                assembler = _FastFrameAssembler(frame.data)
            except ValueError:
                continue
            completed = assembler.complete()
            if completed is not None:
                yield frame.pgn, frame.source, completed
            else:
                partial[key] = assembler
            continue

        try:
            assembler.add_frame(frame.data)
        except ValueError:
            del partial[key]
            # The failure may be because this frame should start a new sequence; retry it now
            # that the abandoned one has been removed.
            try:
                assembler = _FastFrameAssembler(frame.data)
            except ValueError:
                continue
            completed = assembler.complete()
            if completed is not None:
                yield frame.pgn, frame.source, completed
            else:
                partial[key] = assembler
            continue

        completed = assembler.complete()
        if completed is not None:
            del partial[key]
            yield frame.pgn, frame.source, completed


def create_parser() -> ArgumentParser:
    parser = ArgumentParser(
        description=(
            "Extracts sample real NMEA 2000 payloads from a Yacht Devices RAW recording, "
            "ready to paste into a _testHexMsg(...) call in parsing_2000_test.dart."
        ),
        epilog="Copyright Jody Sankey 2026",
    )
    parser.add_argument(
        "raw_file", type=Path, help="Path to a Yacht Devices RAW format recording."
    )
    parser.add_argument(
        "--pgn",
        type=int,
        nargs="+",
        help="One or more PGNs to print sample payloads for. If omitted, prints a count of "
        "every PGN seen instead.",
    )
    parser.add_argument(
        "--max-per-pgn",
        type=int,
        default=5,
        help="Maximum number of sample payloads to print per requested PGN (default 5).",
    )
    parser.add_argument(
        "--source",
        type=int,
        help="Only consider messages from this NMEA 2000 source address.",
    )
    return parser


def main() -> None:
    args = create_parser().parse_args()
    needs_fast_frame = fast_frame_pgns()

    with args.raw_file.open(encoding="ascii", errors="ignore") as f:
        messages = assemble_messages(read_frames(f), needs_fast_frame)
        if args.source is not None:
            messages = (m for m in messages if m[1] == args.source)

        if not args.pgn:
            counts = Counter(pgn for pgn, _source, _payload in messages)
            for pgn, count in sorted(counts.items()):
                flag = " (fast frame)" if pgn in needs_fast_frame else ""
                print(f"{pgn:>6}: {count:>6} messages{flag}")
            return

        targets = set(args.pgn)
        printed = Counter()
        for pgn, source, payload in messages:
            if pgn not in targets or printed[pgn] >= args.max_per_pgn:
                continue
            hex_payload = "_".join(f"{b:02x}" for b in payload)
            print(f"{pgn} src={source} len={len(payload)}: {hex_payload}")
            printed[pgn] += 1

        for pgn in sorted(targets - set(printed)):
            print(f"{pgn}: no messages found")


if __name__ == "__main__":
    main()
