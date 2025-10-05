#' Parse @typedParam tag
#'
#' This tag works as both @param (for roxygen2 documentation) and provides
#' type information for static type checking. Format: name {type} description
#'
#' @param x A roxy_tag object
#' @return A roxy_tag object with param class for roxygen2 compatibility
#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_typedParam <- function(x) {
  tag_parse_typed_param(x)
}

#' Parse @typedReturn tag
#'
#' This tag works as both @return (for roxygen2 documentation) and provides
#' type information for static type checking. Format: {type} description
#'
#' @param x A roxy_tag object
#' @return A roxy_tag object with return class for roxygen2 compatibility
#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_typedReturn <- function(x) {
  tag_parse_typed_return(x)
}

#' Internal parser for typed-param
#'
#' Parses the format: "param_name {type} description"
#' Creates a structure compatible with roxygen2's @param tag
#'
#' @param x A roxy_tag object
#' @return A roxy_tag object with both type info and @param compatibility
#' @keywords internal
tag_parse_typed_param <- function(x) {
  # Pattern: param_name {type} description
  pattern <- "^(\\S+)\\s+\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(x$raw, regexec(pattern, x$raw))[[1]]

  if (length(matches) != 4) {
    cli::cli_abort(
      c(
        "Invalid {.code @typedParam} format",
        "x" = "Expected format: {.code param_name {{type}} description}",
        "i" = "Got: {.code {x$raw}}"
      )
    )
  }

  param_name <- matches[2]
  type_spec <- matches[3]
  description <- matches[4]

  # Store both rdoc-specific and roxygen2-compatible information
  x$val <- list(
    # For rdoc type checking
    param = param_name,
    type = type_spec,
    description = description,
    # For roxygen2 @param compatibility
    name = param_name  # roxygen2 expects 'name' field
  )

  # Add roxy_tag_param class so roxygen2 treats this as @param
  class(x) <- c("roxy_tag_typedParam", "roxy_tag_param", "roxy_tag")

  x
}

#' Internal parser for typed-return
#'
#' Parses the format: "{type} description"
#' Creates a structure compatible with roxygen2's @return tag
#'
#' @param x A roxy_tag object
#' @return A roxy_tag object with both type info and @return compatibility
#' @keywords internal
tag_parse_typed_return <- function(x) {
  # Pattern: {type} description
  pattern <- "^\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(x$raw, regexec(pattern, x$raw))[[1]]

  if (length(matches) != 3) {
    cli::cli_abort(
      c(
        "Invalid {.code @typedReturn} format",
        "x" = "Expected format: {.code {{type}} description}",
        "i" = "Got: {.code {x$raw}}"
      )
    )
  }

  type_spec <- matches[2]
  description <- matches[3]

  # Store both rdoc-specific and roxygen2-compatible information
  # Use consistent list structure like @typedParam
  x$val <- list(
    type = type_spec,
    description = description
  )

  # Add return class for roxygen2 compatibility
  class(x) <- c("roxy_tag_typedReturn", "roxy_tag_return", "roxy_tag")

  x
}


#' Register tags with rd roclet
#'
#' Tells roxygen2's rd roclet about our custom tags
#'
#' @param x The roclet
#' @return List of tag configurations
#' @exportS3Method roxygen2::roclet_tags
#' @keywords internal
roclet_tags.roclet_rd <- function(x) {
  # Get default tags from roxygen2
  default_tags <- NextMethod()
  
  # Add our custom tags
  default_tags$typedParam <- roxygen2::tag_markdown()
  default_tags$typedReturn <- roxygen2::tag_markdown()
  
  default_tags
}

#' Convert @typedParam to rd_section
#'
#' @param x A roxy_tag_typedParam object
#' @param base_path Base path
#' @param env Environment
#' @return An rd_section object
#' @exportS3Method roxygen2::roxy_tag_rd
#' @keywords internal
roxy_tag_rd.roxy_tag_typedParam <- function(x, base_path, env) {
  # Create rd_section for param, following roxygen2's pattern
  value <- setNames(x$val$description, x$val$name)
  roxygen2::rd_section("param", value)
}

#' Convert @typedReturn to rd_section
#'
#' @param x A roxy_tag_typedReturn object
#' @param base_path Base path
#' @param env Environment
#' @return An rd_section object
#' @exportS3Method roxygen2::roxy_tag_rd
#' @keywords internal
roxy_tag_rd.roxy_tag_typedReturn <- function(x, base_path, env) {
  # Create rd_section for value/return, following roxygen2's pattern
  # x$val is now a list with type and description
  roxygen2::rd_section("value", x$val$description)
}
