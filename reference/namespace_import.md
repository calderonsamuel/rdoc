# Namespace Import Information

Represents a namespace import from library(), require(), or box::use().
Unifies the concept of namespace imports across different R mechanisms.

## Usage

``` r
namespace_import(
  source_type = character(0),
  source_path = character(0),
  namespace_name = character(0),
  namespace_alias = character(0),
  selected_objects = character(0),
  attach_all = logical(0),
  import_mechanism = character(0),
  line = integer(0)
)
```

## Details

This class supports three import mechanisms:

- [`library(pkg)`](https://rdrr.io/r/base/library.html): Traditional
  package loading (attaches all exports)

- [`require(pkg)`](https://rdrr.io/r/base/library.html): Conditional
  package loading (attaches all exports)

- `box::use(...)`: Modern module/package imports (flexible attachment)

Import modes for box::use():

- Full module: `box::use(mod/math)` → qualified access via `math$func`

- Aliased: `box::use(m = mod/math)` → qualified access via `m$func`

- Selective: `box::use(mod/math[add])` → unqualified access to `add()`

- Attach all: `box::use(mod/math[...])` → unqualified access to all
  exports

## Fields

- `source_type`:

  Character: "package" or "module"

- `source_path`:

  Character: Package name or module path

- `namespace_name`:

  Character: Derived namespace name (last component of path)

- `namespace_alias`:

  Character or NULL: Optional alias for the namespace

- `selected_objects`:

  Character vector or NULL: Selectively imported objects (NULL = none
  selected)

- `attach_all`:

  Logical: Whether all exports are attached to namespace

- `import_mechanism`:

  Character: "library", "require", or "box"

- `line`:

  Integer: Source line number where import occurs
