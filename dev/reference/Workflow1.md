# Workflow1 Object

Workflow1 file parsing and manipulation.

## Super class

[`nemo::Workflow`](https://tidywf.github.io/nemo/dev/reference/Workflow.md)
-\> `Workflow1`

## Methods

### Public methods

- [`Workflow1$new()`](#method-Workflow1-new)

- [`Workflow1$clone()`](#method-Workflow1-clone)

Inherited methods

- [`nemo::Workflow$filter_files()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-filter_files)
- [`nemo::Workflow$get_metadata()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-get_metadata)
- [`nemo::Workflow$get_raw_schemas_all()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-get_raw_schemas_all)
- [`nemo::Workflow$get_tbls()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-get_tbls)
- [`nemo::Workflow$get_tidy_schemas_all()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-get_tidy_schemas_all)
- [`nemo::Workflow$list_files()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-list_files)
- [`nemo::Workflow$nemofy()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-nemofy)
- [`nemo::Workflow$print()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-print)
- [`nemo::Workflow$tidy()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-tidy)
- [`nemo::Workflow$write()`](https://tidywf.github.io/nemo/dev/reference/Workflow.html#method-write)

------------------------------------------------------------------------

### Method `new()`

Create a new Workflow1 object.

#### Usage

    Workflow1$new(path = NULL)

#### Arguments

- `path`:

  (`character(n)`)  
  Path(s) to Workflow1 results.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Workflow1$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
path <- system.file("extdata/tool1", package = "nemo")
odir <- tempdir()
id <- "workflow1_run1"
w <- Workflow1$new(path)
x <- w$nemofy(diro = odir, format = "parquet", input_id = id)
(lf <- list.files(odir, pattern = "tool1.*parquet", full.names = FALSE))
#> [1] "sampleA_2_tool1_table1.parquet" "sampleA_tool1_table1.parquet"  
#> [3] "sampleA_tool1_table2.parquet"   "sampleA_tool1_table3.parquet"  
```
