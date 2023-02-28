This form lets you define a new data element that is derived from existing data.

For example, you could:
1.  Define a "depth below waterline" element that is equal to "depth at sensor"
    plus the depth of the fathometer on your boat.
2.  Correct for a anemometer that reads 5% slow by multiplying the raw wind
    speed by a factor of 1.05.

*IT WOULD BE VERY EASY TO MAKE MISTAKES AND DEFINE MISLEADING DATA - PLEASE USE
THIS FEATURE WITH CARE!*

# Controls

* **Derived Name**: The name of the derived data element. This name is used when
  selecting the derived element to display in a cell.

* **Input source**: Where the original data come from. Either a network or the
  local device. Defining derived data elements based on other derived data
  elements is not yet supported.

* **Input element**: Which original data the derived element is based on. Note
  that not all elements that can be displayed can be used as an input element.
  Generally elements that are displayed as a single numeric value (e.g. wind
  speed) are supported while elements that are displayed in some other fashion
  (e.g. position) are not supported.

* **Input unit**: The units that should be used while applying the operation.

* **Operation**: The mathematical operation used to create the derived data from
  the input data. In the example above, if the fathometer was 1.8 feet below the
  waterline the operation used to define "depth below waterline" from "depth at
  sensor" would be "+ 1.8". Input units would be set to "feet".

* **Save**: Save the changes and close the form. Alternatively tap the back
  arrow (at the top left) to close the form without saving changes.
