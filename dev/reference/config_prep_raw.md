# Prepare config from raw file

Prepares config from raw file.

## Usage

``` r
config_prep_raw(path, name, descr, pat, type = "tsv", v = "latest", ...)
```

## Arguments

- path:

  (`character(1)`)  
  File path.

- name:

  (`character(1)`)  
  File nickname.

- descr:

  (`character(1)`)  
  File description.

- pat:

  (`character(1)`)  
  File pattern.

- type:

  (`character(1)`)  
  File type.

- v:

  (`character(1)`)  
  File version.

- ...:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).

## Value

A named list with the config info.

## Examples

``` r
path <- system.file("extdata", "tool1/latest/sampleA.tool1.table1.tsv", package = "nemo")
name <- "table1"
descr <- "Table1 from Tool1."
pat <- "\\.tool1\\.table1\\.tsv$"
l <- config_prep_raw(path, name, descr, pat)
```
