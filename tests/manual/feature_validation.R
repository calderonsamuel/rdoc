# rdoc Feature Validation Script
#
# PURPOSE: Manual validation of all rdoc features in VSCode
# INSTRUCTIONS:
#   1. Open this file in VSCode with languageserver + lintr configured
#   2. Ensure .lintr has: type_consistency_linter(mode = "strict")
#   3. Look for squiggly lines under function calls marked with # ❌
#   4. Verify NO squiggly lines under calls marked with # ✅
#   5. Hover over errors to see lint messages

# =============================================================================
# FEATURE 1: Basic Type Checking (Literals)
# =============================================================================

#' Add two numbers
#' @typedParam x {class_numeric} first number
#' @typedParam y {class_numeric} second number
#' @typedReturn {class_numeric} sum
add_numbers <- function(x, y) {
  x + y
}

# ✅ PASS: Correct types
add_numbers(1, 2)
add_numbers(3.14, 2.71)

# ❌ FAIL: Wrong types
add_numbers("text", 2)      # Expects class_numeric, got class_character
add_numbers(1, TRUE)        # Expects class_numeric, got class_logical
add_numbers(NULL, 2)        # Expects class_numeric, got NULL

# =============================================================================
# FEATURE 2: Length Constraints [n]
# =============================================================================

#' Get first element
#' @typedParam x {class_character[1]} single string
#' @typedReturn {class_character[1]} the string
get_first <- function(x) {
  x
}

# ✅ PASS: Scalar string
get_first("hello")

# ❌ FAIL: Not length-1 (rdoc doesn't check runtime length yet, but syntax works)
# Note: Length validation is syntax-level only for now
get_first(c("a", "b"))  # May not error (runtime length checking not implemented)

# =============================================================================
# FEATURE 3: Element Type Constraints <T>
# =============================================================================

#' Process list of numbers
#' @typedParam items {class_list<class_numeric>} list of numbers
#' @typedReturn {class_numeric} sum of all numbers
sum_list <- function(items) {
  sum(unlist(items))
}

# ✅ PASS: List of numbers
sum_list(list(1, 2, 3))

# ❌ FAIL: Not a list
sum_list(c(1, 2, 3))        # Expects class_list, got class_numeric

# Note: Element type validation (<class_numeric>) is syntax-level only
# rdoc validates container type (list) but not element types yet

# =============================================================================
# FEATURE 4: Union Types |
# =============================================================================

#' Accept number or string
#' @typedParam value {class_numeric | class_character} input value
#' @typedReturn {class_character} string representation
to_string <- function(value) {
  as.character(value)
}

# ✅ PASS: Either type in union
to_string(42)
to_string("hello")

# ❌ FAIL: Not in union
to_string(TRUE)            # Expects class_numeric | class_character, got class_logical
to_string(list(1, 2))      # Expects class_numeric | class_character, got class_list

# =============================================================================
# FEATURE 5: NULL Safety (NULL | Type)
# =============================================================================

#' Optional parameter
#' @typedParam name {NULL | class_character[1]} optional name
#' @typedReturn {class_character} greeting
greet <- function(name) {
  if (is.null(name)) "Hello!" else paste("Hello", name)
}

# ✅ PASS: NULL or character
greet(NULL)
greet("Alice")

# ❌ FAIL: Wrong type
greet(123)                 # Expects NULL | class_character, got class_numeric
greet(TRUE)                # Expects NULL | class_character, got class_logical

# =============================================================================
# FEATURE 6: Variable Type Inference
# =============================================================================

#' Needs numeric input
#' @typedParam x {class_numeric} number
#' @typedReturn {class_numeric} result
double_it <- function(x) {
  x * 2
}

# ✅ PASS: Inferred from literal assignment
my_num <- 42
double_it(my_num)          # Infers my_num is class_numeric

# ✅ PASS: Inferred from c()
my_vec <- c(1, 2, 3)
double_it(my_vec)          # Infers my_vec is class_numeric

# ❌ FAIL: Inferred from wrong type
my_str <- "text"
double_it(my_str)          # Infers my_str is class_character, expects class_numeric

# ✅ PASS: Inferred from list()
my_list <- list(1, 2)
# (Need a function that expects list to test)

# =============================================================================
# FEATURE 7: Function Return Type Inference
# =============================================================================

#' Get a number
#' @typedReturn {class_numeric[1]} a number
get_number <- function() {
  42
}

#' Needs character input
#' @typedParam x {class_character} text
#' @typedReturn {class_character} uppercased
upper <- function(x) {
  toupper(x)
}

# ✅ PASS: Infers from @typedReturn
result <- get_number()
# double_it(result)        # Should pass (result is class_numeric from @typedReturn)

# ❌ FAIL: Infers from @typedReturn
num_result <- get_number()
upper(num_result)          # get_number returns class_numeric, upper expects class_character

# =============================================================================
# FEATURE 8: Return Value Validation
# =============================================================================

#' Should return numeric
#' @typedReturn {class_numeric} result
#' @keywords internal
bad_return <- function() {
  "text"                   # ❌ Implementation returns character, declared numeric
}

#' Should return character
#' @typedReturn {class_character} result
#' @keywords internal
good_return <- function() {
  "text"                   # ✅ Matches declaration
}

#' Comparison returns logical
#' @typedReturn {class_logical} result
#' @keywords internal
is_big <- function(x) {
  x > 10                   # ✅ Correctly returns logical
}

# =============================================================================
# FEATURE 9: Named and Positional Arguments
# =============================================================================

#' Function with multiple params
#' @typedParam x {class_numeric} first
#' @typedParam y {class_character} second
#' @typedParam z {class_logical} third
#' @typedReturn {class_character} result
multi_param <- function(x, y, z) {
  paste(x, y, z)
}

# ✅ PASS: Positional arguments
multi_param(1, "hello", TRUE)

# ✅ PASS: Named arguments
multi_param(x = 1, y = "hello", z = TRUE)
multi_param(y = "hello", z = TRUE, x = 1)  # Out of order

# ❌ FAIL: Wrong positional types
multi_param("text", 1, TRUE)     # x is character, expects numeric

# ❌ FAIL: Wrong named types
multi_param(x = "text", y = 1, z = TRUE)  # x is character, y is numeric

# =============================================================================
# FEATURE 10: External Types (package::class)
# =============================================================================

# Note: This requires roxygen2 package to be installed

#' Returns a roclet
#' @typedReturn {roxygen2::roclet} a roclet object
#' @keywords internal
make_roclet <- function() {
  roxygen2::roclet("test")
}

#' Expects a roclet
#' @typedParam x {roxygen2::roclet} roclet input
#' @typedReturn {class_character} description
#' @keywords internal
describe_roclet <- function(x) {
  class(x)[1]
}

# ✅ PASS: External type from function return
# my_roclet <- make_roclet()
# describe_roclet(my_roclet)

# ❌ FAIL: Wrong external type
# describe_roclet("not a roclet")

# =============================================================================
# FEATURE 11: All S7 Base Types
# =============================================================================

#' Test atomic types
#' @typedParam lgl {class_logical} logical
#' @typedParam int {class_integer} integer
#' @typedParam dbl {class_double} double
#' @typedParam cplx {class_complex} complex
#' @typedParam chr {class_character} character
#' @typedParam raw {class_raw} raw bytes
#' @typedReturn {class_list} combined
test_atomics <- function(lgl, int, dbl, cplx, chr, raw) {
  list(lgl, int, dbl, cplx, chr, raw)
}

# ✅ PASS: All correct types
test_atomics(
  lgl = TRUE,
  int = 1L,
  dbl = 3.14,
  cplx = 1+2i,
  chr = "text",
  raw = raw(10)
)

#' Test base classes
#' @typedParam fn {class_function} a function
#' @typedParam env {class_environment} an environment
#' @typedReturn {class_list} combined
test_base <- function(fn, env) {
  list(fn, env)
}

# ✅ PASS: Function and environment
test_base(fn = sum, env = new.env())

#' Test S3 wrappers
#' @typedParam df {class_data.frame} data frame
#' @typedParam dt {class_Date} date
#' @typedParam fct {class_factor} factor
#' @typedReturn {class_list} combined
test_s3_wrappers <- function(df, dt, fct) {
  list(df, dt, fct)
}

# ✅ PASS: S3 wrapped types
test_s3_wrappers(
  df = data.frame(x = 1:3),
  dt = Sys.Date(),
  fct = factor(c("a", "b"))
)

# ❌ FAIL: Wrong S3 types
test_s3_wrappers(
  df = list(x = 1:3),      # Expects class_data.frame, got class_list
  dt = "2024-01-01",       # Expects class_Date, got class_character
  fct = c("a", "b")        # Expects class_factor, got class_character
)

# =============================================================================
# FEATURE 12: Union of S7 Types (Numeric = Integer | Double)
# =============================================================================

#' Accept any numeric
#' @typedParam x {class_numeric} integer or double
#' @typedReturn {class_numeric} result
add_one <- function(x) {
  x + 1
}

# ✅ PASS: Both integer and double work (class_numeric is union)
add_one(1L)    # class_integer (subset of class_numeric)
add_one(3.14)  # class_double (subset of class_numeric)

# =============================================================================
# FEATURE 13: Three-Level Mode System
# =============================================================================

# To test modes, update .lintr config:
#
# MODE: lenient (default)
#   linters: with_defaults(type_consistency_linter = rdoc::type_consistency_linter())
#   - Only checks typed functions
#   - Allows untyped functions
#
# MODE: exported
#   linters: with_defaults(type_consistency_linter = rdoc::type_consistency_linter(mode = "exported"))
#   - Requires types on @export functions
#   - Allows untyped internal functions
#
# MODE: strict
#   linters: with_defaults(type_consistency_linter = rdoc::type_consistency_linter(mode = "strict"))
#   - Requires types on ALL functions
#   - Warns on unknown types in arguments

# Untyped function (different behavior per mode)
#' @export
untyped_exported <- function(x) {
  x + 1
}

# Lenient: ✅ No error
# Exported: ❌ Error (missing types on @export function)
# Strict: ❌ Error (missing types)

#' @keywords internal
untyped_internal <- function(x) {
  x + 1
}

# Lenient: ✅ No error
# Exported: ✅ No error (internal function)
# Strict: ❌ Error (missing types)

# =============================================================================
# FEATURE 14: Comparison and Logical Operators Return Logical
# =============================================================================

#' Expects logical
#' @typedParam condition {class_logical} true or false
#' @typedReturn {class_character} result
if_true <- function(condition) {
  if (condition) "yes" else "no"
}

# ✅ PASS: Comparison operators inferred as logical
x <- 5
if_true(x > 3)
if_true(x >= 5)
if_true(x < 10)
if_true(x <= 5)
if_true(x == 5)
if_true(x != 0)

# ✅ PASS: Logical operators inferred as logical
if_true(TRUE & FALSE)
if_true(TRUE | FALSE)
if_true(!FALSE)

# =============================================================================
# FEATURE 15: Constructor Inference
# =============================================================================

#' Needs specific types
#' @typedParam num {class_numeric} number vector
#' @typedParam lst {class_list} list
#' @typedParam df {class_data.frame} data frame
#' @typedParam mat {class_matrix} matrix
#' @typedReturn {class_list} combined
test_constructors <- function(num, lst, df, mat) {
  list(num, lst, df, mat)
}

# ✅ PASS: Inferred from constructors
v <- c(1, 2, 3)           # Inferred as class_numeric
l <- list(1, 2)           # Inferred as class_list
d <- data.frame(x = 1:3)  # Inferred as class_data.frame
m <- matrix(1:4, 2, 2)    # Inferred as class_matrix

test_constructors(v, l, d, m)

# ❌ FAIL: Wrong constructor
wrong_vec <- c("a", "b")
test_constructors(
  num = wrong_vec,        # Inferred as class_character, expects class_numeric
  lst = l,
  df = d,
  mat = m
)

# =============================================================================
# FEATURE 16: Context-Aware Union Error Messages (Phase 26)
# =============================================================================

#' Needs specific double (not union)
#' @typedParam x {class_double} double value
#' @typedReturn {class_double} result
needs_double <- function(x) {
  x * 2
}

#' Returns numeric union
#' @typedReturn {class_numeric[1]} integer or double
get_numeric <- function() {
  42
}

# ❌ FAIL: Scenario 1 - Partial compatibility (needs type narrowing)
# Error should say: "Cannot narrow union to 'class_double' without type guard"
result_numeric <- get_numeric()
needs_double(result_numeric)  # class_numeric[1] → class_double (some compatible, some not)

#' Needs character (completely different from numeric)
#' @typedParam x {class_character} text
#' @typedReturn {class_character} uppercased
needs_char <- function(x) {
  toupper(x)
}

# ❌ FAIL: Scenario 2 - Total incompatibility (no explanation needed)
# Error should be brief: just "expects... but got..." (no explanation about narrowing)
result_numeric2 <- get_numeric()
needs_char(result_numeric2)   # class_numeric[1] → class_character (no members compatible)

# Large union example - class_atomic (6 members)
#' Returns atomic value
#' @typedReturn {class_atomic[1]} any atomic value
get_atomic <- function() {
  42
}

# ❌ FAIL: Partial compatibility with large union
# Should still say "Cannot narrow..." without listing all 6 types
result_atomic <- get_atomic()
needs_double(result_atomic)   # class_atomic[1] → class_double

# ❌ FAIL: Total incompatibility with large union
# Should be brief (no explanation)
result_atomic2 <- get_atomic()
needs_char(result_atomic2)    # class_atomic[1] → class_character

# =============================================================================
# FEATURE 17: Error Position Accuracy
# =============================================================================

# Test that errors point to the right locations:
#
# For missing parameter types:
#   - Should underline the PARAMETER name (not function name)
#
# For missing return types:
#   - Should underline the FUNCTION name (not FUNCTION keyword)
#
# For type mismatches:
#   - Should underline the ARGUMENT (the problematic expression)

# rdoc: strict

#' Missing types - check positioning
#' @export
untyped_func <- function(missing_param) {
  # ❌ Should underline 'missing_param' (not 'untyped_func')
  # ❌ Should underline 'untyped_func' (not 'function' keyword)
  missing_param + 1
}

#' Multiple params - check each position
#' @export
multi_untyped <- function(a, b, c) {
  # ❌ Each parameter should be underlined at its own position
  a + b + c
}

# =============================================================================
# FEATURE 18: Complex Type Syntax Edge Cases
# =============================================================================

#' Nested generics
#' @typedParam data {class_list<class_list<class_numeric>>} nested lists
#' @typedReturn {class_numeric} sum
sum_nested <- function(data) {
  sum(unlist(data))
}

# ✅ PASS: Nested list structure (container type checked)
nested_data <- list(list(1, 2), list(3, 4))
sum_nested(nested_data)

# ❌ FAIL: Wrong outer container
sum_nested(c(1, 2, 3))  # Expects class_list, got class_numeric

#' Combined constraints
#' @typedParam items {class_list<class_numeric[1]>[3]} exactly 3 scalar numbers
#' @typedReturn {class_numeric} sum
sum_three <- function(items) {
  sum(unlist(items))
}

# ✅ PASS: Correct structure (container checked)
three_items <- list(1, 2, 3)
sum_three(three_items)

# ❌ FAIL: Wrong container type
sum_three(c(1, 2, 3))  # Expects class_list, got class_numeric

#' Union with length constraints
#' @typedParam value {class_integer[1] | class_double[1]} scalar number
#' @typedReturn {class_numeric} result
process_scalar <- function(value) {
  value * 2
}

# ✅ PASS: Both union members work
process_scalar(1L)     # class_integer[1]
process_scalar(3.14)   # class_double[1]

# ❌ FAIL: Wrong type entirely
process_scalar("text") # Expects class_integer | class_double, got class_character

#' NULL in complex union
#' @typedParam data {NULL | class_list<class_numeric> | class_data.frame} optional data
#' @typedReturn {class_numeric} result
process_data <- function(data) {
  if (is.null(data)) 0 else sum(unlist(data))
}

# ✅ PASS: NULL accepted
process_data(NULL)

# ✅ PASS: List accepted
process_data(list(1, 2, 3))

# ❌ FAIL: Wrong type
process_data("invalid")  # Expects NULL | class_list | class_data.frame, got class_character

# =============================================================================
# FEATURE 19: Type Inference Edge Cases
# =============================================================================

#' Needs numeric
#' @typedParam x {class_numeric} number
#' @typedReturn {class_numeric} result
needs_numeric <- function(x) {
  x * 2
}

# Variable shadowing (most recent assignment wins)
shadowed <- 123       # Inferred as class_numeric
needs_numeric(shadowed)  # ✅ PASS
shadowed <- "text"    # Now inferred as class_character
needs_numeric(shadowed)  # ❌ FAIL (new type)

# Empty constructors
empty_list <- list()
# Should infer as class_list (not unknown)

empty_vec <- c()
# May infer as class_logical (R's default for empty c())

# Complex expressions (inference may be limited)
computed <- if (TRUE) 42 else "text"
# rdoc may not infer type from if/else (complex control flow)

# Function calls without @typedReturn
#' No return type declared
#' @keywords internal
untyped_function <- function() {
  42
}

unknown_result <- untyped_function()
# May be inferred as 'unknown' type

# =============================================================================
# FEATURE 20: Operator Inference Comprehensive
# =============================================================================

#' Needs logical
#' @typedParam condition {class_logical} boolean
#' @typedReturn {class_character} result
check_condition <- function(condition) {
  if (condition) "yes" else "no"
}

a <- 5
b <- 10

# ✅ PASS: All comparison operators return logical
check_condition(a > b)
check_condition(a >= b)
check_condition(a < b)
check_condition(a <= b)
check_condition(a == b)
check_condition(a != b)

# ✅ PASS: All logical operators return logical
check_condition(TRUE & FALSE)
check_condition(TRUE | FALSE)
check_condition(!FALSE)
check_condition(TRUE && FALSE)  # Short-circuit AND
check_condition(TRUE || FALSE)  # Short-circuit OR

# ❌ FAIL: Arithmetic operators return numeric (not logical)
check_condition(a + b)    # Expects class_logical, got class_numeric
check_condition(a - b)    # Expects class_logical, got class_numeric
check_condition(a * b)    # Expects class_logical, got class_numeric

# =============================================================================
# FEATURE 21: Box Module Support (if using box package)
# =============================================================================

# Note: Requires box package installation
# Uncomment if testing box integration:

# box::use(./some_module)
#
# #' Use module function
# #' @typedParam x {class_numeric} input
# #' @typedReturn {class_numeric} output
# use_module <- function(x) {
#   some_module$typed_function(x)
# }

# =============================================================================
# FEATURE 22: Stress Tests & Corner Cases
# =============================================================================

#' Many parameters
#' @typedParam p1 {class_numeric} param 1
#' @typedParam p2 {class_numeric} param 2
#' @typedParam p3 {class_numeric} param 3
#' @typedParam p4 {class_numeric} param 4
#' @typedParam p5 {class_numeric} param 5
#' @typedParam p6 {class_numeric} param 6
#' @typedParam p7 {class_numeric} param 7
#' @typedParam p8 {class_numeric} param 8
#' @typedReturn {class_numeric} sum
many_params <- function(p1, p2, p3, p4, p5, p6, p7, p8) {
  p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8
}

# ✅ PASS: All correct types
many_params(1, 2, 3, 4, 5, 6, 7, 8)

# ❌ FAIL: Wrong type in middle
many_params(1, 2, 3, "wrong", 5, 6, 7, 8)  # p4 is character

# ❌ FAIL: Multiple wrong types
many_params(1, "two", 3, "four", 5, TRUE, 7, 8)  # Multiple errors

#' Long type union (8 types)
#' @typedParam value {class_logical | class_integer | class_double | class_complex | class_character | class_raw | class_expression | class_list} any value
#' @typedReturn {class_character} description
describe_value <- function(value) {
  class(value)[1]
}

# ✅ PASS: All union members work
describe_value(TRUE)
describe_value(1L)
describe_value(3.14)
describe_value(1+2i)
describe_value("text")
describe_value(raw(10))
describe_value(list(1))

# ❌ FAIL: Type not in union
describe_value(new.env())  # class_environment not in union

#' Default parameter values
#' @typedParam x {class_numeric} number
#' @typedParam multiplier {class_numeric} multiplier (default 2)
#' @typedReturn {class_numeric} result
with_default <- function(x, multiplier = 2) {
  x * multiplier
}

# ✅ PASS: Using default
with_default(5)

# ✅ PASS: Overriding default
with_default(5, 3)

# ❌ FAIL: Wrong type for default param
with_default(5, "wrong")  # multiplier is character

#' Ellipsis parameter (...)
#' @typedParam x {class_numeric} first number
#' @typedParam ... additional arguments
#' @typedReturn {class_list} all arguments
collect_args <- function(x, ...) {
  list(x, ...)
}

# ✅ PASS: Ellipsis not type-checked (by design)
collect_args(1, "text", TRUE, list())

# ❌ FAIL: First param wrong type
collect_args("wrong", 1, 2, 3)  # x is character

# =============================================================================
# FEATURE 23: Anonymous and Nested Functions
# =============================================================================

# Anonymous function
lapply_test <- lapply(1:3, function(x) x * 2)
# Should not require type annotations on anonymous function (exported mode)

# Nested function definition
#' Outer function
#' @typedParam x {class_numeric} input
#' @typedReturn {class_function} a function
#' @export
make_adder <- function(x) {
  function(y) x + y  # Inner function - should not require types in exported mode
}

# ✅ PASS: Nested function creation
add_five <- make_adder(5)

# =============================================================================
# FEATURE 24: Return Value Validation Edge Cases
# =============================================================================

#' Simple literal return
#' @typedReturn {class_numeric} number
#' @keywords internal
return_literal <- function() {
  42  # ✅ Implicit return of literal
}

#' Explicit return statement
#' @typedReturn {class_numeric} number
#' @keywords internal
return_explicit <- function() {
  return(42)  # ✅ Explicit return
}

#' Constructor return
#' @typedReturn {class_list} list
#' @keywords internal
return_constructor <- function() {
  list(1, 2, 3)  # ✅ Implicit return of constructor
}

#' Wrong literal return
#' @typedReturn {class_numeric} number
#' @keywords internal
return_wrong_literal <- function() {
  "text"  # ❌ Returns character, declared numeric
}

#' Wrong constructor return
#' @typedReturn {class_numeric} number
#' @keywords internal
return_wrong_constructor <- function() {
  list(1, 2)  # ❌ Returns list, declared numeric
}

# Multiple returns (validation skipped - too complex)
#' Multiple return paths (not validated)
#' @typedReturn {class_numeric} number
#' @keywords internal
multiple_returns <- function(x) {
  if (x > 0) {
    return(42)  # numeric
  } else {
    return("text")  # character - won't be caught (control flow too complex)
  }
}

# =============================================================================
# VALIDATION CHECKLIST
# =============================================================================
#
# Open this file in VSCode and verify:
#
# [ ] Lines marked ✅ have NO red squiggles
# [ ] Lines marked ❌ have RED squiggles underneath the function call
# [ ] Hovering over ❌ lines shows helpful error message
# [ ] Error messages show:
#     - Expected type
#     - Actual type
#     - Parameter name
# [ ] All S7 base types work (class_integer, class_character, etc.)
# [ ] Union types work (| operator)
# [ ] NULL safety works (NULL | Type)
# [ ] External types work (roxygen2::roclet)
# [ ] Variable inference works (assignments tracked)
# [ ] Function return inference works (@typedReturn used)
# [ ] Named and positional arguments both work
# [ ] Comparison operators (>, <, ==) inferred as logical
# [ ] Logical operators (&, |, !) inferred as logical
# [ ] Context-aware union errors (Phase 26):
#     - Partial compatibility shows "Cannot narrow union..."
#     - Total incompatibility shows just basic error (no explanation)
# [ ] Error positioning (Phase 27):
#     - Missing param type underlines parameter name
#     - Missing return type underlines function name
#     - Type mismatch underlines argument expression
# [ ] Complex type syntax works:
#     - Nested generics: class_list<class_list<T>>
#     - Combined constraints: class_list<T>[n]
#     - Union with constraints: T[1] | U[1]
# [ ] Edge cases handled:
#     - Variable shadowing (most recent assignment)
#     - Empty constructors (list(), c())
#     - Default parameter values
#     - Ellipsis (...) parameters
#     - Anonymous and nested functions
#     - Multiple error detection (shows all errors)
#
# =============================================================================
# EXPECTED ERRORS (should see these in VSCode)
# =============================================================================
#
# BASIC TYPE CHECKING:
#
# Line ~28: add_numbers("text", 2)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#
# Line ~30: add_numbers(1, TRUE)
#   → Type mismatch for parameter 'y': expected class_numeric, got class_logical
#
# Line ~31: add_numbers(NULL, 2)
#   → Type mismatch for parameter 'x': expected class_numeric, got NULL
#
# Line ~62: sum_list(c(1, 2, 3))
#   → Type mismatch for parameter 'items': expected class_list, got class_numeric
#
# Line ~82: to_string(TRUE)
#   → Type mismatch for parameter 'value': expected class_numeric | class_character, got class_logical
#
# Line ~83: to_string(list(1, 2))
#   → Type mismatch for parameter 'value': expected class_numeric | class_character, got class_list
#
# Line ~102: greet(123)
#   → Type mismatch for parameter 'name': expected NULL | class_character, got class_numeric
#
# Line ~103: greet(TRUE)
#   → Type mismatch for parameter 'name': expected NULL | class_character, got class_logical
#
# Line ~125: double_it(my_str)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#
# Line ~149: upper(num_result)
#   → Type mismatch for parameter 'x': expected class_character, got class_numeric
#
# Line ~161: bad_return function body
#   → Return type mismatch: expected class_numeric, got class_character
#
# Line ~190: multi_param("text", 1, TRUE)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#
# Line ~193: multi_param(x = "text", y = 1, z = TRUE)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#   → Type mismatch for parameter 'y': expected class_character, got class_numeric
#
# Line ~266: test_s3_wrappers with wrong types
#   → Type mismatch for parameter 'df': expected class_data.frame, got class_list
#   → Type mismatch for parameter 'dt': expected class_Date, got class_character
#   → Type mismatch for parameter 'fct': expected class_factor, got class_character
#
# Line ~327: test_constructors with wrong_vec
#   → Type mismatch for parameter 'num': expected class_numeric, got class_character
#
# CONTEXT-AWARE UNION ERRORS (Phase 26):
#
# Line ~430: needs_double(result_numeric)  [PARTIAL COMPATIBILITY]
#   → Argument 'x' expects type 'class_double' but got 'class_integer[1] | class_double[1]'.
#      Cannot narrow union to 'class_double' without type guard
#
# Line ~442: needs_char(result_numeric2)  [TOTAL INCOMPATIBILITY]
#   → Argument 'x' expects type 'class_character' but got 'class_integer[1] | class_double[1]'
#   (NO extra explanation - mismatch is obvious)
#
# Line ~454: needs_double(result_atomic)  [LARGE UNION - PARTIAL]
#   → Should say "Cannot narrow union..." without listing all 6 members
#
# Line ~459: needs_char(result_atomic2)  [LARGE UNION - TOTAL]
#   → Should be brief (no explanation about union members)
#
# ERROR POSITIONING (Phase 27):
#
# Lines ~480-484: untyped_func function
#   → Parameter 'missing_param' error: underline should be at 'missing_param' (~col 40)
#   → Return type error: underline should be at 'untyped_func' (~col 1-12)
#
# Lines ~488-491: multi_untyped function
#   → Each parameter (a, b, c) should have underline at its own position
#
# COMPLEX TYPE SYNTAX:
#
# Line ~509: sum_nested(c(1, 2, 3))
#   → Type mismatch: expected class_list<class_list<class_numeric>>, got class_numeric
#
# Line ~523: sum_three(c(1, 2, 3))
#   → Type mismatch: expected class_list<class_numeric[1]>[3], got class_numeric
#
# Line ~537: process_scalar("text")
#   → Type mismatch: expected class_integer[1] | class_double[1], got class_character
#
# Line ~553: process_data("invalid")
#   → Type mismatch: expected NULL | class_list<class_numeric> | class_data.frame, got class_character
#
# INFERENCE EDGE CASES:
#
# Line ~570: needs_numeric(shadowed) [after reassignment]
#   → Type mismatch: expected class_numeric, got class_character
#   (Variable shadowing - new assignment changes inferred type)
#
# OPERATOR INFERENCE:
#
# Line ~623: check_condition(a + b)
#   → Type mismatch: expected class_logical, got class_numeric
#
# Lines ~624-625: Arithmetic operators
#   → Similar errors (arithmetic returns numeric, not logical)
#
# STRESS TESTS:
#
# Line ~665: many_params(1, 2, 3, "wrong", 5, 6, 7, 8)
#   → Type mismatch for parameter 'p4': expected class_numeric, got class_character
#
# Line ~668: many_params with multiple errors
#   → Should show MULTIPLE errors (p2, p4, p6 all wrong)
#
# Line ~687: describe_value(new.env())
#   → Type mismatch: expected class_logical | class_integer | ... (8 types), got class_environment
#
# Line ~704: with_default(5, "wrong")
#   → Type mismatch for parameter 'multiplier': expected class_numeric, got class_character
#
# Line ~718: collect_args("wrong", 1, 2, 3)
#   → Type mismatch for parameter 'x': expected class_numeric, got class_character
#   (Ellipsis params not checked)
#
# RETURN VALUE VALIDATION:
#
# Line ~768-770: return_wrong_literal function
#   → Return type mismatch: declared class_numeric, returns class_character
#
# Line ~775-777: return_wrong_constructor function
#   → Return type mismatch: declared class_numeric, returns class_list
#
# Line ~783-789: multiple_returns function
#   → NO ERROR (validation skipped for complex control flow)
#
# =============================================================================
