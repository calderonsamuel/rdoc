test_that("type_consistency_linter can be created", {
  linter <- type_consistency_linter()

  expect_s3_class(linter, "linter")
})

test_that("parse_typed_param_text parses correctly", {
  result <- parse_typed_param_text("x {numeric} input value")

  expect_equal(result$param, "x")
  expect_equal(result$type, "numeric")
  expect_equal(result$description, "input value")
})

test_that("parse_typed_return_text parses correctly", {
  result <- parse_typed_return_text("{numeric} output value")

  expect_equal(result$type, "numeric")
  expect_equal(result$description, "output value")
})

test_that("infer_argument_type detects string", {
  skip_if_not_installed("xml2")

  code <- "'test'"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  str_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(str_node)

  expect_equal(result, "character")
})

test_that("infer_argument_type detects numeric", {
  skip_if_not_installed("xml2")

  code <- "123"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  num_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(num_node)

  expect_equal(result, "numeric")
})

test_that("infer_argument_type detects logical", {
  skip_if_not_installed("xml2")

  code <- "TRUE"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  bool_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(bool_node)

  expect_equal(result, "logical")
})

test_that("infer_argument_type detects NULL", {
  skip_if_not_installed("xml2")

  code <- "NULL"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  null_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(null_node)

  expect_equal(result, "NULL")
})

test_that("types_compatible handles exact matches", {
  expect_true(types_compatible("numeric", "numeric"))
  expect_true(types_compatible("character", "character"))
  expect_false(types_compatible("numeric", "character"))
})

test_that("types_compatible handles union types", {
  expect_true(types_compatible("NULL", "character | NULL"))
  expect_true(types_compatible("character", "character | NULL"))
  expect_false(types_compatible("numeric", "character | NULL"))
})

test_that("types_compatible handles numeric compatibility", {
  expect_true(types_compatible("integer", "numeric"))
  expect_true(types_compatible("numeric", "numeric"))
  expect_true(types_compatible("double", "numeric"))
})

test_that("types_compatible ignores length constraints", {
  expect_true(types_compatible("numeric", "numeric(1)"))
  expect_true(types_compatible("character", "character(n)"))
})

test_that("linter catches type mismatch with literals", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} input
    foo <- function(x) x * 2

    foo('not a number')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should have at least one lint
  expect_true(length(lints) > 0)

  # Check the lint message
  lint_messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("numeric.*character", lint_messages)))
})

test_that("linter passes correct types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} input
    foo <- function(x) x * 2

    foo(123)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter handles union types", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric | NULL} input
    foo <- function(x) x

    foo(NULL)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_length(lints, 0)
})

test_that("linter handles multiple parameters", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} first
    #' @typedParam y {character} second
    foo <- function(x, y) paste(x, y)

    foo('wrong', 123)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should catch the first argument mismatch
  expect_true(length(lints) > 0)
})

test_that("linter infers types from simple variable assignments", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} input
    foo <- function(x) x * 2

    y <- 'string'
    foo(y)  # Can infer type of variable from assignment
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should catch the type error since y is inferred as character
  expect_length(lints, 1)
  expect_true(grepl("numeric.*character", lints[[1]]$message))
})

test_that("find_loaded_packages detects library calls", {
  skip_if_not_installed("xml2")

  code <- "
    library(dplyr)
    require(ggplot2)
  "

  parsed <- parse(text = code, keep.source = TRUE)
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parsed))

  source_expr <- list(xml_parsed_content = xml)
  packages <- find_loaded_packages(source_expr)

  expect_true("dplyr" %in% packages)
  expect_true("ggplot2" %in% packages)
})

test_that("linter handles no type annotations gracefully", {
  skip_if_not_installed("lintr")

  code <- "
    # Regular function without types
    foo <- function(x) x * 2

    foo('string')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not lint if no type annotations
  expect_length(lints, 0)
})

test_that("linter handles named arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} first
    #' @typedParam y {logical} second
    foo <- function(x, y) x

    foo(x = 'wrong', y = 'also wrong')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should catch both named arguments
  expect_equal(length(lints), 2)

  # Check messages mention the correct parameters
  lint_messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("Argument 'x'.*numeric.*character", lint_messages)))
  expect_true(any(grepl("Argument 'y'.*logical.*character", lint_messages)))
})

test_that("linter handles mixed positional and named arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @typedParam x {numeric} first
    #' @typedParam y {logical} second
    foo <- function(x, y) x

    foo('wrong', y = 'also wrong')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should catch both arguments (one positional, one named)
  expect_equal(length(lints), 2)

  # Check messages
  lint_messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("Argument 'x'", lint_messages)))
  expect_true(any(grepl("Argument 'y'", lint_messages)))
})

test_that("linter reports all type errors in single call", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate mean
    #' @typedParam x {numeric} vector
    #' @typedParam na_rm {logical(1)} remove NAs
    calculate_mean <- function(x, na_rm = FALSE) mean(x, na.rm = na_rm)

    calculate_mean('a', na_rm = 'FALSE')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should report both errors
  expect_equal(length(lints), 2)

  lint_messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("Argument 'x'.*numeric.*character", lint_messages)))
  expect_true(any(grepl("Argument 'na_rm'.*logical.*character", lint_messages)))
})

test_that("extract_arguments handles named arguments", {
  skip_if_not_installed("xml2")

  code <- "foo(x = 'a', y = 123)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  call_node <- xml2::xml_find_first(xml, "//expr[.//SYMBOL_FUNCTION_CALL]")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_equal(args[[1]]$name, "x")
  expect_equal(args[[1]]$type, "character")
  expect_equal(args[[2]]$name, "y")
  expect_equal(args[[2]]$type, "numeric")
})

test_that("extract_arguments handles positional arguments", {
  skip_if_not_installed("xml2")

  code <- "foo('a', 123)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  call_node <- xml2::xml_find_first(xml, "//expr[.//SYMBOL_FUNCTION_CALL]")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_true(is.na(args[[1]]$name))
  expect_equal(args[[1]]$type, "character")
  expect_true(is.na(args[[2]]$name))
  expect_equal(args[[2]]$type, "numeric")
})

test_that("extract_arguments handles mixed arguments", {
  skip_if_not_installed("xml2")

  code <- "foo('a', y = 123)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  call_node <- xml2::xml_find_first(xml, "//expr[.//SYMBOL_FUNCTION_CALL]")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_true(is.na(args[[1]]$name))
  expect_equal(args[[1]]$type, "character")
  expect_equal(args[[2]]$name, "y")
  expect_equal(args[[2]]$type, "numeric")
})

# Variable type inference tests (not yet implemented)

test_that("linter infers type from character vector variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} vector of values
    #' @typedReturn {numeric(1)} the mean value
    calculate_mean <- function(x) mean(x)

    a <- c('1', '2', '3')
    calculate_mean(x = a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is character vector
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Argument 'x'.*numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from numeric vector variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- c(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is numeric
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*numeric", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from logical variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- TRUE
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is logical
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*logical", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from string variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- 'text'
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is character
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter handles variable reassignment", {
  skip("Variable type inference not yet implemented")
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- 123
    a <- 'text'
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should use the most recent assignment (character)
  expect_equal(length(lints), 0)
})

test_that("linter infers type from NULL assignment", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- NULL
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is NULL
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*NULL", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from list() call", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- list(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is list
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*list", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from empty list()", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x

    a <- list()
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is list
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*list", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes when list matches list parameter", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {list} a list
    foo <- function(x) length(x)

    a <- list(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - list to list parameter
  expect_equal(length(lints), 0)
})

test_that("linter infers type from data.frame() call", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- data.frame(x = 1:3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is data.frame
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*data.frame", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes when data.frame matches data.frame parameter", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam df {data.frame} a data frame
    process <- function(df) nrow(df)

    my_df <- data.frame(x = 1:3, y = 4:6)
    process(my_df)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - data.frame to data.frame parameter
  expect_equal(length(lints), 0)
})

test_that("linter infers type from matrix() call", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) x

    a <- matrix(1:9, 3, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is matrix
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*matrix", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes when matrix matches matrix parameter", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam m {matrix} a matrix
    foo <- function(m) nrow(m)

    my_matrix <- matrix(1:12, nrow = 3)
    foo(my_matrix)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - matrix to matrix parameter
  expect_equal(length(lints), 0)
})

test_that("linter passes when variable type matches", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- 123
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - numeric variable to numeric parameter
  expect_equal(length(lints), 0)
})

test_that("linter handles variables from outer scope", {
  skip("Variable type inference not yet implemented")
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- 'text'

    bar <- function() {
      foo(a)  # 'a' from outer scope
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect that 'a' is character from outer scope
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

# Phase 7: Function Return Type Inference ----

test_that("linter infers types from function return values - simple case", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} a number
    get_number <- function() 42

    #' @typedParam x {character} text
    process_text <- function(x) paste(x)

    result <- get_number()
    process_text(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: process_text expects character but result is numeric
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*numeric", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers types from function return values - matching types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} a number
    get_number <- function() 42

    #' @typedParam x {numeric} number
    process_number <- function(x) x * 2

    result <- get_number()
    process_number(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - numeric return to numeric parameter
  expect_equal(length(lints), 0)
})

test_that("linter handles function calls without @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    # No @typedReturn annotation
    get_value <- function() 42

    #' @typedParam x {character} text
    process_text <- function(x) paste(x)

    result <- get_value()
    process_text(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not error - result type is unknown, so no warning
  expect_equal(length(lints), 0)
})

test_that("linter infers types from chained function calls", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {data.frame} a data frame
    load_data <- function() data.frame(x = 1:3)

    #' @typedParam df {data.frame} input data
    #' @typedReturn {list} processed results
    process_data <- function(df) list(df)

    #' @typedParam x {list} input list
    show_results <- function(x) print(x)

    df <- load_data()
    results <- process_data(df)
    show_results(results)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # All types should match in the chain
  expect_equal(length(lints), 0)
})

test_that("linter infers types from function calls with scalar returns", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric(1)} scalar number
    get_scalar <- function() 42

    #' @typedParam x {numeric} vector
    process_vector <- function(x) sum(x)

    result <- get_scalar()
    process_vector(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - numeric(1) is compatible with numeric
  expect_equal(length(lints), 0)
})

test_that("linter handles inline function calls as arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} a number
    get_number <- function() 42

    #' @typedParam x {character} text
    process_text <- function(x) paste(x)

    process_text(get_number())
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: expects character but get_number() returns numeric
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*numeric", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers types from functions returning list, data.frame, matrix", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {list} a list
    get_list <- function() list(1, 2)

    #' @typedReturn {data.frame} a data frame
    get_df <- function() data.frame(x = 1:3)

    #' @typedReturn {matrix} a matrix
    get_matrix <- function() matrix(1:9, 3, 3)

    #' @typedParam x {list} list input
    use_list <- function(x) x

    #' @typedParam x {data.frame} df input
    use_df <- function(x) x

    #' @typedParam x {matrix} matrix input
    use_matrix <- function(x) x

    a <- get_list()
    b <- get_df()
    c <- get_matrix()

    use_list(a)
    use_df(b)
    use_matrix(c)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # All should match correctly
  expect_equal(length(lints), 0)
})

test_that("linter catches type mismatch with complex return types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {data.frame} a data frame
    get_df <- function() data.frame(x = 1:3)

    #' @typedParam x {list} list input
    use_list <- function(x) x

    result <- get_df()
    use_list(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: expects list but get_df() returns data.frame
  expect_equal(length(lints), 1)
  expect_true(any(grepl("list.*data\\.frame", vapply(lints, function(l) l$message, character(1)))))
})
