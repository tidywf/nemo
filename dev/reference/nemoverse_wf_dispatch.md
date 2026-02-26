# Nemoverse Workflow Dispatcher

Dispatches the nemoverse workflow class based on the chosen workflow.

## Usage

``` r
nemoverse_wf_dispatch(wf = NULL)
```

## Arguments

- wf:

  Workflow name.

## Value

The nemo workflow class to initiate.

## Examples

``` r
wf <- "basemean"
(fun <- nemoverse_wf_dispatch(wf))
#> function (x, ...) 
#> UseMethod("mean")
#> <bytecode: 0x55b510dd4dc8>
#> <environment: namespace:base>
```
