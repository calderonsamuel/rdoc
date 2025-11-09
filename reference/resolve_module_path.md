# Resolve module path to file on disk

Converts box module paths to actual .r/.R file paths. Handles:

- Absolute module paths: mod/math → \<search_path\>/mod/math.r

- Relative paths: ./utils → \<current_file_dir\>/utils.r

- Parent paths: ../shared/helpers →
  \<current_file_dir\>/../shared/helpers.r

## Usage

``` r
resolve_module_path(
  module_path,
  current_file,
  search_paths = get_box_search_paths()
)
```

## Arguments

- module_path:

  Module path as written in box::use() (e.g., "mod/math", "./utils")

- current_file:

  Path to file containing the box::use() call (for relative path
  resolution)

- search_paths:

  Character vector of box.path search directories

## Value

Absolute path to .r/.R file, or NULL if not found

## Examples

``` r
if (FALSE) { # \dontrun{
# Absolute module path
resolve_module_path("mod/math", "/proj/script.r", c("/proj/R/modules"))
# Returns: "/proj/R/modules/mod/math.r"

# Relative path
resolve_module_path("./utils", "/proj/analysis/script.r", c("/proj"))
# Returns: "/proj/analysis/utils.r"
} # }
```
