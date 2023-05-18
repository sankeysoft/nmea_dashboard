#!/usr/bin/python3

# Copyright Jody M Sankey 2022-2023
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

"""This is a simple python script I use to playback recorded NMEA network on a local network
during development, optionally with fragmentation, trunctation and corruption."""

from argparse import ArgumentParser
from datetime import datetime, timedelta
import socket
import os
from random import randrange
import time
import typing


DEFAULT_INTERVAL = timedelta(milliseconds=50)
EWMA_ALPHA = 0.2
ONE_MS = timedelta(milliseconds=1)


def send_file(args: ArgumentParser, open_file: typing.TextIO):
    """Sends all the lines in the supplied file, corrupting some of them if requested in args."""
    exclude = set(args.exclude.split(',')) if args.exclude else set()
    carry = ''
    interval = DEFAULT_INTERVAL

    print(f'Sending at default interval of {interval / ONE_MS:.1f}ms until 2 timestamps are found.')
    last_clock = None
    last_timestamp = None
    line_count = 0

    for line in open_file.readlines():
        line_count += 1
        if sentence_type(line) in exclude:
            print(f'Not sending {line}', end='')
            continue
        if sentence_type(line) == 'ZDA':
            clock, timestamp = datetime.now(), datetime_from_zda(line)
            if last_timestamp is None:
                print(f'Found first timestamp {timestamp.strftime("%Y-%m-%d %H:%M:%S")}')
            elif timestamp <= last_timestamp or clock <= last_clock:
                print(f'Ignoring non-positive step. {timestamp.strftime("%Y-%m-%d %H:%M:%S")}')
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
                print(f'Timestamp {timestamp.strftime("%H:%M:%S")}: '
                      f'Sent {line_count} lines at time ratio of 1:{data_delta / real_delta:.2f}, '
                      f'adjusting interval to {interval / ONE_MS:.1f}ms')
            last_clock, last_timestamp, line_count = clock, timestamp, 0

        carry = send_line(args, carry + line)
        time.sleep(interval.total_seconds())


def sentence_type(line: str) -> str:
    """Returns the NMEA sentence type for the supplied string."""
    return line[3:6] if len(line) > 6 else None


def datetime_from_zda(line: str) -> datetime:
    """Returns the date encoded in a NMEA ZDA message, note this does not verify the checksum
    and does not fail elegantly if the message happened to be corrupted."""
    data = line.split(',')
    microsecond = int(float(data[1][6:]) * 1000000.0)
    return datetime(int(data[4]), int(data[3]), int(data[2]),
                    int(data[1][0:2]), int(data[1][2:4]), int(data[1][4:6]), microsecond)


def send_line(args: ArgumentParser, line: str) -> str:
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
        time.sleep(0.01)
        send_data(args, line[idx:])
    elif introduce_random_event():
        # Just carry the line to send with the next
        return line
    else:
        # Send the full line in one chunk
        send_data(args, line)
    return ''


def introduce_random_event() -> bool:
    """Returns true if some rare random event should be introduced."""
    return randrange(25) == 0


def corrupt_data(data_string: str) -> str:
    """Corrupts a single random character in the supplied input."""
    idx = randrange(len(data_string))
    new_char = chr(randrange(32, 127))
    print(f'replacing {data_string[idx]} with {new_char}')
    return data_string[:idx] + new_char + data_string[idx+1:]


def truncate_data(data_string: str) -> str:
    """Truncates the supplied input to a random length."""
    idx = randrange(len(data_string))
    print(f'trunctating to length {idx}')
    return data_string[:idx]


def send_data(args: ArgumentParser, data_string: str):
    """Sends the supplied string over a new connection then closes it."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.connect(('255.255.255.255', args.port))

        msg = data_string.encode('utf-8')
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
            parser.error(f'{arg} does not exist')
            return None
        return arg

    parser = ArgumentParser(
        description='Script to simulate a YDWG-02 NMEA bridge by broadcasting '
                    'data from a file as UDP packets to localhost on the '
                    'supplied port.',
        epilog='Copyright Jody Sankey 2022')
    parser.add_argument('input', metavar='NMEA_FILE',
                        type=lambda x: file_if_valid(parser, x),
                        help='A file containing ASCII NMEA0183 data.')
    parser.add_argument('-p', '--port', action='store', default=2000, type=int,
                        help='Broadcast port.')
    parser.add_argument('-c', '--corrupt', action='store_true',
                        help='Introduce some message corruption.')

    parser.add_argument('-x', '--exclude', action='store',
                        help='Comma separated list of message types to exclude.')
    return parser


def main():
    """Executes the script using command line arguments."""
    args = create_parser().parse_args()
    print(f'Opening file: {args.input}')
    with open(args.input, mode='r', encoding='utf-8') as f:
        send_file(args, f)


if __name__ == '__main__':
    main()
