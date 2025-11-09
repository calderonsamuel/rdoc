# S7 Classes for Type Metadata

These classes provide a type-safe representation of type annotations
extracted from @typedParam and @typedReturn tags. Using S7 classes
instead of plain lists prevents common errors like typos in field names
and ensures consistent structure across the codebase.

## Details

### Design Philosophy

rdoc uses S7 internally for all type metadata, practicing what it
preaches. S7 objects are used throughout:

- Internal type registry: S7 objects

- Serialization (inst/types.rds): S7 objects (serialize perfectly with
  saveRDS)

- Tests: Access S7 properties with `@` operator

This provides type safety and validation while maintaining clean
serialization.
