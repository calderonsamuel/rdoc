# Package Type Metadata Container

Top-level container for all type metadata exported by a package. Saved
to inst/types.rds and installed with the package.

## Usage

``` r
type_metadata(
  format_version = integer(0),
  rdoc_version = character(0),
  generated_at = (function (.data = double(), tz = "") 
 {
     .POSIXct(.data, tz = tz)

    })(),
  package_info = list(),
  exports = list()
)
```

## Details

This container enables:

- Format versioning for future evolution

- Package-level metadata (version, generation time)

- Multiple export types (functions, classes, data)

- Migration between format versions

## Fields

- `format_version`:

  Integer1 - Format version (current: 1)

- `rdoc_version`:

  Character1 - rdoc version that generated this

- `generated_at`:

  POSIXct1 - Generation timestamp

- `package_info`:

  List - Package name, version, etc.

- `exports`:

  Named list - Export name -\> exported_item subclass
