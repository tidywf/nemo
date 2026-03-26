# Tool1 Object

Tool1 file parsing and manipulation.

## Super class

[`nemo::Tool`](https://tidywf.github.io/nemo/dev/reference/Tool.md) -\>
`Tool1`

## Methods

### Public methods

- [`Tool1$new()`](#method-Tool1-new)

- [`Tool1$parse_table1()`](#method-Tool1-parse_table1)

- [`Tool1$tidy_table1()`](#method-Tool1-tidy_table1)

- [`Tool1$parse_table2()`](#method-Tool1-parse_table2)

- [`Tool1$tidy_table2()`](#method-Tool1-tidy_table2)

- [`Tool1$parse_table3()`](#method-Tool1-parse_table3)

- [`Tool1$tidy_table3()`](#method-Tool1-tidy_table3)

- [`Tool1$clone()`](#method-Tool1-clone)

Inherited methods

- [`nemo::Tool$.eval_func()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-.eval_func)
- [`nemo::Tool$.parse_file()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-.parse_file)
- [`nemo::Tool$.parse_file_keyvalue()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-.parse_file_keyvalue)
- [`nemo::Tool$.parse_file_nohead()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-.parse_file_nohead)
- [`nemo::Tool$.tidy_file()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-.tidy_file)
- [`nemo::Tool$filter_files()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-filter_files)
- [`nemo::Tool$list_files()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-list_files)
- [`nemo::Tool$nemofy()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-nemofy)
- [`nemo::Tool$print()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-print)
- [`nemo::Tool$tidy()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-tidy)
- [`nemo::Tool$write()`](https://tidywf.github.io/nemo/dev/reference/Tool.html#method-write)

------------------------------------------------------------------------

### Method `new()`

Create a new Tool1 object.

#### Usage

    Tool1$new(path = NULL, files_tbl = NULL)

#### Arguments

- `path`:

  (`character(1)`)  
  Output directory of tool. If `files_tbl` is supplied, this basically
  gets ignored.

- `files_tbl`:

  (`tibble(n)`)  
  Tibble of files from
  [`list_files_dir()`](https://tidywf.github.io/nemo/dev/reference/list_files_dir.md).

------------------------------------------------------------------------

### Method `parse_table1()`

Read `table1.tsv` file.

#### Usage

    Tool1$parse_table1(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_table1()`

Tidy `table1.tsv` file.

#### Usage

    Tool1$tidy_table1(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_table2()`

Read `table2.tsv` file.

#### Usage

    Tool1$parse_table2(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_table2()`

Tidy `table2.tsv` file.

#### Usage

    Tool1$tidy_table2(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `parse_table3()`

Read `table3.tsv` file.

#### Usage

    Tool1$parse_table3(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `tidy_table3()`

Tidy `table3.tsv` file.

#### Usage

    Tool1$tidy_table3(x)

#### Arguments

- `x`:

  (`character(1)`)  
  Path to file.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Tool1$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
cls <- Tool1
indir <- system.file("extdata/tool1", package = "nemo")
odir <- tempdir()
id <- "tool1_run1"
obj <- cls$new(indir)
obj$nemofy(diro = odir, format = "parquet", input_id = id)
(lf <- list.files(odir, pattern = "tool1.*parquet", full.names = FALSE))
#> [1] "sampleA_2_tool1_table1.parquet" "sampleA_tool1_table1.parquet"  
#> [3] "sampleA_tool1_table2.parquet"   "sampleA_tool1_table3.parquet"  
```
