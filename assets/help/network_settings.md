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

    * *NMEA0183 Text* for comma separated 0183 format sentences. 
    * *NMEA2000 ActiSence NGT* for binary assembled NMEA2000 messages using DLE
       escapes to delimit mesages (not yet tested with real hardware). 
    * *NMEA2000 YD RAW* for Yacht Devices' per frame text-based NMEA2000 format
       (less efficient than the binary NMEA2000 formats).

* **Require checksum**: (Only applies to NMEA0183) Most NMEA 0183 messages
  contain a checksum to detect and ignore corrupted data. When "require checksum"
  is on, any messages without a checksum are assumed to be corrupted and are
  ignored. When "require checksum" is off, messages without a checksum are used
  if possible. You may need to turn off "require checksum" if a device on your
  network does not generate checksums but doing so will potentially allow
  corrupted data.

* **Staleness**: The time to wait before removing old data from the display and
  replacing it with dashes. For example, if a depth has not been received for
  longer than this time then everywhere depth is displayed will be replaced with
  dashes. Different boats send different data at different rates so you may need
  to change this value. It should be large enough that you don't see dashes
  while everything is working fine and small enough that you would notice in a
  reasonably short time if something does fail.

* **Save**: Save the changes and close the form. Alternatively tap the back
  arrow (at the top left) to close the form without saving changes.