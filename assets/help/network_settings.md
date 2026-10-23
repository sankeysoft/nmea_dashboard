This form is where you define how to read NMEA data from a network.

The settings you use here should match those on whichever device is sending your
NMEA data. You'll also need to be connected to the same WiFi network as the
device sending the NMEA data.  

# Controls

* **Mode**: Either listen for broadcast UDP packets, or connect to a TCP port.

* **IP Address**: Which IP address to connect to (only used when Mode is
  "Connect to TCP port").

* **Port number**: The port number to listen on (when Mode is "Listen on UDP
  port") or to connect to (when Mode is "Connect to TCP port").

* **Protocol**: The NMEA protocol and IP framing to use. Select:

    * *"NMEA0183 (checksum)"* for comma separated 0183 format sentences, ignoring
       any sentences that do not contain a checksum. Most NMEA 0183 sentences
       contain a checksum to detect and ignore corrupted data so this is
       normally the best choice.
    * *"NMEA0183 (no checksum)"* for comma separated 0183 format sentences,
       accepting sentences with or without a checksum. You may need this option
       if a device on your network does not generate checksums, but it will
       potentially allow corrupted data.
    * *"NMEA2000 ActiSense NGT"* for binary assembled NMEA2000 messages using DLE
       escapes to delimit mesages (not yet tested with real hardware). 
    * *"NMEA2000 YD RAW"* for Yacht Devices' per frame text-based NMEA2000 format
       (less efficient than the binary NMEA2000 formats).

* **Staleness**: The time to wait before removing old data from the display and
  replacing it with dashes. For example, if a depth has not been received for
  longer than this time then everywhere depth is displayed will be replaced with
  dashes. Different boats send different data at different rates so you may need
  to change this value. It should be large enough that you don't see dashes
  while everything is working fine and small enough that you would notice in a
  reasonably short time if something does fail.

* **Default magnetic variation**: Turn this on to supply a default magnetic
  variation to use when variation is not received from the network. Enter the
  default variation in degrees and select whether it is West or East.

* **Save**: Save the changes and close the form. Alternatively tap the back
  arrow (at the top left) to close the form without saving changes.