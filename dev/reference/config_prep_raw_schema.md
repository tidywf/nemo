# Prepare config schema from raw file

Prepares config schema from raw file.

## Usage

``` r
config_prep_raw_schema(path, ...)
```

## Arguments

- path:

  (`character(1)`)  
  File path.

- ...:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

## Value

A tibble with columns `field` and `type`, each single-quoted for
prettier YAML export.

## Examples

``` r
path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
(x <- config_prep_raw_schema(path = path, delim = "\t"))
#> # A tibble: 7 × 2
#>   field        type   
#>   <chr>        <chr>  
#> 1 'SampleID'   'char' 
#> 2 'Chromosome' 'char' 
#> 3 'Start'      'float'
#> 4 'End'        'float'
#> 5 'metricX'    'float'
#> 6 'metricY'    'float'
#> 7 'metricZ'    'float'
```
