# Output Format is Valid

Checks that the specified output format is valid.

## Usage

``` r
valid_out_fmt(x, choices = nemo_out_formats())
```

## Arguments

- x:

  Output format.

- choices:

  Available choices for valid output formats.

## Examples

``` r
valid_out_fmt("tsv")
#> [1] TRUE
```
