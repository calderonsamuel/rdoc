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
  log_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(log_node)

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

test_that("extract_arguments handles positional arguments", {
  skip_if_not_installed("xml2")

  code <- "foo(123, 'test')"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  call_node <- xml2::xml_find_first(xml, "//expr[SYMBOL_FUNCTION_CALL]")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_null(args[[1]]$name)
  expect_equal(args[[1]]$type, "numeric")
  expect_null(args[[2]]$name)
  expect_equal(args[[2]]$type, "character")
})

test_that("extract_arguments handles named arguments", {
  skip_if_not_installed("xml2")

  code <- "foo(x = 123, y = 'test')"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  call_node <- xml2::xml_find_first(xml, "//expr[SYMBOL_FUNCTION_CALL]")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_equal(args[[1]]$name, "x")
  expect_equal(args[[1]]$type, "numeric")
  expect_equal(args[[2]]$name, "y")
  expect_equal(args[[2]]$type, "character")
})

test_that("linter flags type mismatch - literal argument", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number input
    calculate_mean <- function(x) mean(x)

    calculate_mean('test')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes with correct type - literal argument", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number input
    calculate_mean <- function(x) mean(x)

    calculate_mean(123)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_equal(length(lints), 0)
})

test_that("linter handles multiple arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} first number
    #' @typedParam y {numeric} second number
    add <- function(x, y) x + y

    add(1, 'text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect mismatch on second argument
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter handles named arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    #' @typedParam text {character} text
    process <- function(x, text) paste(text, x)

    process(x = 'wrong', text = 123)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect both mismatches
  expect_equal(length(lints), 2)
})

test_that("linter handles mixed positional and named arguments", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    #' @typedParam y {numeric} another number
    #' @typedParam z {character} text
    process <- function(x, y, z) paste(z, x + y)

    process(1, z = 'ok', y = 'wrong')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect mismatch on y (named argument with wrong type)
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("types_compatible accepts matching types", {
  expect_true(types_compatible("numeric", "numeric"))
  expect_true(types_compatible("character", "character"))
  expect_true(types_compatible("logical", "logical"))
})

test_that("types_compatible rejects mismatching types", {
  expect_false(types_compatible("numeric", "character"))
  expect_false(types_compatible("character", "logical"))
})

test_that("types_compatible handles union types", {
  expect_true(types_compatible("character | NULL", "character"))
  expect_true(types_compatible("character | NULL", "NULL"))
  expect_false(types_compatible("character | NULL", "numeric"))
})

test_that("types_compatible handles numeric coercion", {
  # numeric(1) should be compatible with numeric
  expect_true(types_compatible("numeric", "numeric(1)"))
  expect_true(types_compatible("numeric(1)", "numeric"))
})

test_that("linter reports correct line numbers", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x

    # Line 5
    foo('wrong')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_equal(length(lints), 1)
  # Lint should be on line 6 (where foo('wrong') is)
  expect_equal(lints[[1]]$line_number, 6)
})

test_that("linter handles functions with no type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    # No type annotations
    calculate <- function(x) x * 2

    calculate('text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not produce lints if function has no type annotations
  expect_equal(length(lints), 0)
})

test_that("linter handles multiple lints in single call", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    #' @typedParam y {numeric} another number
    #' @typedParam z {numeric} third number
    add_three <- function(x, y, z) x + y + z

    add_three('a', 'b', 'c')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect all three mismatches
  expect_equal(length(lints), 3)
})

test_that("linter extracts types from accumulated comments", {
  skip_if_not_installed("lintr")

  # Simulate lintr's multi-pass execution
  code <- "
    #' Function with types
    #' @typedParam x {numeric} a number
    calculate <- function(x) x * 2

    calculate('wrong')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Linter should accumulate comments and find type info
  expect_equal(length(lints), 1)
})

# Phase 5: Variable Type Inference ----

test_that("infer_argument_type detects c() with character", {
  skip_if_not_installed("xml2")

  code <- "c('a', 'b', 'c')"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "character")
})

test_that("infer_argument_type detects c() with numeric", {
  skip_if_not_installed("xml2")

  code <- "c(1, 2, 3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "numeric")
})

test_that("infer_argument_type detects list()", {
  skip_if_not_installed("xml2")

  code <- "list(1, 2, 3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "list")
})

test_that("infer_argument_type detects data.frame()", {
  skip_if_not_installed("xml2")

  code <- "data.frame(x = 1:3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "data.frame")
})

test_that("infer_argument_type detects matrix()", {
  skip_if_not_installed("xml2")

  code <- "matrix(1:9, 3, 3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "matrix")
})

test_that("extract_variable_assignments finds simple assignments", {
  skip_if_not_installed("xml2")

  code <- "
    x <- 123
    y <- 'text'
  "
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))

  vars <- extract_variable_assignments(xml)

  expect_equal(length(vars), 2)
  expect_true("x" %in% names(vars))
  expect_true("y" %in% names(vars))
})

test_that("linter infers type from character vector variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- c('1', '2', '3')
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is character
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from numeric vector variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {character} text
    foo <- function(x) paste(x)

    a <- c(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects character but a is numeric
  expect_equal(length(lints), 1)
  expect_true(any(grepl("character.*numeric", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from logical variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- TRUE
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is logical
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*logical", vapply(lints, function(l) l$message, character(1)))))
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

  # Should detect: foo expects numeric but a is character
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from NULL variable", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- NULL
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is NULL
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*NULL", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from list() constructor", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- list(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is list
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*list", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from empty list() constructor", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- list()
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is list
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*list", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from data.frame() constructor", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- data.frame(x = 1:3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is data.frame
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*data\\.frame", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter infers type from matrix() constructor", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- matrix(1:9, 3, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should detect: foo expects numeric but a is matrix
  expect_equal(length(lints), 1)
  expect_true(any(grepl("numeric.*matrix", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes when variable type matches from c()", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number
    foo <- function(x) x * 2

    a <- c(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - numeric vector to numeric parameter
  expect_equal(length(lints), 0)
})

test_that("linter passes when list type matches", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {list} a list
    foo <- function(x) x

    a <- list(1, 2, 3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - list to list parameter
  expect_equal(length(lints), 0)
})

test_that("linter passes when data.frame type matches", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {data.frame} a data frame
    foo <- function(x) x

    a <- data.frame(x = 1:3)
    foo(a)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - data.frame to data.frame parameter
  expect_equal(length(lints), 0)
})

test_that("linter passes when matrix type matches", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {matrix} a matrix
    foo <- function(x) x

    a <- matrix(1:9, 3, 3)
    foo(a)
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

# Phase 7.2: Return Value Validation ----

test_that("linter validates explicit return statement matches @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} should return number
    get_value <- function() {
      return('text')
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared numeric but returns character
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter validates implicit return (last expression) matches @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {character} should return text
    get_value <- function() {
      42
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared character but returns numeric
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*character.*numeric", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter passes when return type matches declaration", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} returns number
    get_number <- function() {
      return(42)
    }

    #' @typedReturn {character} returns text
    get_text <- function() {
      'hello'
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass - both functions return correct types
  expect_equal(length(lints), 0)
})

test_that("linter skips validation for complex function bodies", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} complex logic
    calculate <- function(x) {
      if (x > 0) {
        return(x * 2)
      } else {
        return('error')
      }
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should skip validation - too complex (multiple return paths)
  # Function still usable with inferred return type
  expect_equal(length(lints), 0)
})

test_that("linter validates return from constructor calls", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} should return number
    get_data <- function() {
      return(list(1, 2, 3))
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared numeric but returns list
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*numeric.*list", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter handles functions without @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    # No @typedReturn annotation
    get_value <- function() {
      return('text')
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should not error - no declared return type to validate
  expect_equal(length(lints), 0)
})

test_that("linter validates return from comparison operators", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {logical} is adult
    is_adult <- function(age) {
      age >= 18
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass: comparison operator returns logical
  expect_equal(length(lints), 0)
})

test_that("linter catches wrong type with comparison operators", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {numeric} wrong type
    is_valid <- function(x) {
      x > 0
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should warn: declared numeric but returns logical
  expect_equal(length(lints), 1)
  expect_true(any(grepl("Return.*numeric.*logical", vapply(lints, function(l) l$message, character(1)))))
})

test_that("linter validates return from logical operators", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedReturn {logical} combined check
    check_both <- function(x, y) {
      (x > 0) & (y < 10)
    }
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Should pass: logical operators return logical
  expect_equal(length(lints), 0)
})

test_that("infer_argument_type detects comparison operators as logical", {
  skip_if_not_installed("xml2")

  operators <- c("x > y", "x >= y", "x < y", "x <= y", "x == y", "x != y")

  for (code in operators) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, "//expr")

    result <- infer_argument_type(expr_node)

    expect_equal(result, "logical", info = paste("Failed for:", code))
  }
})

test_that("infer_argument_type detects logical operators as logical", {
  skip_if_not_installed("xml2")

  operators <- c("x & y", "x | y", "!x")

  for (code in operators) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, "//expr")

    result <- infer_argument_type(expr_node)

    expect_equal(result, "logical", info = paste("Failed for:", code))
  }
})

# Phase 9: Strict Mode ----

test_that("type_consistency_linter accepts strict parameter", {
  linter <- type_consistency_linter(strict = TRUE)
  expect_s3_class(linter, "linter")

  linter_false <- type_consistency_linter(strict = FALSE)
  expect_s3_class(linter_false, "linter")
})

test_that("strict mode flags function with missing @typedParam", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    #' @param y Another number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag both parameters missing type annotations
  expect_gte(length(lints), 2)
  expect_true(any(grepl("missing type annotation.*strict mode", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode flags function with missing @typedReturn", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @typedParam x {numeric} First number
    #' @typedParam y {numeric} Second number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag missing return type annotation
  expect_gte(length(lints), 1)
  expect_true(any(grepl("missing return type annotation.*strict mode", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode passes with complete type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @typedParam x {numeric} First number
    #' @typedParam y {numeric} Second number
    #' @typedReturn {numeric} The sum
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should pass - all parameters and return have type annotations
  expect_equal(length(lints), 0)
})

test_that("lenient mode allows missing type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    #' @param y Another number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = FALSE))

  # Should not flag missing annotations in lenient mode
  expect_equal(length(lints), 0)
})

test_that("default mode is lenient", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate sum
    #' @param x A number
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  # Default should be lenient - no lints for missing annotations
  expect_equal(length(lints), 0)
})

test_that("strict mode flags partial type annotations", {
  skip_if_not_installed("lintr")

  code <- "
    #' Process data
    #' @typedParam x {numeric} A number
    #' @param y Another parameter (missing type)
    process <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag parameter y and missing return type
  expect_gte(length(lints), 2)
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("missing type annotation", messages, ignore.case = TRUE)))
})

test_that("strict mode warns on unknown variable types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} A number
    #' @typedReturn {numeric} Result
    process <- function(x) x * 2

    # result type is unknown (no @typedReturn on foo)
    foo <- function() 42
    result <- foo()
    process(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should warn about unknown type from foo() in strict mode
  expect_gte(length(lints), 1)
  expect_true(any(grepl("cannot verify type|unknown type", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("lenient mode skips unknown variable types", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} A number
    process <- function(x) x * 2

    # result type is unknown
    foo <- function() 42
    result <- foo()
    process(result)
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = FALSE))

  # Lenient mode should skip unknown types - no error
  expect_equal(length(lints), 0)
})

test_that("strict mode flags functions without roxygen comments", {
  skip_if_not_installed("lintr")

  code <- "
    # Regular comment, not roxygen
    calculate <- function(x, y) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag missing type annotations
  expect_gte(length(lints), 1)
  expect_true(any(grepl("missing.*annotation", vapply(lints, function(l) l$message, character(1)), ignore.case = TRUE)))
})

test_that("strict mode handles functions with default parameters", {
  skip_if_not_installed("lintr")

  code <- "
    #' Calculate with defaults
    #' @param x A number
    #' @param y Another number with default
    calculate <- function(x, y = 10) x + y
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag both parameters regardless of defaults
  expect_gte(length(lints), 2)
})

test_that("strict mode handles functions with ... parameter", {
  skip_if_not_installed("lintr")

  code <- "
    #' Process with ellipsis
    #' @param x A number
    #' @param ... Additional arguments
    process <- function(x, ...) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag x and return type, but maybe allow ... without type
  # (... is tricky to type - implementation decision)
  expect_gte(length(lints), 1)
})

test_that("strict mode only checks exported functions for return types", {
  skip_if_not_installed("lintr")

  # This test documents expected behavior - may need adjustment
  # based on implementation: should internal functions require @typedReturn?
  code <- "
    #' Internal helper
    #' @keywords internal
    #' @typedParam x {numeric} A number
    .internal_helper <- function(x) x * 2
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Decision: Should internal functions require @typedReturn in strict mode?
  # For now, let's require it for all functions
  expect_gte(length(lints), 1)
})

test_that("strict mode provides helpful error messages", {
  skip_if_not_installed("lintr")

  code <- "
    #' Test function
    #' @param x A number
    test <- function(x) x
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Check that messages are informative
  expect_gte(length(lints), 1)
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_true(any(grepl("strict mode", messages, ignore.case = TRUE)))
  expect_true(any(grepl("@typed", messages)))
})

test_that("strict mode handles multiple functions in one file", {
  skip_if_not_installed("lintr")

  code <- "
    #' Complete function
    #' @typedParam x {numeric} A number
    #' @typedReturn {numeric} Result
    good <- function(x) x * 2

    #' Incomplete function
    #' @param y A number
    bad <- function(y) y + 1
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should only flag the incomplete function
  expect_gte(length(lints), 2)
  # All lints should reference 'bad' or 'y', not 'good' or 'x'
  messages <- vapply(lints, function(l) l$message, character(1))
  expect_false(any(grepl("\\bgood\\b", messages)))
  expect_false(any(grepl("\\bx\\b.*missing", messages)))
})

test_that("strict mode combined with type checking still works", {
  skip_if_not_installed("lintr")

  code <- "
    #' Process number
    #' @typedParam x {numeric} A number
    #' @typedReturn {numeric} Result
    process <- function(x) x * 2

    # This call has wrong type AND missing annotations
    process('text')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter(strict = TRUE))

  # Should flag the type mismatch
  expect_gte(length(lints), 1)
  expect_true(any(grepl("numeric.*character", vapply(lints, function(l) l$message, character(1)))))
})
