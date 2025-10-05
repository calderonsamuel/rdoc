#' Types roclet
#'
#' This roclet generates type metadata from @typedParam and @typedReturn tags.
#' The metadata is saved to inst/types.rds and gets installed with the package.
#'
#' @typedReturn {<roclet>} A roxygen2 roclet object for type metadata generation
#' @export
#' @examples
#' \dontrun{
#' # Use in roxygen2::roxygenize()
#' roxygen2::roxygenize(roclets = c("collate", "rd", "namespace", "rdoc::roclet_types"))
#' }
roclet_types <- function() {
  roxygen2::roclet("types")
}

#' Process blocks to extract type information
#'
#' @param x The roclet
#' @param blocks List of roxy_block objects
#' @param env Environment
#' @param base_path Base path of the package
#' @return List of type information per function
#' @exportS3Method roxygen2::roclet_process
roclet_process.roclet_types <- function(x, blocks, env, base_path) {
  results <- list()

  for (block in blocks) {
    # Skip if no typed tags
    if (!has_typed_tags(block)) {
      next
    }

    # Extract function name
    fn_name <- get_function_name(block)
    if (is.null(fn_name)) {
      next
    }

    # Extract type information
    type_info <- extract_type_info_from_block(block)

    if (!is.null(type_info)) {
      results[[fn_name]] <- type_info
    }
  }

  results
}

#' Output type metadata to file
#'
#' @param x The roclet
#' @param results Results from roclet_process
#' @param base_path Base path of the package
#' @param ... Additional arguments
#' @param is_first Whether this is the first roclet run
#' @return Path to generated file
#' @exportS3Method roxygen2::roclet_output
roclet_output.roclet_types <- function(x, results, base_path, ..., is_first = TRUE) {
  # Don't create file if no types found
  if (length(results) == 0) {
    return(character())
  }

  # Create inst/ directory if needed
  inst_dir <- file.path(base_path, "inst")
  if (!dir.exists(inst_dir)) {
    dir.create(inst_dir, recursive = TRUE)
  }

  # Write types to RDS file
  types_file <- file.path(inst_dir, "types.rds")
  saveRDS(results, types_file, version = 2)

  cli::cli_alert_success("Generated type metadata for {length(results)} function{?s}")

  types_file
}

#' Check if block has typed tags
#'
#' @param block A roxy_block object
#' @return Logical
#' @keywords internal
has_typed_tags <- function(block) {
  tags <- block$tags
  any(vapply(tags, function(tag) {
    inherits(tag, "roxy_tag_typedParam") || inherits(tag, "roxy_tag_typedReturn")
  }, logical(1)))
}

#' Get function name from block
#'
#' @param block A roxy_block object
#' @return Character string or NULL
#' @keywords internal
get_function_name <- function(block) {
  if (!is.null(block$object)) {
    # Try alias first, then topic
    block$object$alias %||% block$object$topic
  } else {
    NULL
  }
}

#' Extract type information from a roxygen block
#'
#' @param block A roxy_block object
#' @return A list with params and return type info
#' @keywords internal
extract_type_info_from_block <- function(block) {
  params <- list()
  return_type <- NULL

  for (tag in block$tags) {
    if (inherits(tag, "roxy_tag_typedParam")) {
      param_name <- tag$val$param
      params[[param_name]] <- list(
        type = tag$val$type,
        description = tag$val$description
      )
    } else if (inherits(tag, "roxy_tag_typedReturn")) {
      return_type <- list(
        type = tag$val$type,
        description = tag$val$description
      )
    }
  }

  # Only return if we have at least params or return type
  if (length(params) > 0 || !is.null(return_type)) {
    result <- list()
    if (length(params) > 0) {
      result$params <- params
    }
    if (!is.null(return_type)) {
      result$return <- return_type
    }
    result
  } else {
    NULL
  }
}

#' @exportS3Method roxygen2::roclet_tags
roclet_tags.roclet_types <- function(x) {
  list(
    typedParam = roxygen2::tag_markdown(),
    typedReturn = roxygen2::tag_markdown()
  )
}
