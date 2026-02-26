# Parse headless file

Parses files with no column names.

## Usage

``` r
parse_file_nohead(fpath, schema, delim = "\t", ...)
```

## Arguments

- fpath:

  (`character(1)`)  
  File path.

- schema:

  (`tibble()`)  
  Schema tibble with version and schema list-col.

- delim:

  (`character(1)`)  
  File delimiter.

- ...:

  Passed on to
  [`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html).
