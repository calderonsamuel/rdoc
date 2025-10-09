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

  expect_equal(result, "class_double")
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
  expect_equal(args[[1]]$type, "class_double")
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
  expect_equal(args[[1]]$type, "class_double")
  expect_equal(args[[2]]$name, "y")
  expect_equal(args[[2]]$type, "class_character")
})

test_that("types_compatible accepts matching types", {
  expect_true(types_compatible("class_double", "class_double"))
  expect_true(types_compatible("class_character", "class_character"))
  expect_true(types_compatible("class_logical", "class_logical"))
})

test_that("types_compatible rejects mismatching types", {
  expect_false(types_compatible("class_double", "class_character"))
  expect_false(types_compatible("class_character", "class_logical"))
})

test_that("types_compatible handles union types", {
  # Subtype → Union (widening, safe)
  expect_true(types_compatible("class_character", "NULL | class_character"))
  expect_true(types_compatible("NULL", "NULL | class_character"))

  # Union → different type (invalid)
  expect_false(types_compatible("NULL | class_character", "class_double"))

  # Union → Subtype (narrowing, unsafe - would be FALSE)
  expect_false(types_compatible("NULL | class_character", "class_character"))
})

test_that("types_compatible handles numeric coercion", {
  # class_numeric[1] should be compatible with class_numeric
  expect_true(types_compatible("class_double", "class_numeric[1]"))
  expect_false(types_compatible("class_numeric[1]", "class_double"))
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

  expect_equal(result, "class_double")
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

test_that("infer_argument_type infers arithmetic operations correctly", {
  skip_if_not_installed("xml2")

  # Test 1: Literal + Literal (should infer from operand types)
  # double + double = double
  code <- "1.5 + 2.5"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_double", info = "double + double should be class_double")

  # integer + integer = integer
  code <- "1L + 2L"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_integer", info = "integer + integer should be class_integer")

  # integer + double = double (type promotion)
  code <- "1L + 2.5"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_double", info = "integer + double should be class_double")

  # Test 2: Variable + Variable (with context)
  # Build variable context: a is double, b is double
  var_context <- list(
    a = list(list(line = 1, type = "class_double")),
    b = list(list(line = 2, type = "class_double"))
  )

  code <- "a + b"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node, var_context = var_context, current_line = 3)
  expect_equal(result, "class_double", info = "double var + double var should be class_double")

  # a is integer, b is integer
  var_context <- list(
    a = list(list(line = 1, type = "class_integer")),
    b = list(list(line = 2, type = "class_integer"))
  )

  code <- "a + b"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node, var_context = var_context, current_line = 3)
  expect_equal(result, "class_integer", info = "integer var + integer var should be class_integer")

  # a is integer, b is double (mixed)
  var_context <- list(
    a = list(list(line = 1, type = "class_integer")),
    b = list(list(line = 2, type = "class_double"))
  )

  code <- "a + b"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node, var_context = var_context, current_line = 3)
  expect_equal(result, "class_double", info = "integer var + double var should be class_double")

  # Test 3: Unknown operands (fallback to class_numeric)
  code <- "x + y"  # No context provided
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_numeric", info = "unknown + unknown should fallback to class_numeric")

  # Test 4: All arithmetic operators
  operators <- list(
    list(code = "1.5 - 2.5", op = "OP-MINUS", expected = "class_double"),
    list(code = "1.5 * 2.5", op = "OP-STAR", expected = "class_double"),
    list(code = "1.5 / 2.5", op = "OP-SLASH", expected = "class_double"),
    list(code = "1.5 ^ 2.5", op = "OP-CARET", expected = "class_double"),
    list(code = "1L - 2L", op = "OP-MINUS", expected = "class_integer"),
    list(code = "1L * 2L", op = "OP-STAR", expected = "class_integer")
  )

  for (op_test in operators) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = op_test$code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, paste0("//expr[", op_test$op, "]"))
    result <- infer_argument_type(expr_node)
    expect_equal(result, op_test$expected, info = paste("Failed for:", op_test$code))
  }
})

test_that("infer_argument_type handles chained arithmetic operations", {
  skip_if_not_installed("xml2")

  # Test 1: Chained doubles (double + double + double + double)
  code <- "1.5 + 2.5 + 3.5 + 4.5"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_double", info = "chained double additions should be class_double")

  # Test 2: Chained integers (integer * integer * integer)
  code <- "2L * 3L * 4L"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-STAR]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_integer", info = "chained integer multiplications should be class_integer")

  # Test 3: Mixed chain that starts with integer but becomes double
  # 1L + 2L + 3.5 should be double (because one operand is double)
  code <- "1L + 2L + 3.5"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_double", info = "integer + integer + double should be class_double")

  # Test 4: Complex expression with parentheses
  code <- "(1L + 2L) * 3L"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-STAR]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_integer", info = "(integer + integer) * integer should be class_integer")

  # Test 5: Mixed operations
  code <- "1.5 * 2L + 3.5"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_double", info = "double * integer + double should be class_double")

  # Test 6: Chained variables with context
  var_context <- list(
    a = list(list(line = 1, type = "class_double")),
    b = list(list(line = 2, type = "class_double")),
    c = list(list(line = 3, type = "class_double")),
    d = list(list(line = 4, type = "class_double"))
  )

  code <- "a + b + c + d"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node, var_context = var_context, current_line = 5)
  expect_equal(result, "class_double", info = "chained double variables should be class_double")

  # Test 7: Mixed variable types
  var_context <- list(
    x = list(list(line = 1, type = "class_integer")),
    y = list(list(line = 2, type = "class_integer")),
    z = list(list(line = 3, type = "class_double"))
  )

  code <- "x + y + z"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node, var_context = var_context, current_line = 4)
  expect_equal(result, "class_double", info = "integer + integer + double variables should be class_double")

  # Test 8: Variables and literals mixed
  var_context <- list(
    a = list(list(line = 1, type = "class_integer"))
  )

  code <- "a + 2L + 3L"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-PLUS]")
  result <- infer_argument_type(expr_node, var_context = var_context, current_line = 2)
  expect_equal(result, "class_integer", info = "integer var + integer + integer should be class_integer")

  # Test 9: Division always returns double (even for integers)
  # Note: In R, 4L / 2L returns a double (2.0, not 2L)
  code <- "4L / 2L"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[OP-SLASH]")
  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_double", info = "division always returns class_double")

  # More division tests
  test_divs <- list(
    list(code = "10.0 / 2.0", expected = "class_double"),
    list(code = "10L / 3L", expected = "class_double"),
    list(code = "10.0 / 3L", expected = "class_double")
  )

  for (div_test in test_divs) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = div_test$code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, "//expr[OP-SLASH]")
    result <- infer_argument_type(expr_node)
    expect_equal(result, div_test$expected, info = paste("Failed for:", div_test$code))
  }

  # Test 10: Exponentiation also always returns double
  # Note: In R, 2L ^ 3L returns 8.0 (double), not 8L (integer)
  test_exps <- list(
    list(code = "2L ^ 3L", expected = "class_double"),
    list(code = "2.0 ^ 3.0", expected = "class_double"),
    list(code = "4L ^ 0.5", expected = "class_double"),
    list(code = "10L ^ 2L", expected = "class_double")
  )

  for (exp_test in test_exps) {
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = exp_test$code, keep.source = TRUE)))
    expr_node <- xml2::xml_find_first(xml, "//expr[OP-CARET]")
    result <- infer_argument_type(expr_node)
    expect_equal(result, exp_test$expected, info = paste("Failed for:", exp_test$code))
  }
})

test_that("infer_argument_type detects function literals", {
  skip_if_not_installed("xml2")

  # Test bare function literal
  code <- "function(x) { x + 1 }"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr[FUNCTION]")

  result <- infer_argument_type(expr_node)
  expect_equal(result, "class_function")

  # Test that function literals inside function calls are not detected
  # (the whole expression should return unknown, not class_function)
  code2 <- "lintr::Linter(function(x) { x + 1 })"
  xml2 <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code2, keep.source = TRUE)))
  expr_node2 <- xml2::xml_find_first(xml2, "//expr")

  result2 <- infer_argument_type(expr_node2)
  expect_equal(result2, "unknown")
})

test_that("infer_argument_type detects double literals", {
  skip_if_not_installed("xml2")

  code <- "3.14"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_double")
})

test_that("infer_argument_type detects complex literals", {
  skip_if_not_installed("xml2")

  # Test complex literal like 1+2i
  code <- "1+2i"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_complex")
})

test_that("infer_argument_type detects raw() constructor", {
  skip_if_not_installed("xml2")

  code <- "raw(10)"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_raw")
})

test_that("infer_argument_type detects new.env() constructor", {
  skip_if_not_installed("xml2")

  code <- "new.env()"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_environment")
})

test_that("infer_argument_type detects factor() constructor", {
  skip_if_not_installed("xml2")

  code <- "factor(c('a', 'b'))"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_factor")
})

test_that("infer_argument_type detects Sys.Date() constructor", {
  skip_if_not_installed("xml2")

  code <- "Sys.Date()"
  xml <- xml2::read_xml(xmlparsedata::xml_parse_data(parse(text = code, keep.source = TRUE)))
  expr_node <- xml2::xml_find_first(xml, "//expr")

  result <- infer_argument_type(expr_node)

  expect_equal(result, "class_Date")
})
