# Get Version Subsets from a LinkML Schema

Reads a LinkML `schema.yaml` file and returns the names of version
subsets, i.e. all subsets excluding the `raw` and `tidy` meta-subsets.

## Usage

``` r
schema_versions(path)
```

## Arguments

- path:

  (`character(1)`)  
  Path to LinkML `schema.yaml` file.

## Value

Character vector of version subset names, or `character(0)` if none.

## Examples

``` r
p <- system.file("config/tools/tool1/schema.yaml", package = "nemo")
schema_versions(p)
#> [1] "v1.2.3" "latest"
```
