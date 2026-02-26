# Generate Mermaid ER Diagram from a LinkML Schema

Reads a LinkML `schema.yaml` file and returns a Mermaid ER diagram
string that can be embedded in a Quarto document via a `{mermaid}`
fenced block. When `version` is `NULL`, all schema versions are merged
into a single view. When `version` is specified, only attributes
belonging to that version are shown.

## Usage

``` r
schema_to_mermaid(path, version = NULL)
```

## Arguments

- path:

  (`character(1)`)  
  Path to a LinkML `schema.yaml` file.

- version:

  (`character(1)` or `NULL`)  
  Version subset name (e.g. `"v4.0"`, `"latest"`). When `NULL`, all
  attributes are included regardless of version.

## Value

A single character string containing a Mermaid `erDiagram` block.

## Examples

``` r
p <- system.file("config/tools/tool1/schema.yaml", package = "nemo")
cat(schema_to_mermaid(p))
#> erDiagram
#> RawTable1 {
#>     string SampleID
#>     string Chromosome
#>     integer Start
#>     integer End
#>     float metricX
#>     float metricY
#>     float metricZ
#> }
#> TidyTable1 {
#>     string sample_id
#>     string chromosome
#>     integer start
#>     integer end
#>     float metric_x
#>     float metric_y
#>     float metric_z
#> }
#> RawTable2 {
#>     string SampleID
#>     string metricA
#>     float metricB
#> }
#> TidyTable2 {
#>     string sample_id
#>     string metric_a
#>     float metric_b
#> }
#> RawTable3 {
#>     string SampleID
#>     string QCStatus
#>     float TotalReads
#>     float MappedReads
#>     float UnmappedReads
#> }
#> TidyTable3 {
#>     string sample_id
#>     string qcstatus
#>     float reads_total
#>     float reads_map
#>     float reads_unmap
#> }
```
