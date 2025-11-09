# Exported Class Metadata

Represents a class export (S7, R6, S3, S4) with constructor signature
and property/field definitions.

## Usage

``` r
exported_class(
  name = character(0),
  export_type = character(0),
  class_system = character(0),
  constructor_signature = function_signature(),
  properties = list()
)
```

## Fields

- `name`:

  Character1 - Class name

- `export_type`:

  Character1 - Always "class"

- `class_system`:

  Character1 - "S7", "R6", "S3", or "S4"

- `constructor_signature`:

  function_signature or NULL - Constructor types

- `properties`:

  Named list of param_type objects or NULL - Class properties/fields
