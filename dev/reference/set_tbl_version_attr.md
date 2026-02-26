# Set Table Version Attribute

Set the version attribute from a table.

## Usage

``` r
set_tbl_version_attr(tbl, v, x = "file_version")
```

## Arguments

- tbl:

  (`tibble()`)  
  Table with a version attribute.

- v:

  (`character(1)`)  
  Version string to set.

- x:

  (`character(1)`)  
  Name of the attribute to retrieve.

## Examples

``` r
d <- tibble::tibble(a = 1:3, b = letters[1:3])
v <- "v1.2.3"
d <- set_tbl_version_attr(d, v)
(a <- attr(d, "file_version"))
#> [1] "v1.2.3"
```
