.onLoad <- function(libname, pkgname) {
  # Register our custom tags with roxygen2
  # The tag parsers are already defined via S3 methods
  # but we need to ensure they're available
  invisible()
}
