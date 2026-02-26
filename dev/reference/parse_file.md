# Parse file

Parses files.

## Usage

``` r
parse_file(fpath, pname, schemas_all, delim = "\t", ...)
```

## Arguments

- fpath:

  (`character(1)`)  
  File path.

- pname:

  (`character(1)`)  
  Parser name (e.g. "breakends" - see docs).

- schemas_all:

  (`tibble()`)  
  Tibble with name, version and schema list-col.

- delim:

  (`character(1)`)  
  File delimiter.

- ...:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

## Examples

``` r
path <- system.file("extdata/tool1", package = "nemo")
x <- Tool$new("tool1", pkg = "nemo", path)
schemas_all <- x$raw_schemas_all
pname <- "table1"
fpath <- file.path(path, "latest", "sampleA.tool1.table1.tsv")
(d <- parse_file(fpath, pname, schemas_all))
#> # A tibble: 3 × 7
#>   SampleID Chromosome Start   End metricX metricY metricZ
#>   <chr>    <chr>      <int> <int>   <dbl>   <dbl>   <dbl>
#> 1 sampleA  chr1          10    50     0.1     0.4     0.7
#> 2 sampleA  chr2         100   500     0.2     0.5     0.8
#> 3 sampleA  chr3        1000  5000     0.3     0.6     0.9
```
