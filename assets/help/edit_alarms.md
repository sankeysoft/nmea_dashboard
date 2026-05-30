This form lets you define alarms based on the value of data elements. For
example, you could set alarms for "depth below 3 metres", "TWS above 25kt",
or "COG outside 170M-190M".

Alarms come in two levels and these are presented differently:

* **Warning** - All cells displaying the data are highlighted red, a
  popup dialog is displayed, and optionally audio is played.
* **Caution** - All cells displaying the data are highlighted yellow, no
  popup is displayed and audio is not played.

You can define multiple alarms on the same data element, so you could set a 
caution for depth below 6 metres and a warning for depth below 3 metres.

Alarms can be set on either the current value or the average value. When
any alarm is active for a data element all cells for that element will be
highlighted whether they are displaying current value, an average, or
a history.

*BE CAREFUL WITH THIS FEATURE. AUDIO WON'T PLAY UNLESS THE DEVICE IS UNLOCKED
WITH THE APP RUNNING IN FOREGROUND. IF VOLUME IS LOW OR MUTED YOU MAY NOT
HEAR THE ALARM.*

# Controls

The middle of the form lists the alarms that are currently defined:

* Tap an alarm to edit it
* Long hold an alarm then drag to change its position
* Tap the trash can next to an element to delete it.
* Tap "Add new alarm" to add a new alarm.

**Close**: This button closes the form.

# Toolbar

At the top right there are three buttons:

1.  **Copy to clipboard**. Tapping this copies the definition of all alarms
    to text in the clipboard. You could then paste into a text file or an email
    to synchronize your settings across devices, back them up, or share
    them with others.
2.  **Paste from clipboard**. Tapping this replaces the current alarms with
    those in the clipboard. The contents of the clipboard must have been
    created using the "copy to clipboard" button.
3.  **Help**. Displays this text.
