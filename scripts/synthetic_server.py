#!/usr/bin/python3

# Copyright Jody M Sankey 2026
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENCE.md file for details.

"""Sends generated synthetic NMEA data as UDP broadcasts for use during development."""

from argparse import ArgumentParser
import math
import socket
import struct
import time

SEND_INTERVAL = 1.0  # 1 Hz
FEET_TO_METERS = 0.3048
KNOTS_TO_MS = 0.514444
KNOTS_TO_KMPH = 1.852
ORIGIN_LAT = 37.70522  # degrees N
ORIGIN_LON = -122.98915  # degrees E (negative = West)
CIRCLE_RADIUS_NM = 0.075  # radius of circular track (0.15 nm diameter)
WAYPOINT_LAT = 37.98910  # degrees N
WAYPOINT_LON = -122.96045  # degrees E (negative = West)
_COS_ORIGIN_LAT = math.cos(math.radians(ORIGIN_LAT))
CENTER_LON = ORIGIN_LON + CIRCLE_RADIUS_NM / (60.0 * _COS_ORIGIN_LAT)
VHF_CHANNELS = [16, 9, 68, 72]
N2K_SOURCE = 0x23  # source address of all NMEA 2000 messages
N2K_PRIORITY = 6
NA8 = 0xFF  # NMEA 2000 "data not available" for unsigned 8 bit fields and reserved bytes
NA16 = 0xFFFF  # NMEA 2000 "data not available" for unsigned 16 bit fields
NA16S = 0x7FFF  # NMEA 2000 "data not available" for signed 16 bit fields
NA32 = 0xFFFFFFFF  # NMEA 2000 "data not available" for unsigned 32 bit fields
ABSOLUTE_ZERO_C = -273.15


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
        self.hdop = 0.0
        self.distance_trip_nm = 0.0
        self.rate_of_turn = 0.0
        self.pressure_mb = 0.0
        self.air_temp_c = 0.0
        self.water_temp_c = 0.0
        self.humidity = 0.0
        self.pitch = 0.0
        self.roll = 0.0
        self.yaw = 0.0
        self.battery1_v = 0.0
        self.battery2_v = 0.0
        self.alternator1_v = 0.0
        self.alternator2_v = 0.0
        self.water1_pct = 0.0
        self.water2_pct = 0.0
        self.fuel_pct = 0.0
        self.engine1_temp_c = 0.0
        self.engine1_rpm = 0.0
        self.engine1_oil_bar = 0.0
        self.engine2_temp_c = 0.0
        self.engine2_rpm = 0.0
        self.engine2_oil_bar = 0.0
        self.dew_point_c = 0.0
        self.apparent_wind_angle = 0.0
        self.apparent_wind_speed_kt = 0.0
        self.true_wind_angle = 0.0
        self.lat = ORIGIN_LAT
        self.lon = ORIGIN_LON
        self.rmb_active = True
        self.wpt_range_nm = 0.0
        self.wpt_bearing = 0.0
        self.wpt_closing_kt = 0.0
        self.xte_nm = 0.0
        # The following values are only sent in NMEA 2000 format.
        self.battery1_a = 0.0
        self.battery2_a = 0.0
        self.battery1_soc = 0.0
        self.battery2_soc = 0.0
        self.fuel2_pct = 0.0
        self.black_water_pct = 0.0
        self.engine1_fuel_lph = 0.0
        self.engine2_fuel_lph = 0.0
        self.engine1_hours_s = 0.0
        self.engine2_hours_s = 0.0
        self.trim_port_pct = 0.0
        self.trim_stbd_pct = 0.0
        self.anchor_rode_m = 0.0
        self.vhf_channel = 16
        self._last_elapsed = 0.0
        self._last_true_heading = 0.0

    def update(self, elapsed: float):
        dt = elapsed - self._last_elapsed
        self._last_elapsed = elapsed

        phase_1m = (elapsed % 60.0) / 60.0
        t = 2.0 * phase_1m if phase_1m < 0.5 else 2.0 * (1.0 - phase_1m)
        self.variation = -10.0 - t * 2.0
        self.boat_speed_kt = 4.0 + t * 3.0
        self.trim_port_pct = 20.0 + t * 60.0
        self.trim_stbd_pct = 80.0 - t * 60.0

        phase_2m = (elapsed % 120.0) / 120.0
        t = 2.0 * phase_2m if phase_2m < 0.5 else 2.0 * (1.0 - phase_2m)
        self.depth_with_offset_ft = 10.0 + t * 90.0
        self.wind_speed_kt = 30.0 - t * 20.0
        self.rudder_angle = 2.0 + t * 2.0
        self.hdop = 0.8 + t * 1.2

        phase_5m = (elapsed % 300.0) / 300.0
        t = 2.0 * phase_5m if phase_5m < 0.5 else 2.0 * (1.0 - phase_5m)
        self.true_heading = phase_5m * 360.0
        self.pressure_mb = 1010.0 + t * 5.0
        self.air_temp_c = (70.0 + t * 5.0 - 32.0) * 5.0 / 9.0
        self.water_temp_c = (60.0 + t * 3.0 - 32.0) * 5.0 / 9.0
        self.humidity = 50.0 + t * 20.0
        self.black_water_pct = 10.0 + t * 50.0
        self.anchor_rode_m = t * 50.0

        phase_10s = (elapsed % 10.0) / 10
        self.pitch = 20.0 * math.sin(2.0 * math.pi * phase_10s)
        self.roll = 30.0 * math.sin(2.0 * math.pi * phase_10s + math.pi)
        self.yaw = 5.0 * math.sin(2.0 * math.pi * phase_10s)

        phase_2m_sin = 2.0 * math.pi * elapsed / 120.0
        self.battery1_v = 12.65 + 0.15 * math.sin(phase_2m_sin)
        self.battery2_v = 12.65 + 0.15 * math.sin(phase_2m_sin + math.pi / 3.0)
        self.alternator1_v = 13.35 + 0.15 * math.sin(phase_2m_sin)
        self.alternator2_v = 13.35 + 0.15 * math.sin(phase_2m_sin + math.pi / 3.0)
        self.engine1_temp_c = 105.0 + 5.0 * math.sin(phase_2m_sin)
        self.engine1_rpm = 2250.0 + 250.0 * math.sin(phase_2m_sin)
        self.engine1_oil_bar = 3.75 + 0.25 * math.sin(phase_2m_sin)
        self.engine2_temp_c = 105.0 + 5.0 * math.sin(phase_2m_sin + math.pi)
        self.engine2_rpm = 2250.0 + 250.0 * math.sin(phase_2m_sin + math.pi)
        self.engine2_oil_bar = 3.75 + 0.25 * math.sin(phase_2m_sin + math.pi)
        self.battery1_a = 10.0 * math.sin(phase_2m_sin)
        self.battery2_a = 10.0 * math.sin(phase_2m_sin + math.pi / 3.0)
        self.engine1_fuel_lph = 4.0 + 1.0 * math.sin(phase_2m_sin)
        self.engine2_fuel_lph = 4.0 + 1.0 * math.sin(phase_2m_sin + math.pi)
        self.engine1_hours_s = 1234.0 * 3600.0 + elapsed
        self.engine2_hours_s = 987.0 * 3600.0 + elapsed
        self.vhf_channel = VHF_CHANNELS[int(elapsed // 10.0) % len(VHF_CHANNELS)]

        phase_5m_sin = 2.0 * math.pi * elapsed / 300.0
        nm_north = CIRCLE_RADIUS_NM * math.sin(phase_5m_sin)
        nm_east = CIRCLE_RADIUS_NM * (1.0 - math.cos(phase_5m_sin))
        self.lat = ORIGIN_LAT + nm_north / 60.0
        self.lon = ORIGIN_LON + nm_east / (60.0 * _COS_ORIGIN_LAT)
        self.rmb_active = (elapsed % 300.0) < 150.0

        self.water1_pct = 87.5 + 12.5 * math.sin(phase_5m_sin)
        self.water2_pct = 87.5 + 12.5 * math.sin(phase_5m_sin + math.pi / 3.0)
        self.fuel_pct = 87.5 + 12.5 * math.sin(phase_5m_sin + 2.0 * math.pi / 3.0)
        self.fuel2_pct = 87.5 + 12.5 * math.sin(phase_5m_sin + math.pi)
        self.battery1_soc = 75.0 + 15.0 * math.sin(phase_5m_sin)
        self.battery2_soc = 75.0 + 15.0 * math.sin(phase_5m_sin + math.pi / 3.0)

        self._update_derived()

        self.distance_trip_nm += self.boat_speed_kt * dt / 3600.0

        if dt > 0:
            delta = (
                self.true_heading - self._last_true_heading + 180.0
            ) % 360.0 - 180.0
            self.rate_of_turn = delta / dt * 60.0
        self._last_true_heading = self.true_heading

    def _update_derived(self):
        """Updates the values that are calculated from other values rather than elapsed time."""
        a, b = 17.625, 243.04
        gamma = math.log(self.humidity / 100.0) + a * self.air_temp_c / (b + self.air_temp_c)
        self.dew_point_c = b * gamma / (a - gamma)

        # Apparent wind vector = true wind velocity - boat velocity, where wind direction
        # is the bearing it comes FROM (so the air moves toward wind_direction + 180°).
        wd = math.radians(self.wind_direction)
        h = math.radians(self.true_heading)
        aw_x = -self.wind_speed_kt * math.sin(wd) - self.boat_speed_kt * math.sin(h)
        aw_y = -self.wind_speed_kt * math.cos(wd) - self.boat_speed_kt * math.cos(h)
        self.apparent_wind_speed_kt = math.sqrt(aw_x**2 + aw_y**2)
        aw_from = math.degrees(math.atan2(-aw_x, -aw_y)) % 360.0
        self.apparent_wind_angle = (aw_from - self.true_heading) % 360.0

        self.true_wind_angle = (self.wind_direction - self.true_heading) % 360.0
        if self.true_wind_angle > 180:
            self.true_wind_angle -= 360.0

        # Range and bearing to the fixed waypoint are computed from the current position. XTE
        # is the signed east deviation from the circle center longitude.
        delta_lat_nm = (WAYPOINT_LAT - self.lat) * 60.0
        delta_lon_nm = (WAYPOINT_LON - self.lon) * 60.0 * math.cos(math.radians(self.lat))
        self.wpt_range_nm = math.sqrt(delta_lat_nm**2 + delta_lon_nm**2)
        self.wpt_bearing = math.degrees(math.atan2(delta_lon_nm, delta_lat_nm)) % 360.0
        self.xte_nm = (self.lon - CENTER_LON) * 60.0 * _COS_ORIGIN_LAT
        self.wpt_closing_kt = self.boat_speed_kt * (
            math.sin(h) * delta_lon_nm / self.wpt_range_nm
            + math.cos(h) * delta_lat_nm / self.wpt_range_nm
        )


def position_fields(state: State) -> str:
    """Returns the four comma separated NMEA latitude and longitude fields for the position."""
    lat_abs = abs(state.lat)
    lat_deg = int(lat_abs)
    lat_min = (lat_abs - lat_deg) * 60.0
    lat_hem = "N" if state.lat >= 0 else "S"
    lon_abs = abs(state.lon)
    lon_deg = int(lon_abs)
    lon_min = (lon_abs - lon_deg) * 60.0
    lon_hem = "E" if state.lon >= 0 else "W"
    return f"{lat_deg:02d}{lat_min:07.4f},{lat_hem},{lon_deg:03d}{lon_min:07.4f},{lon_hem}"


def gga_sentence(state: State) -> str:
    """Creates an NMEA GGA sentence with the current GPS position and HDOP."""
    utc = time.strftime("%H%M%S", time.gmtime())
    body = f"YDGGA,{utc}.00,{position_fields(state)},1,10,{state.hdop:.2f},2.5,M,-29.7,M,,"
    return f"${body}*{nmea_checksum(body)}\r\n"


def gll_sentence(state: State) -> str:
    """Creates an NMEA GLL sentence with the current GPS position."""
    body = f"YDGLL,{position_fields(state)},,A"
    return f"${body}*{nmea_checksum(body)}\r\n"


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
    pressure_bar = state.pressure_mb / 1000.0
    body = (
        f"YDMDA,,I,{pressure_bar:.4f},B,{state.air_temp_c:.1f},C,"
        f"{state.water_temp_c:.1f},C,{state.humidity:.1f},,{state.dew_point_c:.1f},C,,T,,M,,N,,M"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def mwd_sentence(state: State) -> str:
    """Creates an NMEA MWD sentence with true wind direction and speed."""
    speed_ms = state.wind_speed_kt * KNOTS_TO_MS
    body = f"YDMWD,{state.wind_direction:.1f},T,,M,{state.wind_speed_kt:.1f},N,{speed_ms:.2f},M"
    return f"${body}*{nmea_checksum(body)}\r\n"


def mwv_apparent_sentence(state: State) -> str:
    """Creates an NMEA MWV sentence for apparent wind angle and speed."""
    body = f"YDMWV,{state.apparent_wind_angle:.1f},R,{state.apparent_wind_speed_kt:.1f},N,A"
    return f"${body}*{nmea_checksum(body)}\r\n"


def mwv_true_sentence(state: State) -> str:
    """Creates an NMEA MWV sentence for true wind angle and speed."""
    body = f"YDMWV,{state.true_wind_angle:.1f},T,{state.wind_speed_kt:.1f},N,A"
    return f"${body}*{nmea_checksum(body)}\r\n"


def rmb_sentence(state: State) -> str | None:
    """Creates an NMEA RMB sentence navigating to the fixed waypoint, or None when inactive.

    Active for the first half of each 5-minute cycle.
    """
    if not state.rmb_active:
        return None

    xte_dir = "L" if state.xte_nm >= 0 else "R"

    wpt_lat_deg = int(WAYPOINT_LAT)
    wpt_lat_min = (WAYPOINT_LAT - wpt_lat_deg) * 60.0
    wpt_lon_abs = abs(WAYPOINT_LON)
    wpt_lon_deg = int(wpt_lon_abs)
    wpt_lon_min = (wpt_lon_abs - wpt_lon_deg) * 60.0
    body = (
        f"YDRMB,A,{abs(state.xte_nm):.4f},{xte_dir},ORIG,DEST,"
        f"{wpt_lat_deg:02d}{wpt_lat_min:07.5f},N,"
        f"{wpt_lon_deg:03d}{wpt_lon_min:07.5f},W,"
        f"{state.wpt_range_nm:.3f},{state.wpt_bearing:.2f},{state.wpt_closing_kt:.2f},V"
    )
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


def xdr_engine_sentence(state: State, engine: int) -> str:
    """Creates an NMEA XDR sentence with temperature, RPM, and oil pressure for one engine."""
    temp = state.engine1_temp_c if engine == 1 else state.engine2_temp_c
    rpm = state.engine1_rpm if engine == 1 else state.engine2_rpm
    oil = state.engine1_oil_bar if engine == 1 else state.engine2_oil_bar
    body = (
        f"YDXDR,"
        f"C,{temp:.1f},C,ENGINE#{engine-1},"
        f"T,{rpm:.0f},R,ENGINE#{engine-1},"
        f"P,{oil:.2f},B,ENGINEOIL#{engine-1}"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def xdr_fluid_sentence(state: State) -> str:
    """Creates an NMEA XDR sentence with water and fuel tank levels as percentages."""
    body = (
        f"YDXDR,"
        f"V,{state.water1_pct:.1f},P,FRESHWATER#0,"
        f"V,{state.water2_pct:.1f},P,FRESHWATER#1,"
        f"V,{state.fuel_pct:.1f},P,FUEL"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def xdr_voltage_sentence(state: State) -> str:
    """Creates an NMEA XDR sentence with battery and alternator voltages."""
    body = (
        f"YDXDR,"
        f"U,{state.battery1_v:.2f},V,BATTERY#0,"
        f"U,{state.battery2_v:.2f},V,BATTERY#1,"
        f"U,{state.alternator1_v:.2f},V,ALTERNATOR#0,"
        f"U,{state.alternator2_v:.2f},V,ALTERNATOR#1"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def xdr_attitude_sentence(state: State) -> str:
    """Creates an NMEA XDR sentence with pitch, roll, and yaw in degrees."""
    body = (
        f"YDXDR,"
        f"A,{state.pitch:.1f},D,PITCH,"
        f"A,{state.roll:.1f},D,ROLL,"
        f"A,{state.yaw:.1f},D,YAW"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


# ---------------------------------------------------------------------------------------------
# NMEA 2000 messages. Each function returns a list of (PGN, payload) tuples, with field layouts
# matching the parsers in lib/state/parsing/2000.
# ---------------------------------------------------------------------------------------------


def n2k_angle(degrees: float) -> int:
    """Returns an angle in the NMEA 2000 0.0001 radian resolution."""
    return round(math.radians(degrees) * 10000.0)


def n2k_bearing(degrees: float) -> int:
    """Returns a bearing in the NMEA 2000 0.0001 radian resolution, normalized to 0-360."""
    return n2k_angle(degrees % 360.0)


def n2k_speed(knots: float) -> int:
    """Returns a speed in the NMEA 2000 0.01 m/s resolution."""
    return round(knots * KNOTS_TO_MS * 100.0)


def n2k_kelvin(celcius: float, resolution: float) -> int:
    """Returns a temperature in Kelvin at the supplied resolution."""
    return round((celcius - ABSOLUTE_ZERO_C) / resolution)


def n2k_position(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs 129025 (position rapid update), 129029 (GNSS position) and 129539 (DOPs)."""
    rapid = struct.pack("<ii", round(state.lat * 1e7), round(state.lon * 1e7))
    gnss = struct.pack(
        "<BHIqqqBBBhhiB",
        NA8,
        NA16,  # Date not populated.
        NA32,  # Time not populated.
        round(state.lat * 1e16),
        round(state.lon * 1e16),
        round(2.5 * 1e6),  # Altitude.
        0x10,  # GPS, GNSS fix.
        0xFC,  # No integrity checking.
        10,  # Satellites.
        round(state.hdop * 100.0),
        NA16S,  # PDOP.
        round(-29.7 * 100.0),  # Geoidal separation.
        0,  # Reference stations.
    )
    dops = struct.pack("<BBhhh", NA8, 0xD3, round(state.hdop * 100.0), NA16S, NA16S)
    return [(129025, rapid), (129029, gnss), (129539, dops)]


def n2k_depth(state: State) -> list[tuple[int, bytes]]:
    """Creates PGN 128267 for water depth and transducer offset."""
    offset_m = state.offset_ft * FEET_TO_METERS
    depth_m = state.depth_with_offset_ft * FEET_TO_METERS - offset_m
    payload = struct.pack("<BIhB", NA8, round(depth_m * 100.0), round(offset_m * 1000.0), NA8)
    return [(128267, payload)]


def n2k_heading(state: State) -> list[tuple[int, bytes]]:
    """Creates PGN 127250 for magnetic heading and variation."""
    mag_heading = state.true_heading + state.variation
    # State variation is negative to the East, NMEA 2000 is positive to the East.
    payload = struct.pack(
        "<BHhhB", NA8, n2k_bearing(mag_heading), NA16S, n2k_angle(-state.variation), 0xFD
    )
    return [(127250, payload)]


def n2k_environment(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs 130316 (temperatures), 130313 (humidity) and 130314 (pressure)."""
    ret = []
    for source, celcius in [(0, state.water_temp_c), (1, state.air_temp_c), (9, state.dew_point_c)]:
        kelvin = n2k_kelvin(celcius, 0.001).to_bytes(3, "little")
        ret.append((130316, struct.pack("<BBB", NA8, 0, source) + kelvin + struct.pack("<H", NA16)))
    humidity = round(state.humidity / 0.004)
    ret.append((130313, struct.pack("<BBBhhB", NA8, 0, 1, humidity, NA16S, NA8)))
    ret.append((130314, struct.pack("<BBBiB", NA8, 0, 0, round(state.pressure_mb * 1000.0), NA8)))
    return ret


def n2k_wind(state: State) -> list[tuple[int, bytes]]:
    """Creates three PGN 130306 messages for true (ground), apparent, and true (boat) wind."""
    return [
        (130306, struct.pack("<BHHBH", NA8, n2k_speed(speed), n2k_bearing(angle), 0xF8 | ref, NA16))
        for (ref, speed, angle) in [
            (0, state.wind_speed_kt, state.wind_direction),
            (2, state.apparent_wind_speed_kt, state.apparent_wind_angle),
            (3, state.wind_speed_kt, state.true_wind_angle),
        ]
    ]


def n2k_navigation(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs 129283 (XTE), 129284 (navigation data) and, when closing on the waypoint,
    129301 (time to mark), or nothing when navigation is inactive."""
    if not state.rmb_active:
        return []
    # State XTE is positive to steer left, NMEA 2000 is positive to steer right.
    xte = struct.pack("<BBiBB", NA8, 0x00, round(-state.xte_nm * 1852.0 * 100.0), NA8, NA8)
    nav = struct.pack(
        "<BIBIHHHIIiih",
        NA8,
        round(state.wpt_range_nm * 1852.0 * 100.0),
        0x00,  # True bearings, not crossed, not arrived, great circle.
        NA32,  # ETA time.
        NA16,  # ETA date.
        NA16,  # Bearing origin to destination.
        n2k_bearing(state.wpt_bearing),
        NA32,  # Origin waypoint number.
        NA32,  # Destination waypoint number.
        round(WAYPOINT_LAT * 1e7),
        round(WAYPOINT_LON * 1e7),
        n2k_speed(state.wpt_closing_kt),
    )
    ret = [(129283, xte), (129284, nav)]
    if state.wpt_closing_kt > 0.5:
        time_ms = round(state.wpt_range_nm / state.wpt_closing_kt * 3600.0 * 1000.0)
        ret.append((129301, struct.pack("<BiBI", NA8, time_ms, 0xF4, NA32)))
    return ret


def n2k_motion(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs for rate of turn, rudder, attitude, set & drift, speed, COG/SOG, and log."""
    rot_rad_per_s = math.radians(state.rate_of_turn / 60.0)
    distance_total_m = round((state.distance_trip_nm + 1000.0) * 1852.0)
    distance_trip_m = round(state.distance_trip_nm * 1852.0)
    return [
        (127251, struct.pack("<BiBBB", NA8, round(rot_rad_per_s / 3.125e-8), NA8, NA8, NA8)),
        (127245, struct.pack("<BBhhH", 0, NA8, NA16S, n2k_angle(state.rudder_angle), NA16)),
        (
            127257,
            struct.pack(
                "<BhhhB",
                NA8,
                n2k_angle(state.yaw),
                n2k_angle(state.pitch),
                n2k_angle(state.roll),
                NA8,
            ),
        ),
        (129291, struct.pack("<BBHHBB", NA8, 0xFC, 0, 0, NA8, NA8)),
        (128259, struct.pack("<BHHBBB", NA8, n2k_speed(state.boat_speed_kt), NA16, 0, NA8, NA8)),
        (
            129026,
            struct.pack(
                "<BBHHH",
                NA8,
                0xFC,
                n2k_bearing(state.true_heading),
                n2k_speed(state.boat_speed_kt),
                NA16,
            ),
        ),
        (128275, struct.pack("<HIII", NA16, NA32, distance_total_m, distance_trip_m)),
    ]


def n2k_electrical(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs 127508 (battery status) and 127506 (DC detailed status) for two batteries."""
    ret = []
    for instance, volts, amps in [
        (0, state.battery1_v, state.battery1_a),
        (1, state.battery2_v, state.battery2_a),
    ]:
        payload = struct.pack(
            "<BhhHB", instance, round(volts * 100.0), round(amps * 10.0), NA16, NA8
        )
        ret.append((127508, payload))
    for instance, soc in [(0, state.battery1_soc), (1, state.battery2_soc)]:
        payload = struct.pack("<BBBBBHHH", NA8, instance, 0, round(soc), NA8, NA16, NA16, NA16)
        ret.append((127506, payload))
    return ret


def n2k_tanks(state: State) -> list[tuple[int, bytes]]:
    """Creates PGN 127505 messages for each fuel, fresh water, and black water tank."""
    return [
        (127505, struct.pack("<BhIB", tank_type << 4 | instance, round(pct / 0.004), NA32, NA8))
        for (tank_type, instance, pct) in [
            (0, 0, state.fuel_pct),
            (0, 1, state.fuel2_pct),
            (1, 0, state.water1_pct),
            (1, 1, state.water2_pct),
            (5, 0, state.black_water_pct),
        ]
    ]


def n2k_engines(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs 127488 (engine rapid update) and 127489 (engine dynamic) for two engines."""
    ret = []
    for instance, rpm, oil_bar, temp_c, alt_v, fuel_lph, hours_s in [
        (
            0,
            state.engine1_rpm,
            state.engine1_oil_bar,
            state.engine1_temp_c,
            state.alternator1_v,
            state.engine1_fuel_lph,
            state.engine1_hours_s,
        ),
        (
            1,
            state.engine2_rpm,
            state.engine2_oil_bar,
            state.engine2_temp_c,
            state.alternator2_v,
            state.engine2_fuel_lph,
            state.engine2_hours_s,
        ),
    ]:
        rapid = struct.pack("<BHHbBB", instance, round(rpm * 4.0), NA16, 0x7F, NA8, NA8)
        dynamic = struct.pack(
            "<BHHHhhIHHBHHbb",
            instance,
            round(oil_bar * 1000.0),  # 100 Pa resolution.
            NA16,  # Oil temperature.
            n2k_kelvin(temp_c, 0.01),
            round(alt_v * 100.0),
            round(fuel_lph * 10.0),
            round(hours_s),
            NA16,  # Coolant pressure.
            NA16,  # Fuel pressure.
            NA8,
            0,  # Discrete status 1.
            0,  # Discrete status 2.
            0x7F,  # Load.
            0x7F,  # Torque.
        )
        ret += [(127488, rapid), (127489, dynamic)]
    return ret


def n2k_systems(state: State) -> list[tuple[int, bytes]]:
    """Creates PGNs 130576 (trim tabs), 128777 (windlass) and 129799 (radio frequency)."""
    channel = f"901{state.vhf_channel:03d}".encode("ascii")
    return [
        (
            130576,
            struct.pack(
                "<bb6B", round(state.trim_port_pct), round(state.trim_stbd_pct), *[NA8] * 6
            ),
        ),
        (128777, struct.pack("<BBBHHB", NA8, 0, NA8, round(state.anchor_rode_m * 10.0), NA16, NA8)),
        (129799, struct.pack("<II6sBBBH", NA32, NA32, channel, NA8, NA8, NA8, NA16)),
    ]


class YdRawFramer:
    """Converts NMEA 2000 messages into Yacht Devices RAW format lines, splitting messages longer
    than a single CAN frame into fast frames."""

    def __init__(self):
        self._sequence_ids = {}

    def lines(self, pgn: int, payload: bytes) -> list[str]:
        """Returns the RAW format lines for one message."""
        # All the PGNs we send are PDU2 so the PGN fits directly into the CAN ID.
        can_id = (N2K_PRIORITY << 26) | (pgn << 8) | N2K_SOURCE
        now = time.time()
        millis = int(now * 1000) % 1000
        timestamp = time.strftime("%H:%M:%S", time.localtime(now)) + f".{millis:03d}"
        return [
            f"{timestamp} R {can_id:08X} {' '.join(f'{b:02X}' for b in frame)}\r\n"
            for frame in self._frames(pgn, payload)
        ]

    def _frames(self, pgn: int, payload: bytes) -> list[bytes]:
        """Returns the CAN frame data for one message."""
        if len(payload) <= 8:
            return [payload]
        sequence_id = self._sequence_ids.get(pgn, 0)
        self._sequence_ids[pgn] = (sequence_id + 1) % 8
        frames = [bytes([sequence_id << 5, len(payload)]) + payload[:6]]
        for start in range(6, len(payload), 7):
            frame = bytes([sequence_id << 5 | len(frames)]) + payload[start : start + 7]
            frames.append(frame.ljust(8, b"\xff"))
        return frames


def nmea0183_lines(state: State) -> list[str]:
    """Returns all the NMEA 0183 sentences for the current state."""
    sentences = [
        gga_sentence(state),
        gll_sentence(state),
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
        xdr_attitude_sentence(state),
        xdr_voltage_sentence(state),
        xdr_fluid_sentence(state),
        xdr_engine_sentence(state, 1),
        xdr_engine_sentence(state, 2),
        rmb_sentence(state),
    ]
    return [s for s in sentences if s is not None]


def nmea2000_lines(state: State, framer: YdRawFramer) -> list[str]:
    """Returns all the NMEA 2000 messages for the current state as RAW format lines."""
    messages = (
        n2k_position(state)
        + n2k_depth(state)
        + n2k_heading(state)
        + n2k_environment(state)
        + n2k_wind(state)
        + n2k_navigation(state)
        + n2k_motion(state)
        + n2k_electrical(state)
        + n2k_tanks(state)
        + n2k_engines(state)
        + n2k_systems(state)
    )
    return [line for (pgn, payload) in messages for line in framer.lines(pgn, payload)]


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
        add_help=False,
    )
    parser.add_argument("--help", action="help", help="Show this help message and exit.")
    parser.add_argument(
        "-p", "--port", action="store", default=2000, type=int, help="Broadcast port."
    )
    parser.add_argument(
        "-h",
        "--host",
        action="store",
        default="255.255.255.255",
        help="Destination address (use 127.0.0.1 for an Android emulator).",
    )
    parser.add_argument(
        "-f",
        "--format",
        choices=["0183", "raw"],
        default="0183",
        help="Output format, NMEA 0183 or NMEA 2000 in Yacht Devices RAW format.",
    )
    return parser


def main():
    """Executes the script using command line arguments."""
    args = create_parser().parse_args()
    print(
        f"Sending synthetic {args.format} NMEA data to port {args.port} at "
        f"{1/SEND_INTERVAL:.0f} Hz"
    )

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    if args.host == "255.255.255.255":
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.connect((args.host, args.port))

    state = State()
    framer = YdRawFramer()
    start_time = time.time()
    while True:
        state.update(time.time() - start_time)
        if args.format == "raw":
            lines = nmea2000_lines(state, framer)
        else:
            lines = nmea0183_lines(state)
        for line in lines:
            send_data(sock, line)
            print(line, end="", flush=True)

        time.sleep(SEND_INTERVAL)


if __name__ == "__main__":
    main()
