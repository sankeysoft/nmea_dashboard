This form lets you define one of the cells on a data page.

# Controls

* **Source**: Where the data to be displayed comes from. Either a network (as
  configured through the "network" menu), the local device, or derived data
  (defined through the "Derived Data" menu).

* **Element**: Which data should be displayed. The elements in this list depend
  on the selected source. Note that not all elements will be available on all
  networks.

* **Display**: How the data should be displayed. All elements support displaying
  the current value, some elements also support displaying an average value or a
  "history" graph of the value over time. Average values include a change bar
  indicating whether the most recent data is higher or lower than the average.
  History graphs will take some time to gather initial data before the graph
  is first displayed - longer history ranges take longer to display the initial
  data. The app can only track averages and histories while the screen is on and
  the app is displayed.

* **Format**: Which format and units should be used to display the data. The
  formats in this list depend on the selected element.

* **Set Manual Name**: Normally the name of a cell is set automatically based
  on the selected element. If you prefer you can turn "Set Manual Name" on to
  set a different name.

* **Name**: The name that will be displayed next to the data. Only editable if
  "Set Manual Name" is on.

* **Save**: Save the changes and close the form. Alternatively tap the back
  arrow (at the top left) to close the form without saving changes.