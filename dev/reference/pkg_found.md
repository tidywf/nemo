# Check if Package is Installed

Check if an R package is installed.

## Usage

``` r
pkg_found(p)
```

## Arguments

- p:

  (`character(1)`)  
  Package name.

## Value

`TRUE` if the package is installed, `FALSE` otherwise.

## Examples

``` r
pkg_found("base")
#> [1] TRUE
pkg_found("somefakepackagename")
#> [1] FALSE
```
