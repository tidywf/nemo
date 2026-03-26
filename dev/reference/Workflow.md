# Workflow Object

A Workflow is composed of multiple Tools.

## Public fields

- `name`:

  (`character(1)`)  
  Name of workflow.

- `path`:

  (`character(n)`)  
  Path(s) to workflow results.

- `tools`:

  (`list(n)`)  
  List of Tools that compose a Workflow.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`list_files_dir()`](https://tidywf.github.io/nemo/dev/reference/list_files_dir.md).

- `written_files`:

  (`tibble(n)`)  
  Tibble of files written from `self$write()`.

## Methods

### Public methods

- [`Workflow$new()`](#method-Workflow-new)

- [`Workflow$print()`](#method-Workflow-print)

- [`Workflow$filter_files()`](#method-Workflow-filter_files)

- [`Workflow$list_files()`](#method-Workflow-list_files)

- [`Workflow$tidy()`](#method-Workflow-tidy)

- [`Workflow$write()`](#method-Workflow-write)

- [`Workflow$nemofy()`](#method-Workflow-nemofy)

- [`Workflow$get_raw_schemas_all()`](#method-Workflow-get_raw_schemas_all)

- [`Workflow$get_tidy_schemas_all()`](#method-Workflow-get_tidy_schemas_all)

- [`Workflow$get_tbls()`](#method-Workflow-get_tbls)

- [`Workflow$get_metadata()`](#method-Workflow-get_metadata)

- [`Workflow$clone()`](#method-Workflow-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new Workflow object.

#### Usage

    Workflow$new(name = NULL, path = NULL, tools = NULL)

#### Arguments

- `name`:

  (`character(1)`)  
  Name of workflow.

- `path`:

  (`character(n)`)  
  Path(s) to workflow results.

- `tools`:

  (`list(n)`)  
  List of Tools that compose a Workflow.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print details about the File.

#### Usage

    Workflow$print(...)

#### Arguments

- `...`:

  (ignored).

------------------------------------------------------------------------

### Method `filter_files()`

Filter files in given workflow directory.

#### Usage

    Workflow$filter_files(include = NULL, exclude = NULL)

#### Arguments

- `include`:

  (`character(n)`)  
  Files to include.

- `exclude`:

  (`character(n)`)  
  Files to exclude.

------------------------------------------------------------------------

### Method `list_files()`

List files in given workflow directory.

#### Usage

    Workflow$list_files(type = c("file", "symlink"))

#### Arguments

- `type`:

  (`character(1)`)  
  File types(s) to return (e.g. any, file, directory, symlink). See
  [`fs::dir_info`](https://fs.r-lib.org/reference/dir_ls.html).

#### Returns

A tibble with all files found for each Tool.

------------------------------------------------------------------------

### Method `tidy()`

Tidy Workflow files.

#### Usage

    Workflow$tidy(tidy = TRUE, keep_raw = FALSE)

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

    Workflow$write(
      diro = ".",
      format = "tsv",
      input_id = NULL,
      output_id = ulid::ulid(),
      dbconn = NULL
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

#### Returns

self invisibly.

------------------------------------------------------------------------

### Method `nemofy()`

Parse, filter, tidy and write files.

#### Usage

    Workflow$nemofy(
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

self invisibly.

------------------------------------------------------------------------

### Method `get_raw_schemas_all()`

Get raw schemas for all Tools.

#### Usage

    Workflow$get_raw_schemas_all()

#### Returns

Tibble with names of tool and file, schema and its version.

------------------------------------------------------------------------

### Method `get_tidy_schemas_all()`

Get tidy schemas for all Tools.

#### Usage

    Workflow$get_tidy_schemas_all()

#### Returns

Tibble with names of tool and tbl, schema and its version.

------------------------------------------------------------------------

### Method `get_tbls()`

Get tidy tbls for all Tools.

#### Usage

    Workflow$get_tbls()

#### Returns

Tibble with tidy tbls of all Tools.

------------------------------------------------------------------------

### Method `get_metadata()`

Get metadata

#### Usage

    Workflow$get_metadata(input_id, output_id, output_dir, pkgs = c("nemo"))

#### Arguments

- `input_id`:

  (`character(1)`)  
  Input ID to use for the dataset (e.g. `run123`).

- `output_id`:

  (`character(1)`)  
  Output ID to use for the dataset (e.g. `run123`).

- `output_dir`:

  (`character(1)`)  
  Output directory.

- `pkgs`:

  (`character(n)`)  
  Which R packages to extract versions for.

#### Returns

List with metadata

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Workflow$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
path <- system.file("extdata/tool1", package = "nemo")
tools <- list(tool1 = Tool1)
wf1 <- Workflow$new(name = "foo", path = path, tools = tools)
diro <- tempdir()
wf1$list_files()
#> # A tibble: 4 × 9
#>   tool_parser  parser bname  size lastmodified        path  pattern prefix group
#>   <glue>       <chr>  <chr> <fs:> <dttm>              <chr> <chr>   <glue> <glu>
#> 1 tool1_table1 table1 samp…   113 2026-03-26 03:10:41 /hom… "\\.to… sampl…      
#> 2 tool1_table1 table1 samp…   153 2026-03-26 03:10:41 /hom… "\\.to… sampl… _2   
#> 3 tool1_table2 table2 samp…    70 2026-03-26 03:10:41 /hom… "\\.to… sampl…      
#> 4 tool1_table3 table3 samp…    83 2026-03-26 03:10:41 /hom… "\\.to… sampl…      
wf1$nemofy(diro = diro, format = "parquet", input_id = "run1")
(lf <- list.files(diro, pattern = "tool1.*parquet", full.names = FALSE))
#> [1] "sampleA_2_tool1_table1.parquet" "sampleA_tool1_table1.parquet"  
#> [3] "sampleA_tool1_table2.parquet"   "sampleA_tool1_table3.parquet"  
#dbconn <- DBI::dbConnect(drv = RPostgres::Postgres(), dbname = "nemo", user = "orcabus")
#wf1$nemofy(format = "db", id = "runABC", dbconn = dbconn)
```
