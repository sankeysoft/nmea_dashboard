#!/usr/bin/python3

# Copyright Jody M Sankey 2022-2026
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

"""This is a simple python script I use to playback recorded NMEA network on a local network
during development, optionally with fragmentation, trunctation and corruption."""

from abc import ABC, abstractmethod
from argparse import ArgumentParser, Namespace
from datetime import date, datetime, time, timedelta
import re
import socket
import os
from random import randrange
import time as time_module
import typing

DEFAULT_INTERVAL = timedelta(milliseconds=50)
EWMA_ALPHA = 0.2
ONE_MS = timedelta(milliseconds=1)

# Arbitrary anchor date used to turn RAW format's time-of-day timestamps into full datetimes.
# Only deltas and ordering between timestamps are ever used, never the calendar date itself.
_RAW_EPOCH_DATE = date(2000, 1, 1)

_RAW_LINE_RE = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\.(\d{3}) ([RT]) ([0-9A-Fa-f]{8}) ")


class MessageFormat(ABC):
    """Interface for a recorded file format that can be played back by this script."""

    name: str

    # Whether every line carries its own timestamp, so playback can simply sleep for the
    # recorded delta between consecutive lines. False means timestamps are sparse (e.g. only
    # on occasional sentences), so playback instead has to estimate a fixed rate using an EWMA
    # over data-to-real time ratio.
    per_line_timing: bool

    @staticmethod
    @abstractmethod
    def sniff(first_line: str) -> bool:
        """Returns whether first_line looks like it belongs to this format."""

    @abstractmethod
    def message_type(self, line: str) -> typing.Optional[str]:
        """Returns a short type identifier for line, used to match --exclude, or None if line
        does not have a recognizable type."""

    @abstractmethod
    def timestamp(self, line: str) -> typing.Optional[datetime]:
        """Returns the timestamp carried by line, or None if line carries no usable timestamp.

        Implementations may be stateful, tracking enough history to return monotonic
        datetimes even when the underlying format only encodes a partial date/time.
        """


class Nmea0183Format(MessageFormat):
    """The ASCII NMEA0183 message format, timed using ZDA sentences."""

    name = "0183"
    per_line_timing = False

    @staticmethod
    def sniff(first_line: str) -> bool:
        return first_line.startswith("$") or first_line.startswith("!")

    def message_type(self, line: str) -> typing.Optional[str]:
        return line[3:6] if len(line) > 6 else None

    def timestamp(self, line: str) -> typing.Optional[datetime]:
        if self.message_type(line) != "ZDA":
            return None
        try:
            # Returns the date encoded in a NMEA ZDA message, note this does not verify the
            # checksum and does not fail elegantly if the message happened to be corrupted.
            data = line.split(",")
            microsecond = int(float(data[1][6:]) * 1000000.0)
            return datetime(
                int(data[4]),
                int(data[3]),
                int(data[2]),
                int(data[1][0:2]),
                int(data[1][2:4]),
                int(data[1][4:6]),
                microsecond,
            )
        except (ValueError, IndexError):
            return None


class RawFormat(MessageFormat):
    """The Yacht Devices "RAW" CAN frame format, timed using the leading time-of-day field."""

    name = "RAW"
    per_line_timing = True

    def __init__(self):
        self._last_time_of_day: typing.Optional[time] = None
        self._day_count = 0

    @staticmethod
    def sniff(first_line: str) -> bool:
        return _RAW_LINE_RE.match(first_line) is not None

    def message_type(self, line: str) -> typing.Optional[str]:
        match = _RAW_LINE_RE.match(line)
        if not match:
            return None
        return hex(_pgn_from_header(match.group(6)))[2:].upper()

    def timestamp(self, line: str) -> typing.Optional[datetime]:
        match = _RAW_LINE_RE.match(line)
        if not match:
            return None
        hour, minute, second, millis = (int(match.group(i)) for i in range(1, 5))
        time_of_day = time(hour, minute, second, millis * 1000)
        if self._last_time_of_day is not None:
            # Real captures interleave frames from multiple CAN sources and are not perfectly
            # monotonic, so small backward steps are jitter rather than a midnight rollover.
            # Only treat a large backward step as a day wrap.
            last_as_delta = timedelta(
                hours=self._last_time_of_day.hour,
                minutes=self._last_time_of_day.minute,
                seconds=self._last_time_of_day.second,
                microseconds=self._last_time_of_day.microsecond,
            )
            this_as_delta = timedelta(
                hours=time_of_day.hour,
                minutes=time_of_day.minute,
                seconds=time_of_day.second,
                microseconds=time_of_day.microsecond,
            )
            if last_as_delta - this_as_delta > timedelta(hours=12):
                self._day_count += 1
        self._last_time_of_day = time_of_day
        return datetime.combine(
            _RAW_EPOCH_DATE + timedelta(days=self._day_count), time_of_day
        )


def _pgn_from_header(header: str) -> int:
    """Returns the PGN encoded in an 8 hex digit CAN header, mirroring
    lib/state/parsing/2000/raw.dart's _hexHeaderToPgnSource."""
    frame_id = int(header, 16)
    data_page = (frame_id >> 24) & 0x1
    pdu_format = (frame_id >> 16) & 0xFF
    pdu_specific = (frame_id >> 8) & 0xFF
    if pdu_format < 240:
        return (data_page << 16) | (pdu_format << 8)
    return (data_page << 16) | (pdu_format << 8) | pdu_specific


FORMATS: list[type[MessageFormat]] = [Nmea0183Format, RawFormat]


def detect_format(lines: list[str]) -> MessageFormat:
    """Returns a SentenceFormat instance for the first format that recognizes the first
    non-blank line in lines. Exits with an error if no format matches."""
    first_line = next((line for line in lines if line.strip()), "")
    for format_class in FORMATS:
        if format_class.sniff(first_line):
            return format_class()
    print(f"Error: could not auto-detect format from first line: {first_line!r}")
    raise SystemExit(1)


def format_by_name(name: str, lines: list[str]) -> MessageFormat:
    """Returns a SentenceFormat instance for the named format ("auto" to detect it)."""
    if name.lower() == "auto":
        return detect_format(lines)
    for format_class in FORMATS:
        if format_class.name.lower() == name.lower():
            return format_class()
    raise ValueError(f"Unknown format: {name}")


def _resolve_format_name(value: str) -> str:
    """Normalizes a case-insensitive --format value to its canonical spelling."""
    if value.lower() == "auto":
        return "auto"
    for format_class in FORMATS:
        if format_class.name.lower() == value.lower():
            return format_class.name
    return value


def find_start_index(fmt: MessageFormat, lines: list[str], offset_minutes: int) -> int:
    """Returns the line index to start sending from when applying a time offset.

    Scans for timestamps using fmt, returns the index of the first line whose timestamp is at
    least offset_minutes after the first timestamp in the file. Exits with an error if the
    offset exceeds the file duration.
    """
    first_timestamp = None
    last_timestamp = None

    for i, line in enumerate(lines):
        ts = fmt.timestamp(line)
        if ts is None:
            continue
        if first_timestamp is None:
            first_timestamp = ts
            print(f'First timestamp: {ts.strftime("%Y-%m-%d %H:%M:%S")}')
        last_timestamp = ts
        if ts >= first_timestamp + timedelta(minutes=offset_minutes):
            print(
                f'Skipping to {ts.strftime("%Y-%m-%d %H:%M:%S")} '
                f"({offset_minutes}m offset from first timestamp, line {i + 1})"
            )
            return i

    if first_timestamp is None or last_timestamp is None:
        print("Error: no timestamps found in file, cannot apply --offset.")
    else:
        duration_min = (last_timestamp - first_timestamp).total_seconds() / 60
        print(
            f"Error: --offset {offset_minutes}m exceeds file duration of {duration_min:.1f} minutes."
        )
    raise SystemExit(1)


def send_file(args: Namespace, fmt: MessageFormat, lines: list[str]):
    """Sends all the supplied lines, corrupting some of them if requested in args."""
    exclude = set(args.exclude.split(",")) if args.exclude else set()
    start_index = find_start_index(fmt, lines, args.offset) if args.offset else 0
    remaining = lines[start_index:]

    if fmt.per_line_timing:
        _send_with_recorded_timing(args, fmt, remaining, exclude)
    else:
        _send_with_ewma_timing(args, fmt, remaining, exclude)


def _send_with_recorded_timing(
    args: Namespace, fmt: MessageFormat, lines: list[str], exclude: set[str]
):
    """Sends lines, sleeping before each one for the delta between its timestamp and the
    previous line's timestamp. Suitable for formats where every line is individually timed.
    """
    print("Sending using each line's recorded timestamp.")
    carry = ""
    last_timestamp = None
    last_progress_clock = time_module.monotonic()
    sent_since_progress = 0

    for line in lines:
        if fmt.message_type(line) in exclude:
            print(f"Not sending {line}", end="")
            continue
        timestamp = fmt.timestamp(line)
        if timestamp is not None:
            if last_timestamp is None:
                print(
                    f'Found first timestamp {timestamp.strftime("%Y-%m-%d %H:%M:%S")}'
                )
            else:
                delay = (timestamp - last_timestamp).total_seconds()
                if delay > 0:
                    time_module.sleep(delay)
            last_timestamp = timestamp

        carry = send_line(args, carry + line)
        sent_since_progress += 1

        now = time_module.monotonic()
        if now - last_progress_clock >= 5:
            print(
                f"Sent {sent_since_progress} lines in the last {now - last_progress_clock:.1f}s"
            )
            last_progress_clock = now
            sent_since_progress = 0


def _send_with_ewma_timing(
    args: Namespace, fmt: MessageFormat, lines: list[str], exclude: set[str]
):
    """Sends lines at a fixed interval, adjusting that interval with an EWMA over the ratio of
    real to data time observed between occasional timestamped lines. Suitable for formats where
    only some lines carry a timestamp (e.g. NMEA0183's ZDA sentences)."""
    carry = ""
    interval = DEFAULT_INTERVAL

    print(
        f"Sending at default interval of {interval / ONE_MS:.1f}ms until 2 timestamps are found."
    )
    last_clock = None
    last_timestamp = None
    line_count = 0

    for line in lines:
        line_count += 1
        if fmt.message_type(line) in exclude:
            print(f"Not sending {line}", end="")
            continue
        timestamp = fmt.timestamp(line)
        if timestamp is not None:
            clock = datetime.now()
            if last_timestamp is None:
                print(
                    f'Found first timestamp {timestamp.strftime("%Y-%m-%d %H:%M:%S")}'
                )
            elif timestamp <= last_timestamp:
                print(
                    f'Ignoring non-positive step. {timestamp.strftime("%Y-%m-%d %H:%M:%S")}'
                )
            elif last_clock is None or clock <= last_clock:
                print(f"Ignoring non-positive clock jump.")
            else:
                # Adjust the rate at which we send new lines based on how successful we were at
                # maintaining a real to data time ratio over the last invterval with EWMA to smooth
                # out any lumps. Message traffic can be quite bursty so this is not perfect. A
                # better solution would be to read ahead to the next timestemp into a buffer and
                # evenly distribute the sending of those messages but this is inconvenient in a
                # single thread.
                real_delta, data_delta = clock - last_clock, timestamp - last_timestamp
                raw_interval = interval * (data_delta / real_delta)
                interval = raw_interval * EWMA_ALPHA + interval * (1.0 - EWMA_ALPHA)
                print(
                    f'Timestamp {timestamp.strftime("%H:%M:%S")}: '
                    f"Sent {line_count} lines at time ratio of 1:{data_delta / real_delta:.2f}, "
                    f"adjusting interval to {interval / ONE_MS:.1f}ms"
                )
            last_clock, last_timestamp, line_count = clock, timestamp, 0

        carry = send_line(args, carry + line)
        time_module.sleep(interval.total_seconds())


def send_line(args: Namespace, line: str) -> str:
    """Sends a single line, potentially with corruption and potentially as multiple packets
    or with some of the output carried into the next send through the return value."""
    if args.corrupt and introduce_random_event():
        line = corrupt_data(line)
    if args.corrupt and introduce_random_event():
        line = truncate_data(line)
    if len(line) > 0 and introduce_random_event():
        # Send the line in two chunks
        idx = randrange(len(line))
        send_data(args, line[:idx])
        time_module.sleep(0.01)
        send_data(args, line[idx:])
    elif introduce_random_event():
        # Just carry the line to send with the next
        return line
    else:
        # Send the full line in one chunk
        send_data(args, line)
    return ""


def introduce_random_event() -> bool:
    """Returns true if some rare random event should be introduced."""
    return randrange(25) == 0


def corrupt_data(data_string: str) -> str:
    """Corrupts a single random character in the supplied input."""
    idx = randrange(len(data_string))
    new_char = chr(randrange(32, 127))
    print(f"replacing {data_string[idx]} with {new_char}")
    return data_string[:idx] + new_char + data_string[idx + 1 :]


def truncate_data(data_string: str) -> str:
    """Truncates the supplied input to a random length."""
    idx = randrange(len(data_string))
    print(f"trunctating to length {idx}")
    return data_string[:idx]


def send_data(args: Namespace, data_string: str):
    """Sends the supplied string over a new connection then closes it."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        if args.host == "255.255.255.255":
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.connect((args.host, args.port))

        msg = data_string.encode("utf-8")
        total_sent = 0
        while total_sent < len(msg):
            sent = sock.send(msg[total_sent:])
            if sent == 0:
                raise RuntimeError("Socket connection broken")
            total_sent += sent


def create_parser() -> ArgumentParser:
    """Creates the definition of the expected command line flags."""

    def file_if_valid(parser, arg):
        if not os.path.exists(arg):
            parser.error(f"{arg} does not exist")
            return None
        return arg

    parser = ArgumentParser(
        description="Script to simulate a YDWG-02 NMEA bridge by broadcasting "
        "data from a file as UDP packets to localhost on the supplied port. "
        "Supports both ASCII NMEA0183 files and Yacht Devices RAW format "
        "NMEA2000 files.",
        epilog="Copyright Jody Sankey 2022-2026",
        add_help=False,
    )
    parser.add_argument(
        "--help", action="help", help="Show this help message and exit."
    )
    parser.add_argument(
        "input",
        metavar="FILE",
        type=lambda x: file_if_valid(parser, x),
        help="A file containing ASCII NMEA0183 or Yacht Devices RAW format data.",
    )
    parser.add_argument(
        "-f",
        "--format",
        action="store",
        default="auto",
        choices=["auto"] + [f.name for f in FORMATS],
        type=_resolve_format_name,
        help="Input file format, or auto to detect it from the file contents.",
    )
    parser.add_argument(
        "-p", "--port", action="store", default=1456, type=int, help="Broadcast port."
    )
    parser.add_argument(
        "-h",
        "--host",
        action="store",
        default="255.255.255.255",
        help="Destination address (use 127.0.0.1 for an Android emulator).",
    )
    parser.add_argument(
        "-c",
        "--corrupt",
        action="store_true",
        help="Introduce some message corruption.",
    )

    parser.add_argument(
        "-x",
        "--exclude",
        action="store",
        help="Comma separated list of message types to exclude.",
    )
    parser.add_argument(
        "-o",
        "--offset",
        action="store",
        type=int,
        metavar="MINUTES",
        help="Skip to this many minutes into the file before sending.",
    )
    return parser


def main():
    """Executes the script using command line arguments."""
    args = create_parser().parse_args()
    print(f"Opening file: {args.input}")
    with open(args.input, mode="r", encoding="utf-8") as f:
        lines = f.readlines()
    fmt = format_by_name(args.format, lines)
    print(f"Using format: {fmt.name}")
    send_file(args, fmt, lines)


if __name__ == "__main__":
    main()
