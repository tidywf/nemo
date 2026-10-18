tool1 <- list(
  # tsv: header present, tab-delimited
  table1 = list(
    list(
      version = "v1.2.3",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        Chromosome = c("chr1", "chr2", "chr3"),
        Start = c(10, 100, 1000),
        End = c(50, 500, 5000),
        metricX = c(0.1, 0.2, 0.3)
      )
    ),
    list(
      version = "v4.5.6",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        Chromosome = c("chr1", "chr2", "chr3"),
        Start = c(10, 100, 1000),
        End = c(50, 500, 5000)
      )
    ),
    list(
      version = "latest",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        Chromosome = c("chr1", "chr2", "chr3"),
        Start = c(10, 100, 1000),
        End = c(50, 500, 5000),
        metricY = c(0.4, 0.5, 0.6),
        metricZ = c(0.7, 0.8, 0.9)
      )
    )
  ),
  # tsv: header present, tab-delimited (simpler, single version)
  table2 = list(
    list(
      version = "v1.0.0",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        metricA = c("a", "b", "c")
      )
    ),
    list(
      version = "latest",
      format = "tsv",
      data = tibble::tibble(
        SampleID = "sampleA",
        metricA = c("a", "b", "c"),
        metricB = c(12.3, 4.56, 7.89)
      )
    )
  ),
  # keyvalue: two-column key=value pairs, tab-delimited, no header, pivots to single-row tibble
  table3 = list(
    list(
      version = "v1.0.0",
      format = "keyvalue",
      delim = "\t",
      data = tibble::tribble(
        ~key         , ~value    ,
        "SampleID"   , "sampleA" ,
        "QCStatus"   , "Pass"    ,
        "TotalReads" , "10000"
      )
    ),
    list(
      version = "latest",
      format = "keyvalue",
      delim = "\t",
      data = tibble::tribble(
        ~key            , ~value    ,
        "SampleID"      , "sampleA" ,
        "QCStatus"      , "Pass"    ,
        "TotalReads"    , "10000"   ,
        "MappedReads"   , "9500"    ,
        "UnmappedReads" , "500"
      )
    )
  ),
  # tsv-nohead: no header, positional columns, tab-delimited
  table4 = list(
    list(
      version = "v1.0.0",
      format = "tsv-nohead",
      data = tibble::tibble(
        SampleID = c("sampleA", "sampleB"),
        Chromosome = c("chr1", "chr2"),
        Start = c(100L, 200L)
      )
    ),
    list(
      version = "latest",
      format = "tsv-nohead",
      data = tibble::tibble(
        SampleID = c("sampleA", "sampleB"),
        Chromosome = c("chr1", "chr2"),
        Start = c(100L, 200L),
        End = c(500L, 800L),
        Depth = c(32.5, 18.1)
      )
    )
  ),
  # csv: header present, comma-delimited
  table6 = list(
    list(
      version = "v1.0.0",
      format = "csv",
      data = tibble::tibble(
        GeneId = c("ENSG001", "ENSG002", "ENSG003"),
        GeneName = c("BRCA1", "TP53", "EGFR"),
        AdjTPM = c(12.3, 45.6, 7.89)
      )
    ),
    list(
      version = "latest",
      format = "csv",
      data = tibble::tibble(
        GeneId = c("ENSG001", "ENSG002", "ENSG003"),
        GeneName = c("BRCA1", "TP53", "EGFR"),
        AdjTPM = c(12.3, 45.6, 7.89),
        RawTPM = c(11.1, 44.4, 6.66)
      )
    )
  ),
  # tsv: one wide row, split into two schema outputs (table7main, table7dp).
  # Own dir so the extdata/tool1 tests don't pick it up.
  table7 = list(
    list(
      version = "v1.0.0",
      format = "tsv",
      dir = "tool1_outputs",
      data = tibble::tibble(
        SampleID = "sampleA",
        TotalReads = 800,
        DepthCov_10 = 0.97,
        DepthCov_20 = 0.88,
        DepthCov_30 = 0.7
      )
    ),
    list(
      version = "latest",
      format = "tsv",
      dir = "tool1_outputs",
      data = tibble::tibble(
        SampleID = "sampleA",
        TotalReads = 1000,
        MappedReads = 950,
        DepthCov_10 = 0.98,
        DepthCov_20 = 0.9,
        DepthCov_30 = 0.75
      )
    )
  )
)

purrr::map2(tool1, names(tool1), \(tab, tab_name) {
  stopifnot(length(tab_name) == 1)
  purrr::map(tab, \(entry) {
    odir <- here::here("inst/extdata", entry$dir %||% "tool1", entry$version) |>
      fs::dir_create()
    if (entry$format == "csv") {
      fname <- file.path(odir, glue::glue("sampleA.tool1.{tab_name}.csv"))
      readr::write_csv(entry$data, fname, col_names = TRUE, na = "NA")
    } else {
      fname <- file.path(odir, glue::glue("sampleA.tool1.{tab_name}.tsv"))
      has_header <- entry$format == "tsv"
      readr::write_tsv(entry$data, fname, col_names = has_header, na = "NA")
    }
  })
})
