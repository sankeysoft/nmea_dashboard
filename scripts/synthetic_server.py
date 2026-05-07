#!/usr/bin/python3

# Copyright Jody M Sankey 2026
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

"""Sends generated synthetic NMEA data as UDP broadcasts for use during development."""

from argparse import ArgumentParser
import math
import socket
import time

SEND_INTERVAL = 1.0  # 1 Hz
FEET_TO_METERS = 0.3048
KNOTS_TO_MS = 0.514444
KNOTS_TO_KMPH = 1.852


def nmea_checksum(body: str) -> str:
    """Returns the two-character hex checksum for an NMEA sentence body (between $ and *)."""
    checksum = 0
    for ch in body:
        checksum ^= ord(ch)
    return f"{checksum:02X}"


class State:
    """Holds the current synthetic sensor values, updated each tick from elapsed time."""

    def __init__(self):
        self.true_heading = 0.0
        self.variation = 0.0
        self.depth_with_offset_ft = 0.0
        self.offset_ft = 5.0
        self.wind_direction = 270.0
        self.wind_speed_kt = 0.0
        self.boat_speed_kt = 0.0
        self.rudder_angle = 0.0
        self.distance_trip_nm = 0.0
        self.rate_of_turn = 0.0
        self.pressure_mb = 0.0
        self.air_temp_c = 0.0
        self.water_temp_c = 0.0
        self.humidity = 0.0
        self._last_elapsed = 0.0
        self._last_true_heading = 0.0

    def update(self, elapsed: float):
        dt = elapsed - self._last_elapsed
        self._last_elapsed = elapsed

        self.true_heading = (elapsed % 60.0) / 60.0 * 360.0

        phase_1m = elapsed % 60.0
        t = phase_1m / 30.0 if phase_1m < 30.0 else (60.0 - phase_1m) / 30.0
        self.variation = -10.0 - t * 2.0
        self.boat_speed_kt = 4.0 + t * 3.0

        phase_2m = elapsed % 120.0
        t = phase_2m / 60.0 if phase_2m < 60.0 else (120.0 - phase_2m) / 60.0
        self.depth_with_offset_ft = 10.0 + t * 90.0
        self.wind_speed_kt = 10.0 + t * 15.0
        self.rudder_angle = 2.0 + t * 2.0

        phase_5m = elapsed % 300.0
        t = phase_5m / 150.0 if phase_5m < 150.0 else (300.0 - phase_5m) / 150.0
        self.pressure_mb = 1010.0 + t * 5.0
        self.air_temp_c = (70.0 + t * 5.0 - 32.0) * 5.0 / 9.0
        self.water_temp_c = (60.0 + t * 3.0 - 32.0) * 5.0 / 9.0
        self.humidity = 50.0 + t * 20.0

        self.distance_trip_nm += self.boat_speed_kt * dt / 3600.0

        if dt > 0:
            delta = (
                self.true_heading - self._last_true_heading + 180.0
            ) % 360.0 - 180.0
            self.rate_of_turn = delta / dt * 60.0
        self._last_true_heading = self.true_heading


def dpt_sentence(state: State) -> str:
    """Creates an NMEA DPT sentence. Converts feet to meters for the sentence."""
    offset_m = state.offset_ft * FEET_TO_METERS
    depth_m = state.depth_with_offset_ft * FEET_TO_METERS - offset_m
    body = f"YDDPT,{depth_m:.2f},{offset_m:.2f}"
    return f"${body}*{nmea_checksum(body)}\r\n"


def hdg_sentence(state: State) -> str:
    """Creates an NMEA HDG sentence."""
    mag_heading = (state.true_heading + state.variation) % 360.0
    var_mag = abs(state.variation)
    var_dir = "E" if state.variation <= 0 else "W"
    body = f"YDHDG,{mag_heading:.1f},,,{var_mag:.1f},{var_dir}"
    return f"${body}*{nmea_checksum(body)}\r\n"


def mda_sentence(state: State) -> str:
    """Creates an NMEA MDA sentence with atmospheric data. True wind direction is not populated."""
    a, b = 17.625, 243.04
    gamma = math.log(state.humidity / 100.0) + a * state.air_temp_c / (
        b + state.air_temp_c
    )
    dew_point_c = b * gamma / (a - gamma)
    pressure_bar = state.pressure_mb / 1000.0
    body = (
        f"YDMDA,,I,{pressure_bar:.4f},B,{state.air_temp_c:.1f},C,"
        f"{state.water_temp_c:.1f},C,{state.humidity:.1f},,{dew_point_c:.1f},C,,T,,M,,N,,M"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def mwd_sentence(state: State) -> str:
    """Creates an NMEA MWD sentence with true wind direction and speed."""
    speed_ms = state.wind_speed_kt * KNOTS_TO_MS
    body = f"YDMWD,{state.wind_direction:.1f},T,,M,{state.wind_speed_kt:.1f},N,{speed_ms:.2f},M"
    return f"${body}*{nmea_checksum(body)}\r\n"


def mwv_apparent_sentence(state: State) -> str:
    """Creates an NMEA MWV sentence for apparent wind angle and speed.

    Apparent wind vector = true wind velocity - boat velocity, where wind direction
    is the bearing it comes FROM (so the air moves toward wind_direction + 180°).
    """
    wd = math.radians(state.wind_direction)
    h = math.radians(state.true_heading)
    tw_x = -state.wind_speed_kt * math.sin(wd)
    tw_y = -state.wind_speed_kt * math.cos(wd)
    bv_x = state.boat_speed_kt * math.sin(h)
    bv_y = state.boat_speed_kt * math.cos(h)
    aw_x = tw_x - bv_x
    aw_y = tw_y - bv_y
    aws = math.sqrt(aw_x**2 + aw_y**2)
    aw_from = math.degrees(math.atan2(-aw_x, -aw_y)) % 360.0
    awa = (aw_from - state.true_heading) % 360.0
    body = f"YDMWV,{awa:.1f},R,{aws:.1f},N,A"
    return f"${body}*{nmea_checksum(body)}\r\n"


def mwv_true_sentence(state: State) -> str:
    """Creates an NMEA MWV sentence for true wind angle and speed."""
    angle = (state.wind_direction - state.true_heading) % 360.0
    body = f"YDMWV,{angle:.1f},T,{state.wind_speed_kt:.1f},N,A"
    return f"${body}*{nmea_checksum(body)}\r\n"


def rot_sentence(state: State) -> str:
    """Creates an NMEA ROT sentence. Rate of turn is derived from heading change."""
    body = f"YDROT,{state.rate_of_turn:.1f},A"
    return f"${body}*{nmea_checksum(body)}\r\n"


def rsa_sentence(state: State) -> str:
    """Creates an NMEA RSA sentence for rudder angle."""
    body = f"YDRSA,{state.rudder_angle:.1f},A,,"
    return f"${body}*{nmea_checksum(body)}\r\n"


def vdr_sentence(state: State) -> str:
    """Creates an NMEA VDR sentence with zero current set and drift."""
    body = "YDVDR,0.0,T,,M,0.0,N"
    return f"${body}*{nmea_checksum(body)}\r\n"


def vhw_sentence(state: State) -> str:
    """Creates an NMEA VHW sentence with boat speed through water."""
    speed_kmph = state.boat_speed_kt * KNOTS_TO_KMPH
    body = f"YDVHW,,,,,{state.boat_speed_kt:.1f},N,{speed_kmph:.1f},K"
    return f"${body}*{nmea_checksum(body)}\r\n"


def vlw_sentence(state: State) -> str:
    """Creates an NMEA VLW sentence. Total is trip plus a fixed 1000 nm offset."""
    total = state.distance_trip_nm + 1000.0
    body = f"YDVLW,{total:.3f},N,{state.distance_trip_nm:.3f},N"
    return f"${body}*{nmea_checksum(body)}\r\n"


def vtg_sentence(state: State) -> str:
    """Creates an NMEA VTG sentence. COG matches true heading, SOG matches boat speed."""
    sog_kmph = state.boat_speed_kt * KNOTS_TO_KMPH
    body = f"YDVTG,{state.true_heading:.1f},T,,M,{state.boat_speed_kt:.1f},N,{sog_kmph:.1f},K"
    return f"${body}*{nmea_checksum(body)}\r\n"


def send_data(sock: socket.socket, data_string: str):
    """Sends the supplied string over the provided socket."""
    msg = data_string.encode("utf-8")
    total_sent = 0
    while total_sent < len(msg):
        sent = sock.send(msg[total_sent:])
        if sent == 0:
            raise RuntimeError("Socket connection broken")
        total_sent += sent


def create_parser() -> ArgumentParser:
    """Creates the definition of the expected command line flags."""
    parser = ArgumentParser(
        description="Script to send synthetic NMEA data as UDP broadcasts to localhost on the "
        "supplied port.",
        epilog="Copyright Jody Sankey 2026",
    )
    parser.add_argument(
        "-p", "--port", action="store", default=2000, type=int, help="Broadcast port."
    )
    return parser


def main():
    """Executes the script using command line arguments."""
    args = create_parser().parse_args()
    print(
        f"Sending synthetic NMEA data to port {args.port} at {1/SEND_INTERVAL:.0f} Hz"
    )

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.connect(("255.255.255.255", args.port))

    state = State()
    start_time = time.time()
    while True:
        state.update(time.time() - start_time)

        for sentence in [
            dpt_sentence(state),
            hdg_sentence(state),
            mda_sentence(state),
            mwd_sentence(state),
            mwv_apparent_sentence(state),
            mwv_true_sentence(state),
            rot_sentence(state),
            rsa_sentence(state),
            vdr_sentence(state),
            vhw_sentence(state),
            vlw_sentence(state),
            vtg_sentence(state),
        ]:
            send_data(sock, sentence)
            print(sentence, end="", flush=True)

        time.sleep(SEND_INTERVAL)


if __name__ == "__main__":
    main()
