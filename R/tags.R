#' Parse @typedParam tag
#'
#' @param x A roxy_tag object
#' @return A list with param, type, and description
#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_typedParam <- function(x) {
  tag_parse_typed_param(x)
}

#' Parse @typedReturn tag
#'
#' @param x A roxy_tag object
#' @return A list with type and description
#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_typedReturn <- function(x) {
  tag_parse_typed_return(x)
}

#' Internal parser for typed-param
#'
#' Parses the format: "param_name {type} description"
#'
#' @param x A roxy_tag object
#' @return A list with param, type, and description
#' @keywords internal
tag_parse_typed_param <- function(x) {
  # Pattern: param_name {type} description
  pattern <- "^(\\S+)\\s+\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(x$raw, regexec(pattern, x$raw))[[1]]

  if (length(matches) != 4) {
    cli::cli_abort(
      c(
        "Invalid {.code @typed-param} format",
        "x" = "Expected format: {.code param_name {{type}} description}",
        "i" = "Got: {.code {x$raw}}"
      )
    )
  }

  x$val <- list(
    param = matches[2],
    type = matches[3],
    description = matches[4]
  )

  x
}

#' Internal parser for typed-return
#'
#' Parses the format: "{type} description"
#'
#' @param x A roxy_tag object
#' @return A list with type and description
#' @keywords internal
tag_parse_typed_return <- function(x) {
  # Pattern: {type} description
  pattern <- "^\\{([^}]+)\\}\\s*(.*)$"
  matches <- regmatches(x$raw, regexec(pattern, x$raw))[[1]]

  if (length(matches) != 3) {
    cli::cli_abort(
      c(
        "Invalid {.code @typed-return} format",
        "x" = "Expected format: {.code {{type}} description}",
        "i" = "Got: {.code {x$raw}}"
      )
    )
  }

  x$val <- list(
    type = matches[2],
    description = matches[3]
  )

  x
}
