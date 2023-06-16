# Basics

This app is designed to display real time data from a marine electronics
network; it isn't much use unless you have hardware that will publish NMEA-0183
messages onto a Wifi or ethernet network (I use Yacht Device's YDWG-02).

Data is displayed on one or more pages, each containing a grid of data elements.
Long hold any data element to change the data it is displaying or its format.
Each cell can hold either the current value of some property or a plot of the
property over time. Swipe left or right to move between pages (or use the number
keys if you have a keyboard).

Every form also has its own help page. Please read this by tapping the question
mark at the top right of the screen to find out more about what the form does
and why.

As a prudent mariner please use the data displayed on this app with caution and
crosscheck against other sources whenever possible. Many different things could
potentially go wrong from malfunctions in a boat's sensor to bugs in the
software to problems with your configuration.

# Menu

The button at the top left of each data page opens a menu containing
the following:

* **Night Mode**: Toggle between white and red display modes.
* **Network**: Configure the connection to your NMEA hardware.
* **Pages**: Add, delete, edit, or reorder data pages.
* **Derived Data**: Define and edit new elements derived from network data.
* **UI Style**: Configure fonts.
* **Debug Log**: Display a log of information useful for debugging.
* **Help & License**: Display this help text.

# Troubleshooting

If a data element is not available then dashes will be displayed instead of a
number. If all data elements are displaying dashes check that the network is
configured correctly in the network menu, that your device is connected to the
correct wifi network, and that the boat's network is powered. If only a few data
elements are displaying dashes it may be that a supported message is not
available on your boat's network. Check the debug log for more details.

I initially wrote this app for my own use but I plan on fixing bugs and am happy
to consider feature requests for expanding its scope. Please file these (or
upvote the existing feature requests) at *github.com/sankeysoft/nmea_dashboard*.

# License

This software is open source and licenced under the MIT License, the terms of
which are provided below.

Copyright (c) 2022-2023 Jody Sankey

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.