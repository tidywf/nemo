# Structure

{nemo} is built on top of R’s
[R6](https://github.com/r-lib/R6 "R6 package repo") encapsulated
object-oriented programming implementation, which helps with code
organisation. It consists of several base classes like `Config`, `Tool`,
and `Workflow` which we describe below. Each R6 class can contain public
and private functions and non-functions (fields).

Other R packages like
{[tidywigits](https://github.com/umccr/tidywigits "tidywigits")} and
{[dracarys](https://github.com/umccr/dracarys "dracarys")} can create
their own `Tool` and `Workflow` children classes that inherit (or
override) functions from the {nemo} parent classes. This allows for
custom parsers and tidiers for specific bioinformatic tools and
workflows.

Here we use the `Tool1` and `Workflow1` classes as examples to
illustrate the structure of the package.

## `Config`

A `Config` object contains functionality for interacting with YAML
configuration files (under `inst/config`) that specify the schemas,
types, patterns and field descriptions for the *raw* input *files* and
*tidy* output *tbls*. See
[`?Config`](https://umccr.github.io/nemo/dev/reference/Config.md).

### raw

- intro
- patterns
- descriptions
- versions
- schemas

Let’s look at some of the information for the raw `Tool1` config, for
instance:

``` r
tool <- params$tool
workflow <- params$workflow
conf <- Config$new(tool, pkg = "nemo")
conf
```

    ## #--- Config tool1 ---#
    ## 
    ## |var   |value |
    ## |:-----|:-----|
    ## |tool  |tool1 |
    ## |nraw  |4     |
    ## |ntidy |4     |

You can access the individual fields in the classic R list-like manner,
using the `$` sign.

Patterns are used to fish out the relevant files from a directory
listing.

``` r
conf$get_raw_patterns() |>
  knitr::kable(caption = glue("{tool} raw file patterns."))
```

| name   | value               |
|:-------|:--------------------|
| table1 | .tool1.table1.tsv\$ |
| table2 | .tool1.table2.tsv\$ |
| table3 | .tool1.table3.tsv\$ |

Tool1 raw file patterns.

File descriptions are based on the available open source documentation.

``` r
conf$get_raw_descriptions() |>
  knitr::kable(caption = glue("{tool} raw file descriptions."))
```

| name   | value                        |
|:-------|:-----------------------------|
| table1 | Table1 raw file.             |
| table2 | Table2 raw file.             |
| table3 | Table3 raw file (no header). |

Tool1 raw file descriptions.

Versions are used to distinguish changes in schema between individual
tool versions. For example, after `Tool1` v1.2.3 metrics Y and Z were
added to `table1`, which is reflected in the available schemas. For now
we are using `latest` as a default version based on the most recent
schema tests, and any discrepancies we see are labelled accordingly by
the version of the tool that generated a file with a different schema.

``` r
conf$get_raw_versions() |>
  knitr::kable(caption = glue("{tool} raw file versions."))
```

| name   | value  |
|:-------|:-------|
| table1 | v1.2.3 |
| table1 | latest |
| table2 | latest |
| table3 | latest |

Tool1 raw file versions.

The raw schemas specify the column name and type (e.g. character (`c`),
integer (`i`), float/double (`d`)) for each input file:

``` r
(s <- conf$get_raw_schemas_all())
```

    ## # A tibble: 4 × 4
    ##   name   tbl_description              version schema          
    ##   <chr>  <chr>                        <chr>   <list>          
    ## 1 table1 Table1 raw file.             v1.2.3  <tibble [5 × 2]>
    ## 2 table1 Table1 raw file.             latest  <tibble [7 × 2]>
    ## 3 table2 Table2 raw file.             latest  <tibble [3 × 2]>
    ## 4 table3 Table3 raw file (no header). latest  <tibble [5 × 2]>

``` r
s |>
  dplyr::filter(name == "table1", version == "v1.2.3") |>
  dplyr::select("schema") |>
  tidyr::unnest("schema")
```

    ## # A tibble: 5 × 2
    ##   field      type 
    ##   <chr>      <chr>
    ## 1 SampleID   c    
    ## 2 Chromosome c    
    ## 3 Start      i    
    ## 4 End        i    
    ## 5 metricX    d

### tidy

- intro
- descriptions
- schemas

Now let’s look at some of the information in the tidy `Tool1` config.
The difference between raw and tidy configs is mostly in the column
names (they are standardised to lowercase separated by underscores,
i.e. `snake_case`), and some raw files get split into multiple tidy
tables (e.g. for normalisation purposes).

Tidy descriptions are the same as the raw descriptions for now.

``` r
conf$get_tidy_descriptions() |>
  knitr::kable(caption = glue("{tool} tidy file descriptions."))
```

| name   | value               |
|:-------|:--------------------|
| table1 | Table1 tidy output. |
| table2 | Table2 tidy output. |
| table3 | Table3 tidy output. |

Tool1 tidy file descriptions.

``` r
(s <- conf$get_tidy_schemas_all())
```

    ## # A tibble: 4 × 5
    ##   name   tbl_description     version tbl   schema          
    ##   <chr>  <chr>               <chr>   <chr> <list>          
    ## 1 table1 Table1 tidy output. v1.2.3  tbl1  <tibble [5 × 3]>
    ## 2 table1 Table1 tidy output. latest  tbl1  <tibble [7 × 3]>
    ## 3 table2 Table2 tidy output. latest  tbl1  <tibble [3 × 3]>
    ## 4 table3 Table3 tidy output. latest  tbl1  <tibble [5 × 3]>

``` r
s |>
  dplyr::filter(.data$name == "table1", version == "v1.2.3") |>
  dplyr::select("schema") |>
  tidyr::unnest("schema")
```

    ## # A tibble: 5 × 3
    ##   field      type  description   
    ##   <chr>      <chr> <chr>         
    ## 1 sample_id  c     Sample ID     
    ## 2 chromosome c     Chromosome    
    ## 3 start      i     Start position
    ## 4 end        i     End position  
    ## 5 metric_x   d     Metric X

## `Tool`

`Tool` is the main organisation class for all file parsers and tidiers.
It contains functions for parsing and tidying typical CSV/TSV files
(with column names), and TXT files where the column names are missing.
Currently it utilises the very simple
[`readr::read_delim`](https://readr.tidyverse.org/reference/read_delim.html)
function from the {[readr](https://github.com/tidyverse/readr "readr")}
package that reads all the data into memory. See
[`?Tool`](https://umccr.github.io/nemo/dev/reference/Tool.md).

These simple parsers are used in 80-90% of cases, so in the future we
can optimise the parsing if needed with faster packages such as
{[data.table](https://github.com/Rdatatable/data.table "data.table")},
{[duckdb-r](https://github.com/duckdb/duckdb-r "duckdb-r")}/{[duckplyr](https://github.com/tidyverse/duckplyr "duckplyr")}
or {[r-polars](https://github.com/pola-rs/r-polars "r-polars")}.

- initialise
- config
- list
- tidy
- filter
- write
- nemofy

We can have different `Tool` children classes that inherit (or override)
functions and fields from the `Tool` parent class. For example, we can
create a `Tool` object for `Tool1` as follows:

- Initialise a `Tool1` object:

``` r
tool1_path <- system.file("extdata/tool1", package = "nemo")
t1 <- nemo::Tool1$new(path = tool1_path)
# each class comes with a print function
t1
```

    ## #--- Tool tool1 ---#
    ## 
    ## |var     |value                                                                     |
    ## |:-------|:-------------------------------------------------------------------------|
    ## |name    |tool1                                                                     |
    ## |path    |/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/nemo/extdata/tool1 |
    ## |files   |4                                                                         |
    ## |tidied  |FALSE                                                                     |
    ## |written |FALSE                                                                     |

- Its `Config` object is also constructed based on the `name` supplied -
  this is used internally to find files of interest and infer their
  schemas:

``` r
t1$config
```

    ## #--- Config tool1 ---#
    ## 
    ## |var   |value |
    ## |:-----|:-----|
    ## |tool  |tool1 |
    ## |nraw  |4     |
    ## |ntidy |4     |

``` r
t1$config$get_raw_patterns()
```

    ## # A tibble: 3 × 2
    ##   name   value                     
    ##   <chr>  <chr>                     
    ## 1 table1 "\\.tool1\\.table1\\.tsv$"
    ## 2 table2 "\\.tool1\\.table2\\.tsv$"
    ## 3 table3 "\\.tool1\\.table3\\.tsv$"

``` r
t1$config$get_raw_schema("table1", v = "v1.2.3")
```

    ## # A tibble: 5 × 5
    ##   name   tbl_description  version field      type 
    ##   <chr>  <chr>            <chr>   <chr>      <chr>
    ## 1 table1 Table1 raw file. v1.2.3  SampleID   c    
    ## 2 table1 Table1 raw file. v1.2.3  Chromosome c    
    ## 3 table1 Table1 raw file. v1.2.3  Start      i    
    ## 4 table1 Table1 raw file. v1.2.3  End        i    
    ## 5 table1 Table1 raw file. v1.2.3  metricX    d

``` r
# t1$config$get_raw_schema("table1", v = "latest") # default
t1$config$get_tidy_schema("table1", v = "v1.2.3")
```

    ## # A tibble: 5 × 7
    ##   name   tbl_description     version tbl   field      type  description   
    ##   <chr>  <chr>               <chr>   <chr> <chr>      <chr> <chr>         
    ## 1 table1 Table1 tidy output. v1.2.3  tbl1  sample_id  c     Sample ID     
    ## 2 table1 Table1 tidy output. v1.2.3  tbl1  chromosome c     Chromosome    
    ## 3 table1 Table1 tidy output. v1.2.3  tbl1  start      i     Start position
    ## 4 table1 Table1 tidy output. v1.2.3  tbl1  end        i     End position  
    ## 5 table1 Table1 tidy output. v1.2.3  tbl1  metric_x   d     Metric X

``` r
# t1$config$get_tidy_schema("table1", v = "latest") # default
```

We can list files that can be parsed with `list_files()`:

``` r
(lf <- t1$list_files())
```

    ## # A tibble: 4 × 9
    ##   tool_parser  parser bname                      size lastmodified        path  pattern prefix group
    ##   <glue>       <chr>  <chr>                    <fs::> <dttm>              <chr> <chr>   <glue> <glu>
    ## 1 tool1_table1 table1 sampleA.tool1.table1.tsv    113 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 2 tool1_table1 table1 sampleA.tool1.table1.tsv    153 2026-02-26 12:58:08 /hom… "\\.to… sampl… _2   
    ## 3 tool1_table2 table2 sampleA.tool1.table2.tsv     70 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 4 tool1_table3 table3 sampleA.tool1.table3.tsv     83 2026-02-26 12:58:08 /hom… "\\.to… sampl…

``` r
lf |> dplyr::slice(1) |> str()
```

    ## tibble [1 × 9] (S3: tbl_df/tbl/data.frame)
    ##  $ tool_parser : 'glue' chr "tool1_table1"
    ##  $ parser      : chr "table1"
    ##  $ bname       : chr "sampleA.tool1.table1.tsv"
    ##  $ size        : 'fs_bytes' num 113
    ##  $ lastmodified: POSIXct[1:1], format: "2026-02-26 12:58:08"
    ##  $ path        : chr "/home/runner/miniconda3/envs/pkgdown_env/lib/R/library/nemo/extdata/tool1/v1.2.3/sampleA.tool1.table1.tsv"
    ##  $ pattern     : chr "\\.tool1\\.table1\\.tsv$"
    ##  $ prefix      : 'glue' chr "sampleA"
    ##  $ group       : 'glue' chr ""

We can parse and tidy files of interest using the `tidy` function. Note
that this function is called on the object and not assigned anywhere:

``` r
# this will create a new field tbls containing the tidy data (and optionally
# the 'raw' parsed data)
t1$tidy(tidy = TRUE, keep_raw = TRUE)
t1$tbls
```

    ## # A tibble: 4 × 11
    ##   tool_parser  parser bname    size lastmodified        path  pattern prefix group raw      tidy    
    ##   <glue>       <chr>  <chr>   <fs:> <dttm>              <chr> <chr>   <glue> <glu> <list>   <list>  
    ## 1 tool1_table1 table1 sample…   113 2026-02-26 12:58:08 /hom… "\\.to… sampl…       <tibble> <tibble>
    ## 2 tool1_table1 table1 sample…   153 2026-02-26 12:58:08 /hom… "\\.to… sampl… _2    <tibble> <tibble>
    ## 3 tool1_table2 table2 sample…    70 2026-02-26 12:58:08 /hom… "\\.to… sampl…       <tibble> <tibble>
    ## 4 tool1_table3 table3 sample…    83 2026-02-26 12:58:08 /hom… "\\.to… sampl…       <tibble> <tibble>

``` r
t1$tbls$raw[[1]] |> dplyr::glimpse()
```

    ## Rows: 3
    ## Columns: 5
    ## $ SampleID   <chr> "sampleA", "sampleA", "sampleA"
    ## $ Chromosome <chr> "chr1", "chr2", "chr3"
    ## $ Start      <int> 10, 100, 1000
    ## $ End        <int> 50, 500, 5000
    ## $ metricX    <dbl> 0.1, 0.2, 0.3

``` r
# the tidy tibbles are nested to allow for more than one tidy tibble per file
t1$tbls$tidy[[1]][["data"]][[1]] |> dplyr::glimpse()
```

    ## Rows: 3
    ## Columns: 5
    ## $ sample_id  <chr> "sampleA", "sampleA", "sampleA"
    ## $ chromosome <chr> "chr1", "chr2", "chr3"
    ## $ start      <int> 10, 100, 1000
    ## $ end        <int> 50, 500, 5000
    ## $ metric_x   <dbl> 0.1, 0.2, 0.3

We can also focus on a subset of files to tidy using the
`filter_files()` function. The `include` and `exclude` arguments can
specify which parsers to include or exclude in the analysis:

``` r
# create new Tool1 object
t2 <- nemo::Tool1$new(path = tool1_path)
t2$files
```

    ## # A tibble: 4 × 9
    ##   tool_parser  parser bname                      size lastmodified        path  pattern prefix group
    ##   <glue>       <chr>  <chr>                    <fs::> <dttm>              <chr> <chr>   <glue> <glu>
    ## 1 tool1_table1 table1 sampleA.tool1.table1.tsv    113 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 2 tool1_table1 table1 sampleA.tool1.table1.tsv    153 2026-02-26 12:58:08 /hom… "\\.to… sampl… _2   
    ## 3 tool1_table2 table2 sampleA.tool1.table2.tsv     70 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 4 tool1_table3 table3 sampleA.tool1.table3.tsv     83 2026-02-26 12:58:08 /hom… "\\.to… sampl…

``` r
t2$filter_files(include = c("tool1_table2", "tool1_table3"))
t2$files
```

    ## # A tibble: 2 × 9
    ##   tool_parser  parser bname                      size lastmodified        path  pattern prefix group
    ##   <glue>       <chr>  <chr>                    <fs::> <dttm>              <chr> <chr>   <glue> <glu>
    ## 1 tool1_table2 table2 sampleA.tool1.table2.tsv     70 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 2 tool1_table3 table3 sampleA.tool1.table3.tsv     83 2026-02-26 12:58:08 /hom… "\\.to… sampl…

After tidying the data of interest, we can write the tidy tibbles to
various formats, like Apache Parquet, PostgreSQL, CSV/TSV and R’s RDS.
Below we can see that the `id` specified is added to the written files
in an additional `nemo_id` column. This can be used e.g. to distinguish
results from different runs in a data pipeline. When writing to a
database like PostgreSQL, another column `nemo_pfix` is used to
distinguish results from the same run from the same tool.

``` r
t2$tidy() # first need to tidy
outdir1 <- tempdir()
fmt <- "csv"
t2$write(diro = outdir1, format = fmt, input_id = "run123")
wfiles <- fs::dir_info(outdir1) |> dplyr::select(1:5)
wfiles |>
  dplyr::mutate(bname = basename(.data$path)) |>
  dplyr::select("bname", "size", "type")
```

    ## # A tibble: 18 × 3
    ##    bname                                 size type 
    ##    <chr>                          <fs::bytes> <fct>
    ##  1 file127e2091c927                     4.71K file 
    ##  2 file127e21b50323                     4.71K file 
    ##  3 file127e2640bdab                     4.71K file 
    ##  4 file127e2f36201f                     4.71K file 
    ##  5 file127e31ddf7e9                     4.71K file 
    ##  6 file127e34e730ff                     4.71K file 
    ##  7 file127e3a45a62c                     4.71K file 
    ##  8 file127e3f3376f8                     4.71K file 
    ##  9 file127e4116d3ea                     4.71K file 
    ## 10 file127e5e447932                     4.71K file 
    ## 11 file127e635cd5dc                     4.71K file 
    ## 12 file127e6f8a583e                     4.71K file 
    ## 13 file127e70151728                     4.71K file 
    ## 14 file127e777dbf4c                     4.71K file 
    ## 15 file127e785c8a9b                     4.71K file 
    ## 16 rmarkdown-str127e58a6fc3e.html       1.13K file 
    ## 17 sampleA_tool1_table2.csv.gz            123 file 
    ## 18 sampleA_tool1_table3.csv.gz            134 file

``` r
# readr::read_csv(wfiles$path[1], show_col_types = F) # see bug #137
```

The `nemofy` function is a convenient wrapper for the process of
filtering, tidying, and writing.

``` r
t3 <- nemo::Tool1$new(path = tool1_path)
outdir2 <- file.path(tempdir(), "t3") |> fs::dir_create()
t3$files
```

    ## # A tibble: 4 × 9
    ##   tool_parser  parser bname                      size lastmodified        path  pattern prefix group
    ##   <glue>       <chr>  <chr>                    <fs::> <dttm>              <chr> <chr>   <glue> <glu>
    ## 1 tool1_table1 table1 sampleA.tool1.table1.tsv    113 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 2 tool1_table1 table1 sampleA.tool1.table1.tsv    153 2026-02-26 12:58:08 /hom… "\\.to… sampl… _2   
    ## 3 tool1_table2 table2 sampleA.tool1.table2.tsv     70 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 4 tool1_table3 table3 sampleA.tool1.table3.tsv     83 2026-02-26 12:58:08 /hom… "\\.to… sampl…

``` r
t3$nemofy(
  diro = outdir2,
  format = "tsv",
  input_id = "run_t3"
)
wfiles2 <- fs::dir_info(outdir2) |>
  dplyr::mutate(bname = basename(.data$path))
wfiles2 |>
  dplyr::select("bname", "size", "type")
```

    ## # A tibble: 4 × 3
    ##   bname                                size type 
    ##   <chr>                         <fs::bytes> <fct>
    ## 1 sampleA_2_tool1_table1.tsv.gz         171 file 
    ## 2 sampleA_tool1_table1.tsv.gz           150 file 
    ## 3 sampleA_tool1_table2.tsv.gz           123 file 
    ## 4 sampleA_tool1_table3.tsv.gz           134 file

``` r
readr::read_tsv(wfiles2$path[2], show_col_types = F)
```

    ## # A tibble: 3 × 8
    ##   input_id input_pfix output_id                  sample_id chromosome start   end metric_x
    ##   <chr>    <chr>      <chr>                      <chr>     <chr>      <dbl> <dbl>    <dbl>
    ## 1 run_t3   sampleA    01KJD0J0M0VWP0GMB665K10RZR sampleA   chr1          10    50      0.1
    ## 2 run_t3   sampleA    01KJD0J0M0VWP0GMB665K10RZR sampleA   chr2         100   500      0.2
    ## 3 run_t3   sampleA    01KJD0J0M0VWP0GMB665K10RZR sampleA   chr3        1000  5000      0.3

## `Workflow`

A `Workflow` consists of a list of one or more `Tool`s. We can construct
a certain `Workflow` with different `Tool`s, which would allow parsing
and writing tidy tables from a variety of bioinformatic tools. See
[`?Workflow`](https://umccr.github.io/nemo/dev/reference/Workflow.md).

For example, {nemo} contains a `Workflow1` class as a `Workflow` child
(containing only a single `Tool1` for simplicity). Similarly to `Tool`,
a `Workflow` object contains functions such as `filter_files`,
`list_files`, `tidy`, `write` and `nemofy`:

``` r
w <- system.file("extdata/tool1", package = "nemo") |>
  nemo::Workflow1$new()
outdir3 <- file.path(tempdir(), "oa") |> fs::dir_create()
w$list_files()
```

    ## # A tibble: 4 × 9
    ##   tool_parser  parser bname                      size lastmodified        path  pattern prefix group
    ##   <glue>       <chr>  <chr>                    <fs::> <dttm>              <chr> <chr>   <glue> <glu>
    ## 1 tool1_table1 table1 sampleA.tool1.table1.tsv    113 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 2 tool1_table1 table1 sampleA.tool1.table1.tsv    153 2026-02-26 12:58:08 /hom… "\\.to… sampl… _2   
    ## 3 tool1_table2 table2 sampleA.tool1.table2.tsv     70 2026-02-26 12:58:08 /hom… "\\.to… sampl…      
    ## 4 tool1_table3 table3 sampleA.tool1.table3.tsv     83 2026-02-26 12:58:08 /hom… "\\.to… sampl…

``` r
x <- w$nemofy(
  diro = outdir3,
  format = "tsv",
  input_id = "workflow1_run1"
)
wfiles3 <- fs::dir_info(outdir3) |>
  dplyr::select(1:5) |>
  dplyr::mutate(bname = basename(.data$path))
wfiles3 |>
  dplyr::select("bname", "size", "type")
```

    ## # A tibble: 5 × 3
    ##   bname                                size type 
    ##   <chr>                         <fs::bytes> <fct>
    ## 1 metadata.json                         806 file 
    ## 2 sampleA_2_tool1_table1.tsv.gz         176 file 
    ## 3 sampleA_tool1_table1.tsv.gz           156 file 
    ## 4 sampleA_tool1_table2.tsv.gz           131 file 
    ## 5 sampleA_tool1_table3.tsv.gz           140 file
