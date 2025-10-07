# Tests for R/linter-inference.R
# Unit tests for type inference functions

test_that("infer_argument_type detects string", {
  skip_if_not_installed("xml2")

  code <- "'test'"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  str_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(str_node)

  expect_equal(result, "class_character")
})

test_that("infer_argument_type detects numeric", {
  skip_if_not_installed("xml2")

  code <- "123"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  num_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(num_node)

  expect_equal(result, "class_numeric")
})

test_that("infer_argument_type detects integer literals (with L suffix)", {
  skip_if_not_installed("xml2")

  code <- "30L"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  int_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(int_node)

  expect_equal(result, "class_integer")
})

test_that("infer_argument_type detects logical", {
  skip_if_not_installed("xml2")

  code <- "TRUE"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  log_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(log_node)

  expect_equal(result, "class_logical")
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
  call_node <- xml2::xml_find_first(xml, "//SYMBOL_FUNCTION_CALL/parent::expr/parent::expr")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_null(args[[1]]$name)
  expect_equal(args[[1]]$type, "class_numeric")
  expect_null(args[[2]]$name)
  expect_equal(args[[2]]$type, "class_character")
})

test_that("extract_arguments handles named arguments", {
  skip_if_not_installed("xml2")

  code <- "foo(x = 123, y = 'test')"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  call_node <- xml2::xml_find_first(xml, "//SYMBOL_FUNCTION_CALL/parent::expr/parent::expr")

  args <- extract_arguments(call_node)

  expect_equal(length(args), 2)
  expect_equal(args[[1]]$name, "x")
  expect_equal(args[[1]]$type, "class_numeric")
  expect_equal(args[[2]]$name, "y")
  expect_equal(args[[2]]$type, "class_character")
})

test_that("types_compatible accepts matching types", {
  expect_true(types_compatible("class_numeric", "class_numeric"))
  expect_true(types_compatible("class_character", "class_character"))
  expect_true(types_compatible("class_logical", "class_logical"))
})

test_that("types_compatible rejects mismatching types", {
  expect_false(types_compatible("class_numeric", "class_character"))
  expect_false(types_compatible("class_character", "class_logical"))
})

test_that("types_compatible handles union types", {
  # Subtype → Union (widening, safe)
  expect_true(types_compatible("class_character", "NULL | class_character"))
  expect_true(types_compatible("NULL", "NULL | class_character"))

  # Union → different type (invalid)
  expect_false(types_compatible("NULL | class_character", "class_numeric"))

  # Union → Subtype (narrowing, unsafe - would be FALSE)
  expect_false(types_compatible("NULL | class_character", "class_character"))
})

test_that("types_compatible handles numeric coercion", {
  # class_numeric[1] should be compatible with class_numeric
  expect_true(types_compatible("class_numeric", "class_numeric[1]"))
  expect_true(types_compatible("class_numeric[1]", "class_numeric"))
})

test_that("infer_argument_type detects c() with character", {
  skip_if_not_installed("xml2")

  code <- "c('a', 'b', 'c')"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_character")
})

test_that("infer_argument_type detects c() with numeric", {
  skip_if_not_installed("xml2")

  code <- "c(1, 2, 3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_numeric")
})

test_that("infer_argument_type detects list()", {
  skip_if_not_installed("xml2")

  code <- "list(1, 2, 3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_list")
})

test_that("infer_argument_type detects data.frame()", {
  skip_if_not_installed("xml2")

  code <- "data.frame(x = 1:3)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_data.frame")
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

test_that("infer_argument_type detects comparison operators as logical", {
  skip_if_not_installed("xml2")

  operators <- c("x > y", "x >= y", "x < y", "x <= y", "x == y", "x != y")

  for (code in operators) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, "//expr")

    result <- infer_argument_type(expr_node)

    expect_equal(result, "class_logical", info = paste("Failed for:", code))
  }
})

test_that("infer_argument_type detects logical operators as logical", {
  skip_if_not_installed("xml2")

  operators <- c("x & y", "x | y", "!x")

  for (code in operators) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, "//expr")

    result <- infer_argument_type(expr_node)

    expect_equal(result, "class_logical", info = paste("Failed for:", code))
  }
})
