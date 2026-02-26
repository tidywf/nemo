# Construct Output File Paths with Format Suffix

Construct Output File Paths with Format Suffix

## Usage

``` r
nemo_osfx(fpfix, format)
```

## Arguments

- fpfix:

  (`character(n)`)  
  Vector of one or more file prefixes e.g. /path/to/foo

- format:

  (`character(1)`)  
  Output format. One of tsv, csv, parquet, rds, or db.

## Value

Character vector of output file paths

## Examples

``` r
fpfix <- "path/to/foo"
format <- "tsv"
(o <- nemo_osfx(fpfix, format))
#> [1] "path/to/foo.tsv.gz"
```
