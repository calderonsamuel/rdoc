# Get box.path search paths configuration

Resolution order:

1.  Check if options(box.path) is already set

2.  Parse .Rprofile in project root for options(box.path = ...)

3.  Check BOX_PATH environment variable

4.  Default to current working directory

## Usage

``` r
get_box_search_paths(project_root = getwd())
```

## Arguments

- project_root:

  Root directory of the project

## Value

Character vector of search paths

## Examples

``` r
if (FALSE) { # \dontrun{
# .Rprofile contains: options(box.path = c("R/modules", "shared"))
get_box_search_paths("/path/to/project")
# Returns: c("/path/to/project/R/modules",
#            "/path/to/project/shared",
#            "/path/to/project")
} # }
```
