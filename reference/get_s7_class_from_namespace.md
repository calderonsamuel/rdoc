# Get S7 class object from type name

Dynamically retrieves from S7 namespace to ensure we get the same object
instances that tests and other code use.

## Usage

``` r
get_s7_class_from_namespace(type_name)
```

## Arguments

- type_name:

  Full S7 class name (e.g., "class_integer")

## Value

S7 class object or NULL
