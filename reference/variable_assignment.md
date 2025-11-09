# Variable Assignment Information

Represents a variable assignment detected during static analysis. Used
to track variable types across the file for type inference.

## Usage

``` r
variable_assignment(
  line = integer(0),
  type = character(0),
  value_node = (function (.data) 
 {
    
    stop(sprintf("S3 class <%s> doesn't have a constructor", class[[1]]), call. =
    FALSE)
 })()
)
```

## Details

This class serves two purposes in the linting pipeline:

1.  **During extraction**: Stores assignment location and the XML node
    to analyze later

2.  **During caching**: Stores assignment location and the inferred type
    for lookup

The `value_node` field is optional because:

- Present during extraction (needs to be analyzed)

- NULL during caching (type already inferred, node no longer needed)

## Fields

- `line`:

  Integer line number where assignment occurs (1-indexed)

- `type`:

  Character string with inferred type (e.g., "class_integer", "unknown")

- `value_node`:

  Optional XML node representing the assigned value expression
