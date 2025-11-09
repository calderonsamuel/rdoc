# Parse type specification with bracket constraints

Parses type specifications supporting:

- Element type constraints: class_list\<class_integer\>

## Usage

``` r
parse_type_constraints(type_spec, validate = TRUE)
```

## Arguments

- type_spec:

  Type specification string (e.g., "class_list\<class_integer\>")

- validate:

  Whether to validate syntax (default TRUE). Set to FALSE if syntax was
  already validated during tag parsing.

## Value

List with base_type and element_type

## Examples

``` r
if (FALSE) { # \dontrun{
# Element type constraint
parse_type_constraints("class_list<class_integer>")
# Returns: list(base_type = "class_list", element_type = "class_integer")
} # }
```
