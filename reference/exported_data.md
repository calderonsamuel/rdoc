# Exported Data Object Metadata

Represents a data object export (dataset, constant, enum).

## Usage

``` r
exported_data(
  name = character(0),
  export_type = character(0),
  type = character(0),
  dimensions = integer(0),
  description = character(0)
)
```

## Fields

- `name`:

  Character1 - Data object name

- `export_type`:

  Character1 - Always "data"

- `type`:

  Character1 - R type (e.g., "data.frame", "numeric")

- `dimensions`:

  Integer vector or NULL - Dimensions (for arrays/data.frames)

- `description`:

  Character1 - Human-readable description
