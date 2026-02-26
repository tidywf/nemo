# Prepare config for multiple raw files

Prepare config for multiple raw files

## Usage

``` r
config_prep_multi(x, tool_descr = NULL)
```

## Arguments

- x:

  (`tibble()`)  
  Tibble with columns `name`, `descr`, `pat`, `type`, and `path`.

- tool_descr:

  (`character(1)`)  
  Tool description.

## Value

A named list with the config info.

## Examples

``` r
dir1 <-  "extdata/tool1/latest"
path1 <- system.file(dir1, "sampleA.tool1.table1.tsv", package = "nemo")
path2 <- system.file(dir1, "sampleA.tool1.table2.tsv", package = "nemo")
x <- tibble::tibble(
  name = c("table1", "table2"),
  descr = c("Table1 from Tool1.", "Table2 from Tool1."),
  pat = c("\\.tool1\\.table1\\.tsv$", "\\.tool1\\.table2\\.tsv$"),
  type = c("tsv", "tsv"),
  path = c(path1, path2)
)
tool_descr <- "Tool1 does amazing things."
config <- config_prep_multi(x, tool_descr)
```
