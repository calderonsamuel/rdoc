#' Extract box::use() import statements from XML AST
#'
#' Parses all box::use() calls in the source code and extracts:
#' - Module paths (e.g., "mod/math", "./local/utils")
#' - Import aliases (e.g., "m" in `box::use(m = mod/math)`)
#' - Selective imports (e.g., `c("add", "multiply")`)
#' - Attach-all imports (e.g., `...` syntax)
#'
#' @param xml XML parsed content from lintr
#' @return List of module imports, each with structure:
#'   list(
#'     module_path = "mod/math",           # The module path as written
#'     module_name = "math",                # Last component for lookup
#'     alias = "m" or NULL,                 # User-provided alias
#'     imports = c("add", "multiply") or NULL,  # NULL = full module import
#'     attach_all = FALSE,                  # TRUE if ... syntax used
#'     line = 5L                            # Line number of box::use() call
#'   )
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # box::use(mod/math) → full module import
#' # box::use(m = mod/math) → aliased import
#' # box::use(mod/math\[add, multiply\]) → selective import
#' # box::use(mod/math\[...\]) → attach all
#' }
extract_box_imports <- function(xml) {
  if (is.null(xml)) {
    return(list())
  }

  imports <- list()

  # Find all box::use() calls
  # XPath: Find SYMBOL_PACKAGE[text()='box'] followed by :: and use
  box_use_calls <- xml2::xml_find_all(
    xml,
    "//expr[expr/SYMBOL_PACKAGE[text()='box'] and expr/NS_GET and expr/SYMBOL_FUNCTION_CALL[text()='use']]"
  )

  for (call_expr in box_use_calls) {
    # Get the line number
    line <- as.integer(xml2::xml_attr(call_expr, "line1"))
    if (is.na(line)) line <- 1L

    # The arguments to box::use() are after the OP-LEFT-PAREN
    # Structure: expr[SYMBOL_PACKAGE/NS_GET/SYMBOL_FUNCTION_CALL]/OP-LEFT-PAREN/...args.../OP-RIGHT-PAREN

    # Find all argument expressions (they're siblings after the opening paren)
    # In box::use(), each argument is a separate import statement
    args <- extract_box_use_arguments(call_expr)

    for (arg in args) {
      import_info <- parse_box_import_arg(arg, line)
      if (!is.null(import_info)) {
        imports[[length(imports) + 1]] <- import_info
      }
    }
  }

  imports
}

#' Extract argument expressions from box::use() call
#'
#' For box::use(), arguments can be:
#' - Simple: mod/math (just an expr)
#' - Aliased: m = mod/math (SYMBOL_SUB, EQ_SUB, expr)
#' - Multiple: separated by OP-COMMA
#'
#' We need to group nodes between commas as single argument units.
#'
#' @param call_expr XML node of the box::use() call expression
#' @return List of lists, each containing nodes for one argument
#' @keywords internal
extract_box_use_arguments <- function(call_expr) {
  # Get all child nodes
  children <- xml2::xml_children(call_expr)

  # Find the position of OP-LEFT-PAREN
  paren_idx <- which(vapply(children, function(node) {
    xml2::xml_name(node) == "OP-LEFT-PAREN"
  }, logical(1)))

  if (length(paren_idx) == 0) return(list())

  # Find the position of OP-RIGHT-PAREN
  close_paren_idx <- which(vapply(children, function(node) {
    xml2::xml_name(node) == "OP-RIGHT-PAREN"
  }, logical(1)))

  if (length(close_paren_idx) == 0) return(list())

  # Group nodes between commas as arguments
  args <- list()
  current_arg_nodes <- list()

  for (i in seq_along(children)) {
    if (i > paren_idx[1] && i < close_paren_idx[length(close_paren_idx)]) {
      node <- children[[i]]
      node_name <- xml2::xml_name(node)

      if (node_name == "OP-COMMA") {
        # End of current argument
        if (length(current_arg_nodes) > 0) {
          args[[length(args) + 1]] <- current_arg_nodes
          current_arg_nodes <- list()
        }
      } else {
        # Add to current argument
        current_arg_nodes[[length(current_arg_nodes) + 1]] <- node
      }
    }
  }

  # Don't forget the last argument
  if (length(current_arg_nodes) > 0) {
    args[[length(args) + 1]] <- current_arg_nodes
  }

  args
}

#' Parse a single box::use() import argument
#'
#' @param arg_nodes List of XML nodes making up one argument
#' @param line Line number of the box::use() call
#' @return List with import information or NULL
#' @keywords internal
parse_box_import_arg <- function(arg_nodes, line) {
  if (length(arg_nodes) == 0) return(NULL)

  # Check if this is an aliased import: alias = module/path
  # Structure: [SYMBOL_SUB, EQ_SUB, expr]
  has_alias <- FALSE
  alias <- NULL
  module_expr <- NULL

  # Look for SYMBOL_SUB
  for (i in seq_along(arg_nodes)) {
    if (xml2::xml_name(arg_nodes[[i]]) == "SYMBOL_SUB") {
      has_alias <- TRUE
      alias <- xml2::xml_text(arg_nodes[[i]])
      # Module expression should be an expr node after EQ_SUB
      for (j in (i+1):length(arg_nodes)) {
        if (xml2::xml_name(arg_nodes[[j]]) == "expr") {
          module_expr <- arg_nodes[[j]]
          break
        }
      }
      break
    }
  }

  # If not aliased, the argument should be just an expr
  if (!has_alias) {
    for (node in arg_nodes) {
      if (xml2::xml_name(node) == "expr") {
        module_expr <- node
        break
      }
    }
  }

  if (is.null(module_expr)) return(NULL)

  # Parse the module path (handles slash-separated paths)
  module_path <- extract_module_path(module_expr)
  if (is.null(module_path)) return(NULL)

  # Extract module name (last component)
  path_parts <- strsplit(module_path, "/")[[1]]
  module_name <- path_parts[length(path_parts)]

  # Check for selective imports: module/path[func1, func2]
  # or attach-all: module/path[...]
  selective_imports <- NULL
  attach_all <- FALSE

  bracket_node <- xml2::xml_find_first(module_expr, ".//OP-LEFT-BRACKET")
  if (!is.na(bracket_node)) {
    # This is a selective import
    import_result <- extract_selective_imports(module_expr)
    selective_imports <- import_result$imports
    attach_all <- import_result$attach_all
  }

  list(
    module_path = module_path,
    module_name = module_name,
    alias = alias,
    imports = selective_imports,
    attach_all = attach_all,
    line = line
  )
}

#' Extract module path from expression (handles slash-separated paths)
#'
#' Parses expressions like:
#' - mod/math → "mod/math"
#' - ./local/utils → "./local/utils"
#' - ../shared/helpers → "../shared/helpers"
#'
#' @param expr_node XML node containing the module path expression
#' @return Character string with full module path, or NULL
#' @keywords internal
extract_module_path <- function(expr_node) {
  # Module paths are represented as:
  # expr[SYMBOL] / expr[SYMBOL] / expr[SYMBOL]
  # or
  # expr[SYMBOL] / expr[expr[SYMBOL] / expr[SYMBOL[...]]  (with brackets for imports)

  # collect_path_components() handles brackets automatically by stopping at them,
  # so we can just extract the path directly
  extract_slash_separated_path(expr_node)
}

#' Extract slash-separated path from expression
#'
#' Handles paths like:
#' - mod/math
#' - ./local/utils
#' - `mod/math\[add\]` (extracts "mod/math", ignoring bracket contents)
#'
#' @param expr_node XML node containing path expression
#' @return Character string with path
#' @keywords internal
extract_slash_separated_path <- function(expr_node) {
  # Look for OP-SLASH operators
  slashes <- xml2::xml_find_all(expr_node, ".//OP-SLASH")

  if (length(slashes) == 0) {
    # No slashes - just a single symbol (but might have brackets)
    # Get the first SYMBOL that's NOT inside brackets
    symbol <- xml2::xml_find_first(expr_node, "./SYMBOL | ./expr[1]/SYMBOL")
    if (is.na(symbol)) return(NULL)
    return(xml2::xml_text(symbol))
  }

  # Multiple components separated by slashes
  # Need to collect path components in order, excluding bracket contents
  # Strategy: Find all expr nodes that are siblings connected by OP-SLASH

  parts <- collect_path_components(expr_node)

  if (length(parts) == 0) return(NULL)

  paste(parts, collapse = "/")
}

#' Collect path components from slash-separated expression
#'
#' Recursively traverse the expression tree to find path components.
#' Stops at brackets - doesn't include bracket contents in path.
#'
#' @param expr_node XML node to traverse
#' @return Character vector of path components
#' @keywords internal
collect_path_components <- function(expr_node) {
  parts <- character()

  # Get direct children
  children <- xml2::xml_children(expr_node)

  for (i in seq_along(children)) {
    child <- children[[i]]
    child_name <- xml2::xml_name(child)

    if (child_name == "SYMBOL") {
      # Direct symbol - add it
      parts <- c(parts, xml2::xml_text(child))
    } else if (child_name == "expr") {
      # Check if this expr has a bracket (selective import)
      has_bracket <- !is.na(xml2::xml_find_first(child, "./OP-LEFT-BRACKET"))

      if (has_bracket) {
        # Extract the symbol before the bracket
        symbol <- xml2::xml_find_first(child, "./expr[1]/SYMBOL | ./SYMBOL")
        if (!is.na(symbol)) {
          parts <- c(parts, xml2::xml_text(symbol))
        }
        # Don't recurse into bracket contents
      } else {
        # Recurse into this expr
        sub_parts <- collect_path_components(child)
        parts <- c(parts, sub_parts)
      }
    }
    # Skip OP-SLASH - it's just a separator
  }

  parts
}

#' Extract selective imports from module expression
#'
#' Parses expressions like:
#' - `module/path\[func1, func2\]` returns `list(imports = c("func1", "func2"), attach_all = FALSE)`
#' - `module/path\[...\]` returns `list(imports = NULL, attach_all = TRUE)`
#'
#' @param expr_node XML node containing the module expression with brackets
#' @return List with imports and attach_all flag
#' @keywords internal
extract_selective_imports <- function(expr_node) {
  # Find all expr nodes between OP-LEFT-BRACKET and OP-RIGHT-BRACKET
  # These are the imported function names

  # Check for [...] syntax (attach all)
  # This is represented as SYMBOL[text()='...'] or similar
  dots <- xml2::xml_find_all(expr_node, ".//SYMBOL[text()='...']")
  if (length(dots) > 0) {
    return(list(imports = NULL, attach_all = TRUE))
  }

  # Find all SYMBOL nodes after OP-LEFT-BRACKET
  # These are the function names to import
  symbols <- xml2::xml_find_all(expr_node, ".//OP-LEFT-BRACKET/following-sibling::expr/SYMBOL")

  if (length(symbols) == 0) {
    return(list(imports = NULL, attach_all = FALSE))
  }

  # Get the function names
  imports <- vapply(symbols, xml2::xml_text, character(1))

  list(imports = imports, attach_all = FALSE)
}

# Phase 21.2: Module Path Resolution ==========================================

#' Get box.path search paths configuration
#'
#' Resolution order:
#' 1. Check if options(box.path) is already set
#' 2. Parse .Rprofile in project root for options(box.path = ...)
#' 3. Check BOX_PATH environment variable
#' 4. Default to current working directory
#'
#' @param project_root Root directory of the project
#' @return Character vector of search paths
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # .Rprofile contains: options(box.path = c("R/modules", "shared"))
#' get_box_search_paths("/path/to/project")  # c("/path/to/project/R/modules", "/path/to/project/shared", "/path/to/project")
#' }
get_box_search_paths <- function(project_root = getwd()) {
  # 1. Check if already set in current session
  existing_path <- getOption("box.path")
  if (!is.null(existing_path)) {
    # Resolve relative paths against project root
    return(normalize_box_paths(existing_path, project_root))
  }

  # 2. Try to parse from .Rprofile
  rprofile_path <- file.path(project_root, ".Rprofile")
  if (file.exists(rprofile_path)) {
    rprofile_paths <- parse_box_path_from_rprofile(rprofile_path)
    if (length(rprofile_paths) > 0) {
      return(normalize_box_paths(rprofile_paths, project_root))
    }
  }

  # 3. Check environment variable
  env_path <- Sys.getenv("BOX_PATH", unset = "")
  if (nzchar(env_path)) {
    paths <- strsplit(env_path, .Platform$path.sep)[[1]]
    return(normalize_box_paths(paths, project_root))
  }

  # 4. Default to project root
  normalizePath(project_root, mustWork = FALSE)
}

#' Parse box.path from .Rprofile file
#'
#' Looks for options(box.path = ...) calls in .Rprofile and extracts the paths.
#'
#' @param rprofile_path Path to .Rprofile file
#' @return Character vector of paths, or empty vector if not found
#' @keywords internal
parse_box_path_from_rprofile <- function(rprofile_path) {
  if (!file.exists(rprofile_path)) {
    return(character(0))
  }

  # Read file content
  content <- readLines(rprofile_path, warn = FALSE)

  # Look for options(box.path = ...) pattern
  # This is a simple heuristic - doesn't handle complex R expressions
  for (line in content) {
    # Skip comments
    if (grepl("^\\s*#", line)) next

    # Look for options(...box.path = ...)
    if (grepl("options\\s*\\(.*box\\.path\\s*=", line)) {
      # Try to extract the value
      # Pattern: box.path = c("path1", "path2") or box.path = "path"
      match <- regexpr("box\\.path\\s*=\\s*c?\\s*\\(([^)]+)\\)", line, perl = TRUE)
      if (match > 0) {
        capture_start <- attr(match, "capture.start")
        capture_length <- attr(match, "capture.length")
        if (length(capture_start) > 0 && capture_start > 0) {
          paths_str <- substr(line, capture_start, capture_start + capture_length - 1)
          # Extract quoted strings
          paths <- extract_quoted_strings(paths_str)
          if (length(paths) > 0) {
            return(paths)
          }
        }
      }

      # Fallback: try simpler pattern box.path = "single_path"
      match2 <- regexpr("box\\.path\\s*=\\s*['\"]([^'\"]+)['\"]", line, perl = TRUE)
      if (match2 > 0) {
        capture_start <- attr(match2, "capture.start")
        capture_length <- attr(match2, "capture.length")
        if (length(capture_start) > 0 && capture_start > 0) {
          path <- substr(line, capture_start, capture_start + capture_length - 1)
          return(path)
        }
      }
    }
  }

  character(0)
}

#' Extract quoted strings from a character string
#'
#' @param text Text containing quoted strings
#' @return Character vector of extracted strings
#' @keywords internal
extract_quoted_strings <- function(text) {
  # Find all "..." or '...' patterns
  matches <- gregexpr("['\"]([^'\"]+)['\"]", text, perl = TRUE)
  if (length(matches[[1]]) == 0 || matches[[1]][1] == -1) {
    return(character(0))
  }

  # Extract the strings (without quotes)
  starts <- attr(matches[[1]], "capture.start")
  lengths <- attr(matches[[1]], "capture.length")

  vapply(seq_along(starts), function(i) {
    substr(text, starts[i], starts[i] + lengths[i] - 1)
  }, character(1))
}

#' Normalize box.path entries to absolute paths
#'
#' @param paths Character vector of paths (may be relative)
#' @param project_root Project root directory
#' @return Character vector of absolute paths
#' @keywords internal
normalize_box_paths <- function(paths, project_root) {
  vapply(paths, function(p) {
    if (grepl("^[/~]", p)) {
      # Already absolute or home-relative
      normalizePath(p, mustWork = FALSE)
    } else {
      # Relative to project root
      normalizePath(file.path(project_root, p), mustWork = FALSE)
    }
  }, character(1), USE.NAMES = FALSE)
}

#' Resolve module path to file on disk
#'
#' Converts box module paths to actual .r/.R file paths.
#' Handles:
#' - Absolute module paths: mod/math → <search_path>/mod/math.r
#' - Relative paths: ./utils → <current_file_dir>/utils.r
#' - Parent paths: ../shared/helpers → <current_file_dir>/../shared/helpers.r
#'
#' @param module_path Module path as written in box::use() (e.g., "mod/math", "./utils")
#' @param current_file Path to file containing the box::use() call (for relative path resolution)
#' @param search_paths Character vector of box.path search directories
#' @return Absolute path to .r/.R file, or NULL if not found
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Absolute module path
#' resolve_module_path("mod/math", "/proj/script.r", c("/proj/R/modules"))
#' # Returns: "/proj/R/modules/mod/math.r"
#'
#' # Relative path
#' resolve_module_path("./utils", "/proj/analysis/script.r", c("/proj"))
#' # Returns: "/proj/analysis/utils.r"
#' }
resolve_module_path <- function(module_path, current_file, search_paths = get_box_search_paths()) {
  # Handle relative paths
  if (grepl("^\\./", module_path) || grepl("^\\.\\./ ", module_path)) {
    # Relative to current file's directory
    current_dir <- dirname(current_file)
    # Remove leading ./
    relative_part <- sub("^\\./", "", module_path)
    # Build path
    candidates <- c(
      file.path(current_dir, paste0(relative_part, ".r")),
      file.path(current_dir, paste0(relative_part, ".R"))
    )

    for (candidate in candidates) {
      if (file.exists(candidate)) {
        return(normalizePath(candidate))
      }
    }

    return(NULL)
  }

  # Absolute module path - search in box.path directories
  # Add current file's directory as a fallback search path
  all_search_paths <- c(search_paths, dirname(current_file))

  for (search_dir in all_search_paths) {
    candidates <- c(
      file.path(search_dir, paste0(module_path, ".r")),
      file.path(search_dir, paste0(module_path, ".R"))
    )

    for (candidate in candidates) {
      if (file.exists(candidate)) {
        return(normalizePath(candidate))
      }
    }
  }

  # Not found
  NULL
}

# Phase 21.3: Module Type Extraction ==========================================

# Cache for module types: module_file_path -> list(mtime, types)
.box_module_cache <- new.env(parent = emptyenv())

#' Get cached module types with mtime-based invalidation
#'
#' Caches module type information keyed by file path + modification time.
#' Automatically re-parses if file has been modified.
#'
#' @param module_file Absolute path to module .r/.R file
#' @return Named list of function types (same format as inst/types.rds)
#' @keywords internal
get_cached_module_types <- function(module_file) {
  if (!file.exists(module_file)) {
    return(list())
  }

  cache_key <- normalizePath(module_file)
  current_mtime <- file.mtime(module_file)

  # Check cache
  if (exists(cache_key, envir = .box_module_cache)) {
    cached <- get(cache_key, envir = .box_module_cache)
    if (identical(cached$mtime, current_mtime)) {
      return(cached$types)  # Cache hit
    }
  }

  # Cache miss or stale - re-parse
  types <- extract_module_types(module_file)

  # Store in cache
  assign(cache_key, list(mtime = current_mtime, types = types),
         envir = .box_module_cache)

  types
}

#' Extract type annotations from a box module file
#'
#' Reads a .r/.R file and extracts all type annotations from functions
#' marked with #' @export. Returns type information in the same format
#' as inst/types.rds for consistency with package type loading.
#'
#' @param module_file Path to module .r/.R file
#' @return Named list: function_name -> list(params = list(...), return = "type")
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Module file:
#' # #' @typedParam x {numeric} value
#' # #' @typedReturn {numeric} result
#' # #' @export
#' # double <- function(x) x * 2
#'
#' types <- extract_module_types("math.r")
#' # Returns: list(double = list(params = list(x = "numeric"), return = "numeric"))
#' }
extract_module_types <- function(module_file) {
  if (!file.exists(module_file)) {
    return(list())
  }

  # Read file content
  content <- tryCatch(
    readLines(module_file, warn = FALSE),
    error = function(e) {
      return(character(0))
    }
  )

  if (length(content) == 0) {
    return(list())
  }

  # Parse the file to get function definitions
  parsed <- tryCatch(
    parse(module_file, keep.source = TRUE),
    error = function(e) {
      return(NULL)
    }
  )

  if (is.null(parsed) || length(parsed) == 0) {
    return(list())
  }

  # Extract types from comments
  # Use the same extraction logic as linter-extract.R
  all_types <- list()

  # Accumulate comment lines for each function
  current_comments <- character(0)
  current_function <- NULL

  for (i in seq_along(content)) {
    line <- content[i]

    # Check if this is a roxygen comment
    if (grepl("^\\s*#'", line)) {
      current_comments <- c(current_comments, line)
    } else if (grepl("<-\\s*function\\s*\\(", line)) {
      # Function definition found
      # Extract function name
      func_match <- regexec("^\\s*([a-zA-Z_][a-zA-Z0-9_.]*)?\\s*<-\\s*function", line)
      if (func_match[[1]][1] > 0) {
        func_name_start <- func_match[[1]][2]
        func_name_length <- attr(func_match[[1]], "match.length")[2]
        func_name <- substr(line, func_name_start, func_name_start + func_name_length - 1)

        if (nzchar(func_name)) {
          # Check if function is exported (has @export in comments)
          is_exported <- any(grepl("@export\\b", current_comments))

          if (is_exported && length(current_comments) > 0) {
            # Extract types from accumulated comments
            # Keep the full structure: list(type = "...", description = "...")
            # This matches what the linter expects
            types <- extract_types_from_comment_lines(current_comments)

            if (length(types$params) > 0 || !is.null(types$return)) {
              all_types[[func_name]] <- types
            }
          }
        }
      }

      # Reset comment accumulator
      current_comments <- character(0)
    } else if (!grepl("^\\s*$", line) && !grepl("^\\s*#[^']", line)) {
      # Non-comment, non-blank line that's not a function def
      # Reset comment accumulator
      current_comments <- character(0)
    }
  }

  all_types
}

#' Filter function types to only include exported functions
#'
#' Checks which functions have #' @export directive in their documentation.
#' This is used to determine which functions are accessible from the module.
#'
#' @param module_file Path to module .r/.R file
#' @param all_types Named list of all function types
#' @return Named list of only exported function types
#' @keywords internal
filter_exported_functions <- function(module_file, all_types) {
  # This is already handled in extract_module_types()
  # which only extracts types for @export functions
  all_types
}

# Phase 21.4: Linter Integration ==============================================

#' Load type information from box modules
#'
#' Detects box::use() calls in the file and loads type information
#' from the imported modules. Handles full imports, selective imports,
#' and module aliases.
#'
#' @param xml XML AST of the file
#' @param current_file Path to the file being linted
#' @return Named list of function types from all imported modules
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # File contains: box::use(mod/math)
#' types <- load_box_module_types(xml, "/proj/script.r")
#' # Returns: list(math$add = list(params = ..., return = ...), ...)
#' }
load_box_module_types <- function(xml, current_file) {
  if (is.null(xml)) {
    return(list())
  }

  # Extract all box::use() imports
  imports <- extract_box_imports(xml)

  if (length(imports) == 0) {
    return(list())
  }

  all_module_types <- list()

  # Process each import
  for (import_info in imports) {
    # Resolve module path to file
    module_file <- resolve_module_path(import_info$module_path, current_file)

    if (is.null(module_file)) {
      # Module not found - skip silently (could add lint warning in future)
      next
    }

    # Load types from module file (with caching)
    module_types <- get_cached_module_types(module_file)

    if (length(module_types) == 0) {
      next
    }

    # Determine the prefix for accessing module functions
    # 3 cases:
    # 1. Aliased import: box::use(m = mod/math) → m$add
    # 2. Full module import: box::use(mod/math) → math$add
    # 3. Selective import: box::use(mod/math[add]) → add (no prefix)

    if (!is.null(import_info$imports) || import_info$attach_all) {
      # Selective import or attach-all: functions accessible without prefix
      if (import_info$attach_all) {
        # [...] syntax: all functions accessible directly
        for (func_name in names(module_types)) {
          all_module_types[[func_name]] <- module_types[[func_name]]
        }
      } else {
        # [func1, func2] syntax: only specified functions accessible
        for (func_name in import_info$imports) {
          if (func_name %in% names(module_types)) {
            all_module_types[[func_name]] <- module_types[[func_name]]
          }
        }
      }
    } else {
      # Full module import: functions accessible via module_name$func or alias$func
      prefix <- if (!is.null(import_info$alias)) {
        import_info$alias
      } else {
        import_info$module_name
      }

      # Add types with prefix
      for (func_name in names(module_types)) {
        prefixed_name <- paste0(prefix, "$", func_name)
        all_module_types[[prefixed_name]] <- module_types[[func_name]]
      }
    }
  }

  all_module_types
}
