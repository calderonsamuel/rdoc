# Type reference node (e.g., "numeric", "pkg::Class")

Represents a reference to a single type, optionally qualified with a
package name and/or element type constraint.

## Usage

``` r
type_ref(base_type = character(0), package = character(0), element_type = NULL)
```

## Details

Examples:

- `numeric` → type_ref(base_type = "numeric")

- `pkg::Class` → type_ref(base_type = "Class", package = "pkg")

- `list<numeric>` → type_ref(base_type = "list", element_type = ...)

## Fields

- `base_type`:

  Character1 - the type name (e.g., "numeric")

- `package`:

  Character1 or NULL - package qualification (e.g., "pkg")

- `element_type`:

  type_ref/union_type or NULL - element type for generics
