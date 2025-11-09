# Union type node (e.g., "NULL \| numeric")

Represents a union of multiple types. Enforces rdoc's opinionated rules:

- At least 2 types in the union

- NULL must appear first if present

- No duplicate NULL values

## Usage

``` r
union_type(types = list())
```

## Details

Examples:

- `NULL | numeric` → union_type(types = list(type_ref("NULL"),
  type_ref("numeric")))

- `integer | character` → union_type(types = list(type_ref("integer"),
  type_ref("character")))

## Fields

- `types`:

  List of type_ref or union_type nodes (length \>= 2)
