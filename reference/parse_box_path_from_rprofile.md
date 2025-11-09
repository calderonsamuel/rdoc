# Parse box.path from .Rprofile file

Looks for options(box.path = ...) calls in .Rprofile and extracts the
paths.

## Usage

``` r
parse_box_path_from_rprofile(rprofile_path)
```

## Arguments

- rprofile_path:

  Path to .Rprofile file

## Value

Character vector of paths, or empty vector if not found
