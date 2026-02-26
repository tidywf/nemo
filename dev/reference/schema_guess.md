# Guess Schema

Given a tibble of available schemas, filters to the one matching the
given column names. Errors out if unsuccessful.

## Usage

``` r
schema_guess(pname, cnames, schemas_all)
```

## Arguments

- pname:

  (`character(1)`)  
  Parser name.

- cnames:

  (`character(n)`)  
  Column names.

- schemas_all:

  (`tibble()`)  
  Tibble with name, version and schema list-col.

## Examples

``` r
dir1 <- system.file("extdata/tool1", package = "nemo")
fpath1 <- file.path(dir1, "latest", "sampleA.tool1.table1.tsv")
fpath2 <- file.path(dir1, "v1.2.3", "sampleA.tool1.table1.tsv")
pname <- "table1"
cnames1 <- file_hdr(fpath1)
cnames2 <- file_hdr(fpath2)
conf <- Config$new("tool1", pkg = "nemo")
schemas_all <- conf$get_raw_schemas_all()
(s1 <- schema_guess(pname, cnames1, schemas_all))
#> $schema
#> # A tibble: 7 × 2
#>   field      type 
#>   <chr>      <chr>
#> 1 SampleID   c    
#> 2 Chromosome c    
#> 3 Start      i    
#> 4 End        i    
#> 5 metricX    d    
#> 6 metricY    d    
#> 7 metricZ    d    
#> 
#> $version
#> [1] "latest"
#> 
(s2 <- schema_guess(pname, cnames2, schemas_all))
#> $schema
#> # A tibble: 5 × 2
#>   field      type 
#>   <chr>      <chr>
#> 1 SampleID   c    
#> 2 Chromosome c    
#> 3 Start      i    
#> 4 End        i    
#> 5 metricX    d    
#> 
#> $version
#> [1] "v1.2.3"
#> 
```
