# Bracket Syntax Demo
# Shows the new bracket notation for type constraints

# Example 1: Length constraints with [n]
#' Set configuration value
#' @typedParam key {class_character[1]} configuration key (must be scalar)
#' @typedParam value {class_numeric[1]} configuration value (must be scalar)
#' @typedReturn {class_logical[1]} TRUE if successful
set_config <- function(key, value) {
  # Implementation
  TRUE
}

# Valid calls:
set_config("timeout", 30)      # ✓ Both scalar
set_config("retries", 5)       # ✓ Both scalar

# Invalid calls (would be caught by linter):
# set_config(c("a", "b"), 30)  # ✗ key is length 2, not 1
# set_config("timeout", c(1,2)) # ✗ value is length 2, not 1


# Example 2: Element type constraints with <T>
#' Process items
#' @typedParam items {class_list<class_integer>} list of integers only
#' @typedReturn {class_numeric[1]} sum of all items
sum_items <- function(items) {
  sum(unlist(items))
}

# Valid calls:
sum_items(list(1L, 2L, 3L))    # ✓ List of integers

# Invalid calls (would be caught by linter if element checking was enabled):
# sum_items(list("a", "b"))     # ✗ List of characters (currently allowed - placeholder)


# Example 3: Combined constraints <T>[n]
#' Calculate 3D distance
#' @typedParam point1 {class_list<class_numeric[1]>[3]} 3D coordinate (x,y,z)
#' @typedParam point2 {class_list<class_numeric[1]>[3]} 3D coordinate (x,y,z)
#' @typedReturn {class_numeric[1]} Euclidean distance
distance_3d <- function(point1, point2) {
  sqrt(sum((unlist(point1) - unlist(point2))^2))
}

# Valid calls (when length inference is available):
distance_3d(list(0, 0, 0), list(1, 1, 1))  # ✓ Both lists of 3 scalars

# Note: Length validation for list() calls requires deeper static analysis
# Currently, length checking is most effective for scalar literals


# Example 4: Backward compatibility with (n) syntax
#' Old-style scalar notation
#' @typedParam x {class_numeric(1)} still works!
#' @typedReturn {class_numeric(1)} returns scalar
legacy_function <- function(x) {
  x * 2
}

legacy_function(5)  # ✓ Still works


# Summary:
# - [n]  = length constraint (scalar = [1])
# - <T>  = element type constraint
# - <T>[n] = combined (list of T with length n)
# - (n)  = legacy syntax (still supported)
