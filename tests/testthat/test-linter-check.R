# Tests for R/linter-check.R
# Integration tests that call lintr::lint() to validate type checking



test_that("linter flags type mismatch - literal argument", {
  skip_if_not_installed("lintr")

  code <- "
    #' @typedParam x {numeric} number input
    calculate_mean <- function(x) mean(x)

    calculate_mean('test')
  "

  lints <- lintr::lint(text = code, linters = type_consistency_linter())

  expect_equal(length(lints), 1)
  expect_true(any(grepl("class_numeric.*class_character", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_character", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_character", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_character", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_character.*class_numeric", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_logical", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_character", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*NULL", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_list", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_list", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*data.frame", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*matrix", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_numeric.*class_character", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_character.*class_numeric", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_character.*class_numeric", vapply(lints, function(l) l$message, character(1)))))
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
  expect_true(any(grepl("class_list.*data.frame", vapply(lints, function(l) l$message, character(1)))))
})
