# Parse Key-Value file

Parses files with no header and two columns representing key-value
pairs.

## Usage

``` r
parse_file_keyvalue(fpath, pname, schemas_all, delim = "\t", ...)
```

## Arguments

- fpath:

  (`character(1)`)  
  File path.

- pname:

  (`character(1)`)  
  Parser name.

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
dir1 <- system.file("extdata/tool1", package = "nemo")
fpath <- file.path(dir1, "latest", "sampleA.tool1.table3.tsv")
x <- Tool1$new(dir1)
schemas_all <- x$raw_schemas_all
pname <- "table3"
(d <- parse_file_keyvalue(fpath, pname, schemas_all))
#> # A tibble: 1 × 5
#>   SampleID QCStatus TotalReads MappedReads UnmappedReads
#>   <chr>    <chr>    <chr>      <chr>       <chr>        
#> 1 sampleA  Pass     10000      9500        500          
```
