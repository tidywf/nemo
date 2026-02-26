# List Files

Lists files inside a given directory.

## Usage

``` r
list_files_dir(d, max_files = NULL, type = "file")
```

## Arguments

- d:

  (`character(n)`)  
  Character vector of one or more paths.

- max_files:

  (`integer(1)`)  
  Max files returned.

- type:

  (`character(n)`)  
  File type(s) to return (e.g. any, file, directory, symlink). See
  [`fs::dir_info`](https://fs.r-lib.org/reference/dir_ls.html).

## Value

A tibble with file basename, size, last modification timestamp and full
path.

## Examples

``` r
d <- system.file("R", package = "nemo")
x <- list_files_dir(d)
```
