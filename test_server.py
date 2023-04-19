#!/usr/bin/python3

# Copyright Jody M Sankey 2022
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

# This is a simple python script I use to playback recorded NMEA network on a local network
# during development, optionally with fragmentation, trunctation and corruption. Note this
# **does not** attempt to playback at constant time, it waits a fixed about of time between
# each message. When more messages are present each second of recorded data will take longer
# to playback.

import argparse
import socket
import os
from random import randrange
import time

SLEEP_SEC = 0.1
RANDOM_EVENT_RANGE = 25

def send_file(args, open_file):
    """Sends all the lines in the supplied file, corrupting them if
    requested in the args."""
    exclude = set(args.exclude.split(',')) if args.exclude else set()
    carry = ''
    for line in open_file.readlines():
        if len(line) > 6 and line[3:6] in exclude:
            print(f'not sending {line}', end='')
            continue
        line = carry + line
        carry = ''
        if args.corrupt and randrange(RANDOM_EVENT_RANGE) == 0:
            line = corrupt_data(line)
        if args.corrupt and randrange(RANDOM_EVENT_RANGE) == 0:
            line = truncate_data(line)
        if randrange(RANDOM_EVENT_RANGE) == 0 and len(line) > 0:
            # Send the line in two chunks
            idx = randrange(len(line))
            print(f'splitting at index {idx}')
            send_data(args, line[:idx])
            time.sleep(SLEEP_SEC)
            send_data(args, line[idx:])
            time.sleep(SLEEP_SEC)
        elif randrange(RANDOM_EVENT_RANGE) == 0:
            # Just carry the line to send with the next
            print(f'deferring to the next send')
            carry = line
        else:
           # Send the full line in one chunk
           send_data(args, line)
           time.sleep(SLEEP_SEC)


def corrupt_data(data_string):
    """Corrupts a single random character in the supplied input."""
    idx = randrange(len(data_string))
    new_char = chr(randrange(32, 127))
    print(f'replacing {data_string[idx]} with {new_char}')
    return data_string[:idx] + new_char + data_string[idx+1:]


def truncate_data(data_string):
    """Truncates the supplied input to a random length."""
    idx = randrange(len(data_string))
    print(f'trunctating to length {idx}')
    return data_string[:idx]


def send_data(args, data_string):
    """Sends the supplied string over a new connection then closes it."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1);
        sock.connect(('255.255.255.255', args.port))

        msg = data_string.encode('utf-8')
        total_sent = 0
        while total_sent < len(msg):
            sent = sock.send(msg[total_sent:])
            if sent == 0:
                raise RuntimeError("Socket connection broken")
            total_sent += sent


def create_parser():
    """Creates the definition of the expected command line flags."""
    def file_if_valid(parser, arg):
        if not os.path.exists(arg):
            parser.error(f'{arg} does not exist')
            return None
        return arg

    parser = argparse.ArgumentParser(
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

    while True:
        print('Reopening file...')
        with open(args.input) as f:
            send_file(args, f)


if __name__ == '__main__':
    main()
