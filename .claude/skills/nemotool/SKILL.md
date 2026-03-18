---
name: nemotool
description: Scaffold a new nemo Tool — R6 class, LinkML schema, and placeholder test data
---

# nemotool

## Instructions

Scaffold a new nemo Tool. Ask the user for:

1. **Tool name** (e.g. `mytool`) — used for the R6 class name (`MyTool`), the `name` arg in `super$initialize()`, the schema id/prefix, and the `inst/extdata/<name>/` and `inst/config/tools/<name>/` paths.
2. **Description** — one-line description of what the tool parses.
3. **Tables** — for each table, collect:
   - Table name (e.g. `table1`)
   - File type: `tsv`, `txt-nohead`, or key-value tsv
   - File pattern regex (e.g. `"\\.mytool\\.table1\\.tsv$"`)
   - Version subsets (e.g. `v1.0.0`, `latest`) — at minimum `latest`
   - Raw columns: name, LinkML range (`string`, `integer`, `float`), and which version subsets each belongs to
   - Tidy columns: name (snake_case), LinkML range, description, and which version subsets each belongs to

Then create the following files, following the conventions in `Tool1`/`Workflow1` exactly:

### 1. `R/<ClassName>.R`

An R6 class inheriting from `Tool`. Include:
- roxygen `@title`, `@description`, `@examples`, `@testexamples`, `@export` block
- `initialize()` calling `super$initialize(name = "<toolname>", pkg = "nemo", path = path, files_tbl = files_tbl)`
- For each table: a `parse_<table>()` method calling `self$.parse_file()` (or `self$.parse_file_keyvalue()` for key-value files), and a `tidy_<table>()` method calling `self$.tidy_file()`

### 2. `inst/config/tools/<toolname>/schema.yaml`

A single LinkML schema file. Include:
- `id`, `name`, `description`, `prefixes`, `imports`, `default_range: string`, `default_prefix`
- `subsets` block: always include `raw` and `tidy`; add one entry per version subset supplied
- For each table, a `Raw<Table>` class and a `Tidy<Table>` class following the naming convention in CLAUDE.md:
  - `Raw<Table>`: `in_subset: [raw]`, annotations with `name`, `pattern`, `ftype`; attributes with version-tagged `in_subset` lists
  - `Tidy<Table>`: `in_subset: [tidy]`, annotations with `name`, `subtbl: tbl1`; attributes with `description` and version-tagged `in_subset` lists

### 3. `inst/extdata/<toolname>/latest/`

Create one minimal placeholder TSV file per table (with correct headers matching the `latest` version raw schema). Use realistic-looking but fake data (1-2 rows). For `txt-nohead` files, omit the header row.

After creating all files, remind the user to:
- Run `devtools::document()` to regenerate `NAMESPACE` and `man/` files
- Add the new class to any relevant `Workflow` if applicable
