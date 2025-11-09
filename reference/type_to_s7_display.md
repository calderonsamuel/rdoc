# Convert type to S7 display name for error messages

Expands S7 union types (like class_numeric) to their constituent types
for clearer error messages. E.g., "class_numeric \| class_character"
becomes "class_integer \| class_double \| class_character".

## Usage

``` r
type_to_s7_display(type_string)
```

## Arguments

- type_string:

  Type string to display

## Value

Display name with S7 unions expanded

## Examples

``` r
if (FALSE) { # \dontrun{
type_to_s7_display("class_integer")  # "class_integer"
type_to_s7_display("class_numeric")  # "class_integer | class_double"
# Expands unions recursively:
type_to_s7_display("class_numeric | class_character")
# Returns: "class_integer | class_double | class_character"
type_to_s7_display("NULL | class_numeric")
# Returns: "NULL | class_integer | class_double"
} # }
```
