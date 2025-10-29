#' Types roclet
#'
#' This roclet generates type metadata from @typedParam and @typedReturn tags.
#' The metadata is saved to inst/types.rds and gets installed with the package.
#'
#' This function is typically used in DESCRIPTION files rather than called directly,
#' so type annotations are not enforced.
#'
#' @return A roxygen2 roclet object for type metadata generation
#' @keywords internal
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
#' @return List of type information per function/class
#' @exportS3Method roxygen2::roclet_process
roclet_process.roclet_types <- function(x, blocks, env, base_path) {
  results <- list()

  for (block in blocks) {
    # Skip if no typed tags
    if (!has_typed_tags(block)) {
      next
    }

    # Extract name (function or class)
    item_name <- get_function_name(block)
    if (is.null(item_name)) {
      next
    }

    # Check if this is an S7 class definition
    if (is_s7_class_definition(block)) {
      # Extract S7 class information
      class_info <- extract_s7_class_info(block, env)
      if (!is.null(class_info)) {
        results[[item_name]] <- class_info
      }
    } else {
      # Extract function type information
      type_info <- extract_type_info_from_block(block)
      if (!is.null(type_info)) {
        results[[item_name]] <- type_info
      }
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

  # Wrap results in appropriate export objects
  exports <- list()
  for (item_name in names(results)) {
    item <- results[[item_name]]

    # Check if this is S7 class metadata (list with is_s7_class flag)
    if (is.list(item) && !is.null(item$is_s7_class) && item$is_s7_class) {
      # Wrap in exported_class
      exports[[item_name]] <- exported_class(
        name = item_name,
        export_type = "class",
        class_system = item$class_system,
        constructor_signature = item$constructor_signature,
        properties = item$properties
      )
    } else {
      # Wrap function_signature in exported_function
      exports[[item_name]] <- exported_function(
        name = item_name,
        export_type = "function",
        signature = item
      )
    }
  }

  # Extract package info from DESCRIPTION
  desc_file <- file.path(base_path, "DESCRIPTION")
  package_name <- "unknown"
  package_version <- "0.0.0"

  if (file.exists(desc_file)) {
    desc_lines <- readLines(desc_file, warn = FALSE)

    # Extract Package field
    pkg_line <- grep("^Package:", desc_lines, value = TRUE)
    if (length(pkg_line) > 0) {
      package_name <- sub("^Package:\\s*", "", pkg_line[1])
    }

    # Extract Version field
    ver_line <- grep("^Version:", desc_lines, value = TRUE)
    if (length(ver_line) > 0) {
      package_version <- sub("^Version:\\s*", "", ver_line[1])
    }
  }

  # Create type_metadata container
  metadata <- type_metadata(
    format_version = 1L,
    rdoc_version = as.character(utils::packageVersion("rdoc")),
    generated_at = Sys.time(),
    package_info = list(
      name = package_name,
      version = package_version
    ),
    exports = exports
  )

  # Write types to RDS file
  # S7 objects serialize perfectly with saveRDS
  types_file <- file.path(inst_dir, "types.rds")
  saveRDS(metadata, types_file, version = 2)

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
#' @return FunctionSignature S7 object or NULL
#' @keywords internal
extract_type_info_from_block <- function(block) {
  params <- list()
  return_type <- NULL

  for (tag in block$tags) {
    if (inherits(tag, "roxy_tag_typedParam")) {
      param_name <- tag$val$param
      params[[param_name]] <- param_type(
        type = tag$val$type,
        description = tag$val$description
      )
    } else if (inherits(tag, "roxy_tag_typedReturn")) {
      return_type <- return_type(
        type = tag$val$type,
        description = tag$val$description
      )
    }
  }

  # Only return if we have at least params or return type
  if (length(params) > 0 || !is.null(return_type)) {
    function_signature(
      params = params,
      return = return_type
    )
  } else {
    NULL
  }
}

#' Check if block represents an S7 class definition
#'
#' @param block A roxy_block object
#' @return Logical
#' @keywords internal
is_s7_class_definition <- function(block) {
  if (is.null(block$object) || is.null(block$object$value)) {
    return(FALSE)
  }

  # Check if the value contains S7::new_class
  value_str <- deparse(block$object$value, width.cutoff = 500L)
  value_str <- paste(value_str, collapse = " ")

  grepl("S7::new_class", value_str, fixed = TRUE) ||
    grepl("new_class", value_str, fixed = TRUE)
}

#' Extract S7 class information from a roxygen block
#'
#' @param block A roxy_block object
#' @param env Environment
#' @return List with class_system, constructor_signature, properties, or NULL
#' @keywords internal
extract_s7_class_info <- function(block, env) {
  # Extract constructor signature from @typedParam/@typedReturn
  constructor_sig <- extract_type_info_from_block(block)

  # Parse S7::new_class call to extract properties
  properties <- extract_s7_properties(block$object$value, env)

  # Return metadata structure that roclet_output can identify
  list(
    is_s7_class = TRUE,
    class_system = "S7",
    constructor_signature = constructor_sig,
    properties = properties
  )
}

#' Extract properties from S7::new_class call
#'
#' @param class_expr Expression containing S7::new_class call
#' @param env Environment
#' @return Named list of param_type objects or NULL
#' @keywords internal
extract_s7_properties <- function(class_expr, env) {
  if (is.null(class_expr)) {
    return(NULL)
  }

  # Parse the expression to find properties argument
  # S7::new_class has signature: new_class(name, parent, properties, ...)
  # We need to extract the properties argument

  tryCatch({
    # Evaluate the call structure (don't actually evaluate it)
    if (is.call(class_expr)) {
      # Find 'properties' argument
      call_args <- as.list(class_expr)

      # Look for properties in named arguments
      props_arg <- NULL
      if ("properties" %in% names(call_args)) {
        props_arg <- call_args$properties
      } else {
        # Properties might be positional (3rd argument typically)
        # S7::new_class(name, parent = NULL, properties = list(), ...)
        # Check if there's an argument that looks like a properties list
        for (i in seq_along(call_args)[-1]) {  # Skip function name
          arg <- call_args[[i]]
          if (is.call(arg) && identical(arg[[1]], quote(list))) {
            props_arg <- arg
            break
          }
        }
      }

      if (is.null(props_arg)) {
        return(NULL)
      }

      # props_arg should be a list() call
      if (is.call(props_arg) && identical(props_arg[[1]], quote(list))) {
        prop_list <- as.list(props_arg)[-1]  # Remove 'list' symbol

        if (length(prop_list) == 0) {
          return(NULL)
        }

        # Convert each property to param_type
        result <- list()
        for (prop_name in names(prop_list)) {
          prop_value <- prop_list[[prop_name]]

          # Convert S7 class object to string
          type_string <- s7_class_expr_to_string(prop_value)

          result[[prop_name]] <- param_type(
            type = type_string,
            description = ""  # Properties don't have descriptions in code
          )
        }

        return(result)
      }
    }

    NULL
  }, error = function(e) {
    # If parsing fails, return NULL
    NULL
  })
}

#' Convert S7 class expression to string
#'
#' @param expr Expression representing an S7 class type
#' @return Character string
#' @keywords internal
s7_class_expr_to_string <- function(expr) {
  if (is.symbol(expr)) {
    # Simple case: class_character, class_numeric, etc.
    return(as.character(expr))
  }

  if (is.call(expr)) {
    # Handle S7::class_character style
    if (length(expr) == 3 && identical(expr[[1]], quote(`::`))) {
      return(paste0(as.character(expr[[2]]), "::", as.character(expr[[3]])))
    }

    # Handle unions: S7::new_union(class_character, NULL)
    # For now, just deparse it
    return(deparse(expr, width.cutoff = 500L)[1])
  }

  # Fallback: deparse the expression
  deparse(expr, width.cutoff = 500L)[1]
}

#' @exportS3Method roxygen2::roclet_tags
roclet_tags.roclet_types <- function(x) {
  list(
    typedParam = roxygen2::tag_markdown(),
    typedReturn = roxygen2::tag_markdown()
  )
}
