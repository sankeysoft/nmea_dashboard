#!/usr/bin/python3

# Copyright Jody M Sankey 2022-2023
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

"""This is a simple python script to print the presence of paritucular NMEA messages in a text
log, such as those generated by openCPN's voyage data recorder plugin."""

from argparse import ArgumentParser
from datetime import datetime, timedelta
import os
from typing import Dict, TextIO, Tuple

STALENESS_LIMIT = timedelta(seconds=60)


class SentenceData:
    """Stores information about a particular sentence type."""

    def __init__(self, type_: str) -> None:
        self.type_ = type_
        self.count = 0
        self.windows = []
        if type_ == "MDA":
            self.children = [SentenceData("- with pressure"),
                             SentenceData("- with air temp"),
                             SentenceData("- with water temp"),
                             SentenceData("- with humidity"),
                             SentenceData("- with dew point")]
        elif type_ == "XDR":
            self.children = [SentenceData("- angle"),
                             SentenceData("- pressure"),
                             SentenceData("- temperature"),
                             SentenceData("- humidity"),
                             SentenceData("- unknown")]
        else:
            self.children = []

    def record(self, event_time: timedelta, fields: Tuple[str, ...]):
        """Records a new instance of the sentence duration into the file."""
        self.count += 1
        if not self.windows or event_time - self.windows[-1][1] > STALENESS_LIMIT:
            self.windows.append([event_time, event_time])
        else:
            self.windows[-1][1] = event_time
        if self.type_ == "MDA":
            if len(fields[2]):
                self.children[0].record(event_time, fields)
            if len(fields[4]):
                self.children[1].record(event_time, fields)
            if len(fields[6]):
                self.children[2].record(event_time, fields)
            if len(fields[8]):
                self.children[3].record(event_time, fields)
            if len(fields[10]):
                self.children[4].record(event_time, fields)
        if self.type_ == "XDR":
            for i in range(0, len(fields), 4):
                if fields[i] == "A":
                    self.children[0].record(event_time, fields)
                elif fields[i] == "P":
                    self.children[1].record(event_time, fields)
                elif fields[i] == "C":
                    self.children[2].record(event_time, fields)
                elif fields[i] == "H":
                    self.children[3].record(event_time, fields)
                else:
                    self.children[4].record(event_time, fields)


    def summary(self) -> str:
        """Returns a string summary of this sentence."""
        windows = ", ".join(
            [
                f"{w[0].total_seconds():0.1f}-{w[1].total_seconds():0.1f}s"
                for w in self.windows
            ]
        )
        output = f"{self.type_}: Total {self.count:,} over time windows {windows}"
        for child in self.children:
            if child.count:
                output += f"\n{child.summary()}"
        return output


def sentence_type(line: str) -> str:
    """Returns the NMEA sentence type for the supplied string."""
    return line[3:6] if len(line) > 6 and line[0] == "$" else None


def datetime_from_zda(line: str) -> datetime:
    """Returns the date encoded in a NMEA ZDA message, note this does not verify the checksum
    and does not fail elegantly if the message happened to be corrupted."""
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


def analyze_file(args: ArgumentParser, open_file: TextIO) -> Dict[str, SentenceData]:
    """Analyzes all the lines in the supplied file, corrupting some of them if requested in args."""
    exclude = set(args.exclude.split(",")) if args.exclude else set()

    sentences = {}
    last_time = None
    start_time = None
    for line in open_file.readlines():
        type_ = sentence_type(line)
        if type_ is None or type_ in exclude:
            continue
        if type_ == "ZDA":
            last_time = datetime_from_zda(line)
            if start_time is None:
                start_time = last_time
                print(
                    f'Found first timestamp {last_time.strftime("%Y-%m-%d %H:%M:%S")}'
                )
        if type_ not in sentences:
            sentences[type_] = SentenceData(type_)
        if last_time is not None:
            sentences[type_].record(last_time - start_time, line.split(",")[1:-1])
    return sentences


def create_parser() -> ArgumentParser:
    """Creates the definition of the expected command line flags."""

    def file_if_valid(parser, arg):
        if not os.path.exists(arg):
            parser.error(f"{arg} does not exist")
            return None
        return arg

    parser = ArgumentParser(
        description="Script to print time windows for each sentence in a NMEA text log.",
        epilog="Copyright Jody Sankey 2023",
    )
    parser.add_argument(
        "input",
        metavar="NMEA_FILE",
        type=lambda x: file_if_valid(parser, x),
        help="A file containing ASCII NMEA0183 data.",
    )
    parser.add_argument(
        "-x",
        "--exclude",
        action="store",
        help="Comma separated list of message types to exclude.",
    )
    return parser


def main():
    """Executes the script using command line arguments."""
    args = create_parser().parse_args()
    print(f"Opening file: {args.input}")
    with open(args.input, mode="r", encoding="utf-8") as f:
        sentences = analyze_file(args, f)
    for type_ in sorted(sentences):
        print(sentences[type_].summary())


if __name__ == "__main__":
    main()
