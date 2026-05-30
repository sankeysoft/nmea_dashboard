This form lets you define an alarm based on the value of a data element.
For example, you could set an alarm for "depth below 3 metres",
"TWS above 25kt", or "COG outside 170M-190M".

Alarms come in two levels and these are presented differently:

* **Warning** - All cells displaying the data are highlighted red, a
  popup dialog is displayed, and optionally audio is played.
* **Caution** - All cells displaying the data are highlighted yellow, no
  popup is displayed and audio is not played.

For most elements you can either set an upper limit, a lower limit, or both.
For bearings you must provide an upper and lower limit to define the alarm
sector.

*BE CAREFUL WITH THIS FEATURE. AUDIO WON'T PLAY UNLESS THE DEVICE IS UNLOCKED
WITH THE APP RUNNING IN FOREGROUND. IF VOLUME IS LOW OR MUTED YOU MAY NOT
HEAR THE ALARM.*


# Controls

* **Source**: Where the data to be alarmed comes from.

* **Element**: Which data the alarm should be set on. The elements in this list
  depend on the selected source and are limited to elements that can be converted
  to a single number.

* **Value**: Whether the alarm should be set based on the most recent value or
  on an average, and the units that should be used.

* **Alarm below**: The number (in the units selected above) below which the alarm
  should be activated.

* **Alarm above**: The number (in the units selected above) above which the alarm
  should be activated.

* **Alarm type**: Warning or caution (see above).

* **Sound**: The sound to play when the alarm is activated. Only enabled for
  warnings. Tap the speaker to the right to preview the selected sound.

* **Save**: Save the changes and close the form. Alternatively tap the back
  arrow (at the top left) to close the form without saving changes.
