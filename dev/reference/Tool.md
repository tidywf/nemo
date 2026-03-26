# Tool Object

Base class for all nemo tools.

## Public fields

- `name`:

  (`character(1)`)  
  Name of tool.

- `path`:

  (`character(1)`)  
  Output directory of tool.

- `config`:

  ([`Config()`](https://tidywf.github.io/nemo/dev/reference/Config.md))  
  Config of tool.

- `files`:

  (`tibble()`)  
  Tibble of files matching available Tool patterns.

- `tbls`:

  (`tibble()`)  
  Tibble of tidy tibbles.

- `raw_schemas_all`:

  (`tibble()`)  
  All raw schemas for tool.

- `tidy_schemas_all`:

  (`tibble()`)  
  All tidy schemas for tool.

- `get_tidy_schema`:

  (`function()`)  
  Get specific tidy schema.

- `get_raw_schema`:

  (`function()`)  
  Get specific raw schema.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`list_files_dir()`](https://tidywf.github.io/nemo/dev/reference/list_files_dir.md).

## Methods

### Public methods

- [`Tool$new()`](#method-Tool-new)

- [`Tool$print()`](#method-Tool-print)

- [`Tool$filter_files()`](#method-Tool-filter_files)

- [`Tool$list_files()`](#method-Tool-list_files)

- [`Tool$.parse_file()`](#method-Tool-.parse_file)

- [`Tool$.tidy_file()`](#method-Tool-.tidy_file)

- [`Tool$.parse_file_keyvalue()`](#method-Tool-.parse_file_keyvalue)

- [`Tool$.parse_file_nohead()`](#method-Tool-.parse_file_nohead)

- [`Tool$.eval_func()`](#method-Tool-.eval_func)

- [`Tool$tidy()`](#method-Tool-tidy)

- [`Tool$write()`](#method-Tool-write)

- [`Tool$nemofy()`](#method-Tool-nemofy)

- [`Tool$clone()`](#method-Tool-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new Tool object.

#### Usage

    Tool$new(name = NULL, pkg = NULL, path = NULL, files_tbl = NULL)

#### Arguments

- `name`:

  (`character(1)`)  
  Name of tool.

- `pkg`:

  (`character(1)`)  
  Package name tool belongs to (for config lookup).

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this basically
  gets ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`list_files_dir()`](https://tidywf.github.io/nemo/dev/reference/list_files_dir.md).

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print details about the Tool.

#### Usage

    Tool$print(...)

#### Arguments

- `...`:

  (ignored).

#### Returns

self invisibly.

------------------------------------------------------------------------

### Method `filter_files()`

Filter files in given tool directory.

#### Usage

    Tool$filter_files(include = NULL, exclude = NULL)

#### Arguments

- `include`:

  (`character(n)`)  
  Files to include.

- `exclude`:

  (`character(n)`)  
  Files to exclude.

#### Returns

The tibble of files with potentially removed rows.

------------------------------------------------------------------------

### Method `list_files()`

List files in given tool directory.

#### Usage

    Tool$list_files(type = "file")

#### Arguments

- `type`:

  (`character(1)`)  
  File type(s) to return (e.g. any, file, directory, symlink). See
  [`fs::dir_info`](https://fs.r-lib.org/reference/dir_ls.html).

#### Returns

A tibble of file paths.

------------------------------------------------------------------------

### Method `.parse_file()`

Parse file.

#### Usage

    Tool$.parse_file(x, name, delim = "\t", ...)

#### Arguments

- `x`:

  (`character(1)`)  
  File path.

- `name`:

  (`character(1)`)  
  Parser name (e.g. "breakends" - see docs).

- `delim`:

  (`character(1)`)  
  File delimiter.

- `...`:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

#### Returns

A tibble with the parsed data.

------------------------------------------------------------------------

### Method `.tidy_file()`

Tidy file.

#### Usage

    Tool$.tidy_file(x, name, convert_types = FALSE)

#### Arguments

- `x`:

  (`character(1)` or `tibble()`)  
  File path or already parsed raw tibble.

- `name`:

  (`character(1)`)  
  Parser name (e.g. "breakends" - see docs).

- `convert_types`:

  (`logical(1)`)  
  Convert field types based on schema.

#### Returns

A tibble with the tidy data enframed.

------------------------------------------------------------------------

### Method `.parse_file_keyvalue()`

Parse files with no header and two columns representing key-value pairs.

#### Usage

    Tool$.parse_file_keyvalue(x, name, delim = "\t", ...)

#### Arguments

- `x`:

  (`character(1)`)  
  File path.

- `name`:

  (`character(1)`)  
  Parser name (e.g. "qc" - see docs).

- `delim`:

  (`character(1)`)  
  File delimiter.

- `...`:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

#### Returns

A tibble with the parsed data.

------------------------------------------------------------------------

### Method `.parse_file_nohead()`

Parse headless file.

#### Usage

    Tool$.parse_file_nohead(x, pname, delim = "\t", ...)

#### Arguments

- `x`:

  (`character(1)`)  
  File path.

- `pname`:

  (`character(1)`)  
  Parser name (e.g. "breakends" - see docs).

- `delim`:

  (`character(1)`)  
  File delimiter.

- `...`:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

#### Returns

A tibble with the parsed data.

------------------------------------------------------------------------

### Method `.eval_func()`

Evaluate function in the context of the Tool's environment.

#### Usage

    Tool$.eval_func(fun, envir = self)

#### Arguments

- `fun`:

  (`character(1)`)  
  Function from Tool to evaluate.

- `envir`:

  ([`environment()`](https://rdrr.io/r/base/environment.html))  
  Environment to evaluate the function within.

#### Returns

The evaluated function.

------------------------------------------------------------------------

### Method `tidy()`

Tidy a list of files.

#### Usage

    Tool$tidy(tidy = TRUE, keep_raw = FALSE)

#### Arguments

- `tidy`:

  (`logical(1)`)  
  Should the raw parsed tibbles get tidied?

- `keep_raw`:

  (`logical(1)`)  
  Should the raw parsed tibbles be kept in the final output?

#### Returns

self invisibly.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write tidy tibbles.

#### Usage

    Tool$write(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = ulid::ulid(),
      dbconn = NULL
    )

#### Arguments

- `diro`:

  (`character(1)`)  
  Directory path to output tidy files. Ignored if format is db.

- `format`:

  (`character(1)`)  
  Format of output.

- `input_id`:

  (`character(1)`)  
  Input ID to use for the dataset (e.g. `run123`).

- `output_id`:

  (`character(1)`)  
  Output ID to use for the dataset (e.g. `run123`).

- `dbconn`:

  (`DBIConnection`)  
  Database connection object (see
  [`DBI::dbConnect`](https://dbi.r-dbi.org/reference/dbConnect.html)).

#### Returns

A tibble with the tidy data and their output location prefix.

------------------------------------------------------------------------

### Method `nemofy()`

Parse, filter, tidy and write files.

#### Usage

    Tool$nemofy(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = ulid::ulid(),
      dbconn = NULL,
      include = NULL,
      exclude = NULL
    )

#### Arguments

- `diro`:

  (`character(1)`)  
  Directory path to output tidy files.

- `format`:

  (`character(1)`)  
  Format of output.

- `input_id`:

  (`character(1)`)  
  Input ID to use for the dataset (e.g. `run123`).

- `output_id`:

  (`character(1)`)  
  Output ID to use for the dataset (e.g. `run123`).

- `dbconn`:

  (`DBIConnection`)  
  Database connection object (see
  [`DBI::dbConnect`](https://dbi.r-dbi.org/reference/dbConnect.html)).

- `include`:

  (`character(n)`)  
  Files to include.

- `exclude`:

  (`character(n)`)  
  Files to exclude.

#### Returns

A tibble with the tidy data and their output location prefix.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Tool$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
path <- here::here("inst/extdata/tool1")
# demo filter + tidy
x <- Tool1$new(path = path)$
  filter_files(exclude = "alignments_dupfreq")$
  tidy(keep_raw = TRUE)
x$tbls
x$files
x$list_files()
lx <- Linx$new(path)
dbconn <- DBI::dbConnect(
  drv = RPostgres::Postgres(),
  dbname = "nemo",
  user = "orcabus"
)
lx$nemofy(
    diro = "nogit/test_data",
    format = "db", # "parquet",
    id = "run2",
    dbconn = dbconn,
    include = NULL,
    exclude = NULL
)
DBI::dbDisconnect(dbconn)
} # }
```
