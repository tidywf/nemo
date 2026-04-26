---
name: nemotool
description: Scaffold a new nemo Tool — R6 class, schema.yaml config, and placeholder test data
---

# nemotool

## Instructions

Scaffold a new nemo Tool. Ask the user for:

1. **Tool name** (e.g. `mytool`) — used for the R6 class name (`MyTool`), the `name` arg in `super$initialize()`, and the `inst/extdata/<name>/` and `inst/config/tools/<name>/` paths.
2. **Description** — one-line description of what the tool parses.
3. **Tables** — for each table, collect:
   - Table name (e.g. `table1`)
   - File type: `txt`, `txt-nohead`, `txt-keyvalue`, or `csv-nohead-long`
   - File pattern regex (e.g. `"\\.mytool\\.table1\\.tsv$"`)
   - Columns: for each column, collect `raw` name, `tidy` name (snake_case), `type` (`char`, `int`, or `float`), `description`, and `since` version (e.g. `v1.0.0` or `latest`)

Then create the following files, following the conventions in `Tool1`/`Workflow1` exactly:

### 1. `R/<ClassName>.R`

An R6 class inheriting from `Tool`. Include:
- roxygen `@title`, `@description`, `@examples`, `@testexamples`, `@export` block
- `initialize()` calling `super$initialize(name = "<toolname>", pkg = "nemo", path = path, files_tbl = files_tbl)`
- For each table: a `parse_<table>()` method calling `self$.parse_file()` (or the appropriate variant for the ftype), and a `tidy_<table>()` method calling `self$.tidy_file()`

### 2. `inst/config/tools/<toolname>/schema.yaml`

A flat YAML config file with a top-level `tables:` map. For each table:

```yaml
tables:
  <table_name>:
    description: '<description>'
    pattern: "<pattern>"
    ftype: '<ftype>'
    columns:
      - raw: '<RawColName>'
        tidy: '<tidy_col_name>'
        type: 'char'   # char | int | float
        description: '<description>'
        since: 'latest'   # or e.g. 'v1.2.3'
```

The `since` field controls versioned schemas: columns with earlier `since` values are included in all subsequent versions. Use `latest` for columns present in all versions; use explicit version tags (e.g. `v1.2.3`) for columns added in that version and carried forward.

### 3. `inst/extdata/<toolname>/latest/`

Create one minimal placeholder file per table (with correct headers matching the `latest` version raw schema). Use realistic-looking but fake data (1-2 rows). For `txt-nohead` files, omit the header row.

After creating all files, remind the user to:
- Run `devtools::document()` to regenerate `NAMESPACE` and `man/` files
- Add the new class to any relevant `Workflow` if applicable
