# Get Table Version Attribute

Get the version attribute from a table.

## Usage

``` r
get_tbl_version_attr(tbl, x = "file_version")
```

## Arguments

- tbl:

  (`tibble()`)  
  Table with a version attribute.

- x:

  (`character(1)`)  
  Name of the attribute to retrieve.

## Examples

``` r
path <- system.file("extdata/tool1", package = "nemo")
path2 <- file.path(path, "v1.2.3", "sampleA.tool1.table1.tsv")
x <- Tool1$new(path)$tidy(keep_raw = TRUE)
ind <- which(x$tbls$path == path2)
stopifnot(length(ind) == 1)
(v <- get_tbl_version_attr(x$tbls$raw[[ind]]))
#> [1] "v1.2.3"
```
