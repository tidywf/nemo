# Config Object

Config YAML file parsing.

## Public fields

- `tool`:

  (`character(1)`)  
  Tool name.

- `schema`:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  Parsed LinkML schema.

- `raw_schemas_all`:

  (`tibble()`)  
  All raw schemas for tool.

- `tidy_schemas_all`:

  (`tibble()`)  
  All tidy schemas for tool.

## Methods

### Public methods

- [`Config$new()`](#method-Config-new)

- [`Config$print()`](#method-Config-print)

- [`Config$read()`](#method-Config-read)

- [`Config$get_raw_patterns()`](#method-Config-get_raw_patterns)

- [`Config$get_raw_versions()`](#method-Config-get_raw_versions)

- [`Config$get_raw_descriptions()`](#method-Config-get_raw_descriptions)

- [`Config$get_raw_schemas_all()`](#method-Config-get_raw_schemas_all)

- [`Config$get_raw_schema()`](#method-Config-get_raw_schema)

- [`Config$are_raw_schemas_valid()`](#method-Config-are_raw_schemas_valid)

- [`Config$get_tidy_descriptions()`](#method-Config-get_tidy_descriptions)

- [`Config$get_tidy_schemas_all()`](#method-Config-get_tidy_schemas_all)

- [`Config$get_tidy_schema()`](#method-Config-get_tidy_schema)

- [`Config$clone()`](#method-Config-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new Config object.

#### Usage

    Config$new(tool, pkg)

#### Arguments

- `tool`:

  (`character(1)`)  
  Tool name.

- `pkg`:

  (`character(1)`)  
  Package name for config lookup.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print details about the Config.

#### Usage

    Config$print(...)

#### Arguments

- `...`:

  (ignored).

------------------------------------------------------------------------

### Method `read()`

Read LinkML schema.yaml.

#### Usage

    Config$read(pkg)

#### Arguments

- `pkg`:

  (`character(1)`)  
  Package name where the config files are located.

#### Returns

A [`list()`](https://rdrr.io/r/base/list.html) with the parsed LinkML
schema.

------------------------------------------------------------------------

### Method `get_raw_patterns()`

Return all output file patterns.

#### Usage

    Config$get_raw_patterns()

------------------------------------------------------------------------

### Method `get_raw_versions()`

Return all output file schema versions.

#### Usage

    Config$get_raw_versions()

------------------------------------------------------------------------

### Method `get_raw_descriptions()`

Return all output file descriptions.

#### Usage

    Config$get_raw_descriptions()

------------------------------------------------------------------------

### Method `get_raw_schemas_all()`

Return all output file schemas.

#### Usage

    Config$get_raw_schemas_all()

------------------------------------------------------------------------

### Method `get_raw_schema()`

Get raw file schema.

#### Usage

    Config$get_raw_schema(x = NULL, v = NULL)

#### Arguments

- `x`:

  (`character(1)`)  
  Raw file name.

- `v`:

  (`character(1)`)  
  Version of schema. If NULL, returns all versions for particular file.

------------------------------------------------------------------------

### Method `are_raw_schemas_valid()`

Validate schema.

#### Usage

    Config$are_raw_schemas_valid()

------------------------------------------------------------------------

### Method `get_tidy_descriptions()`

Return all tidy tibble descriptions.

#### Usage

    Config$get_tidy_descriptions()

------------------------------------------------------------------------

### Method `get_tidy_schemas_all()`

Return all tidy tibble schemas.

#### Usage

    Config$get_tidy_schemas_all()

------------------------------------------------------------------------

### Method `get_tidy_schema()`

Get tidy tbl schema.

#### Usage

    Config$get_tidy_schema(x = NULL, v = NULL, subtbl = NULL)

#### Arguments

- `x`:

  (`character(1)`)  
  Tidy tbl name.

- `v`:

  (`character(1)`)  
  Version of schema. If NULL, returns all versions for particular tbl.

- `subtbl`:

  (`character(1)`)  
  Subtbl to use. If NULL, returns all subtbls for particular tbl and
  version.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Config$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
tool <- "tool1"
pkg <- "nemo"
conf <- Config$new(tool, pkg)
conf$get_raw_patterns()
#> # A tibble: 3 × 2
#>   name   value                     
#>   <chr>  <chr>                     
#> 1 table1 "\\.tool1\\.table1\\.tsv$"
#> 2 table2 "\\.tool1\\.table2\\.tsv$"
#> 3 table3 "\\.tool1\\.table3\\.tsv$"
(rv1 <- conf$get_raw_versions())
#> # A tibble: 4 × 2
#>   name   value 
#>   <chr>  <chr> 
#> 1 table1 v1.2.3
#> 2 table1 latest
#> 3 table2 latest
#> 4 table3 latest
conf$get_raw_descriptions()
#> # A tibble: 3 × 2
#>   name   value                       
#>   <chr>  <chr>                       
#> 1 table1 Table1 raw file.            
#> 2 table2 Table2 raw file.            
#> 3 table3 Table3 raw file (no header).
conf$get_raw_schemas_all()
#> # A tibble: 4 × 4
#>   name   tbl_description              version schema          
#>   <chr>  <chr>                        <chr>   <list>          
#> 1 table1 Table1 raw file.             v1.2.3  <tibble [5 × 2]>
#> 2 table1 Table1 raw file.             latest  <tibble [7 × 2]>
#> 3 table2 Table2 raw file.             latest  <tibble [3 × 2]>
#> 4 table3 Table3 raw file (no header). latest  <tibble [5 × 2]>
conf$get_raw_schema("table1")
#> # A tibble: 12 × 5
#>    name   tbl_description  version field      type 
#>    <chr>  <chr>            <chr>   <chr>      <chr>
#>  1 table1 Table1 raw file. v1.2.3  SampleID   c    
#>  2 table1 Table1 raw file. v1.2.3  Chromosome c    
#>  3 table1 Table1 raw file. v1.2.3  Start      i    
#>  4 table1 Table1 raw file. v1.2.3  End        i    
#>  5 table1 Table1 raw file. v1.2.3  metricX    d    
#>  6 table1 Table1 raw file. latest  SampleID   c    
#>  7 table1 Table1 raw file. latest  Chromosome c    
#>  8 table1 Table1 raw file. latest  Start      i    
#>  9 table1 Table1 raw file. latest  End        i    
#> 10 table1 Table1 raw file. latest  metricX    d    
#> 11 table1 Table1 raw file. latest  metricY    d    
#> 12 table1 Table1 raw file. latest  metricZ    d    
conf$get_raw_schema("table1", v = "v1.2.3")
#> # A tibble: 5 × 5
#>   name   tbl_description  version field      type 
#>   <chr>  <chr>            <chr>   <chr>      <chr>
#> 1 table1 Table1 raw file. v1.2.3  SampleID   c    
#> 2 table1 Table1 raw file. v1.2.3  Chromosome c    
#> 3 table1 Table1 raw file. v1.2.3  Start      i    
#> 4 table1 Table1 raw file. v1.2.3  End        i    
#> 5 table1 Table1 raw file. v1.2.3  metricX    d    
conf$are_raw_schemas_valid()
#> [1] TRUE
conf$get_tidy_descriptions()
#> # A tibble: 3 × 2
#>   name   value              
#>   <chr>  <chr>              
#> 1 table1 Table1 tidy output.
#> 2 table2 Table2 tidy output.
#> 3 table3 Table3 tidy output.
(ts1 <- conf$get_tidy_schemas_all())
#> # A tibble: 4 × 5
#>   name   tbl_description     version tbl   schema          
#>   <chr>  <chr>               <chr>   <chr> <list>          
#> 1 table1 Table1 tidy output. v1.2.3  tbl1  <tibble [5 × 3]>
#> 2 table1 Table1 tidy output. latest  tbl1  <tibble [7 × 3]>
#> 3 table2 Table2 tidy output. latest  tbl1  <tibble [3 × 3]>
#> 4 table3 Table3 tidy output. latest  tbl1  <tibble [5 × 3]>
conf$get_tidy_schema("table1")
#> # A tibble: 12 × 7
#>    name   tbl_description     version tbl   field      type  description   
#>    <chr>  <chr>               <chr>   <chr> <chr>      <chr> <chr>         
#>  1 table1 Table1 tidy output. v1.2.3  tbl1  sample_id  c     Sample ID     
#>  2 table1 Table1 tidy output. v1.2.3  tbl1  chromosome c     Chromosome    
#>  3 table1 Table1 tidy output. v1.2.3  tbl1  start      i     Start position
#>  4 table1 Table1 tidy output. v1.2.3  tbl1  end        i     End position  
#>  5 table1 Table1 tidy output. v1.2.3  tbl1  metric_x   d     Metric X      
#>  6 table1 Table1 tidy output. latest  tbl1  sample_id  c     Sample ID     
#>  7 table1 Table1 tidy output. latest  tbl1  chromosome c     Chromosome    
#>  8 table1 Table1 tidy output. latest  tbl1  start      i     Start position
#>  9 table1 Table1 tidy output. latest  tbl1  end        i     End position  
#> 10 table1 Table1 tidy output. latest  tbl1  metric_x   d     Metric X      
#> 11 table1 Table1 tidy output. latest  tbl1  metric_y   d     Metric Y      
#> 12 table1 Table1 tidy output. latest  tbl1  metric_z   d     Metric Z      
conf$get_tidy_schema("table1", v = "v1.2.3")
#> # A tibble: 5 × 7
#>   name   tbl_description     version tbl   field      type  description   
#>   <chr>  <chr>               <chr>   <chr> <chr>      <chr> <chr>         
#> 1 table1 Table1 tidy output. v1.2.3  tbl1  sample_id  c     Sample ID     
#> 2 table1 Table1 tidy output. v1.2.3  tbl1  chromosome c     Chromosome    
#> 3 table1 Table1 tidy output. v1.2.3  tbl1  start      i     Start position
#> 4 table1 Table1 tidy output. v1.2.3  tbl1  end        i     End position  
#> 5 table1 Table1 tidy output. v1.2.3  tbl1  metric_x   d     Metric X      
conf$get_tidy_schema("table1", subtbl = "tbl1")
#> # A tibble: 12 × 7
#>    name   tbl_description     version tbl   field      type  description   
#>    <chr>  <chr>               <chr>   <chr> <chr>      <chr> <chr>         
#>  1 table1 Table1 tidy output. v1.2.3  tbl1  sample_id  c     Sample ID     
#>  2 table1 Table1 tidy output. v1.2.3  tbl1  chromosome c     Chromosome    
#>  3 table1 Table1 tidy output. v1.2.3  tbl1  start      i     Start position
#>  4 table1 Table1 tidy output. v1.2.3  tbl1  end        i     End position  
#>  5 table1 Table1 tidy output. v1.2.3  tbl1  metric_x   d     Metric X      
#>  6 table1 Table1 tidy output. latest  tbl1  sample_id  c     Sample ID     
#>  7 table1 Table1 tidy output. latest  tbl1  chromosome c     Chromosome    
#>  8 table1 Table1 tidy output. latest  tbl1  start      i     Start position
#>  9 table1 Table1 tidy output. latest  tbl1  end        i     End position  
#> 10 table1 Table1 tidy output. latest  tbl1  metric_x   d     Metric X      
#> 11 table1 Table1 tidy output. latest  tbl1  metric_y   d     Metric Y      
#> 12 table1 Table1 tidy output. latest  tbl1  metric_z   d     Metric Z      
```
