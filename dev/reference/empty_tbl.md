# Create Empty Tibble

From https://stackoverflow.com/a/62535671/2169986. Useful for handling
edge cases with empty data. e.g. virusbreakend.vcf.summary.tsv

## Usage

``` r
empty_tbl(cnames, ctypes = readr::cols(.default = "c"))
```

## Arguments

- cnames:

  (`character(n)`)  
  Character vector of column names to use.

- ctypes:

  (`character(n)`)  
  Character vector of column types corresponding to `cnames`.

## Value

A tibble with 0 rows and the given column names.

## Examples

``` r
(x <- empty_tbl(cnames = c("a", "b", "c")))
#> # A tibble: 0 × 3
#> # ℹ 3 variables: a <chr>, b <chr>, c <chr>
```
