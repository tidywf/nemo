# Get file header

Returns the column names of a file without reading the entire file.

## Usage

``` r
file_hdr(fpath, delim = "\t", n_max = 0, ...)
```

## Arguments

- fpath:

  (`character(1)`)  
  File path.

- delim:

  (`character(1)`)  
  File delimiter.

- n_max:

  (`integer(1)`)  
  Maximum number of lines to read.

- ...:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

## Examples

``` r
dir1 <- system.file("extdata/tool1", package = "nemo")
fpath <- file.path(dir1, "latest", "sampleA.tool1.table1.tsv")
(hdr <- file_hdr(fpath))
#> [1] "SampleID"   "Chromosome" "Start"      "End"        "metricX"   
#> [6] "metricY"    "metricZ"   
```
