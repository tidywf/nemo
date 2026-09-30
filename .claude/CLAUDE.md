# CLAUDE.md --- nemo

Base R package providing R6 classes (`Tool`, `Workflow`, `Config`) inherited by
all tidywf parsing R packages. For deep context use the routing table in
`tidywf/.claude/CLAUDE.md` --- auto-loaded by Claude Code from the parent
directory.

## Structure

```
nemo
├── air.toml                       # config for code formatting
├── data-raw/fake_tool1.R          # for example data construction
├── deploy/conda                   # conda: envs for CI, recipe with deps for R pkg, lock file
├── DESCRIPTION                    # keep in sync with conda recipe deps
├── inst
│   ├── cli/nemo.R                 # cli entry point
│   ├── config/<...>/schema.yaml   # example schema config
│   ├── doc-templates              # documentation templates in qmd/md, used in docs, README and other child pkgs
│   ├── extdata                    # example data for tests and CI, loaded via system.file(), one dir per tool
│   └── scripts                    # for random scripts
├── Makefile                       # Makefile, keep repetitive commands in here
├── man                            # ignore (Rd files)
├── NAMESPACE                      # NAMESPACE
├── nogit                          # ignore
├── pkgdown                        # pkgdown config and extra.scss
├── R                              # R code
├── README.qmd                     # README.md gets rendered via this
├── README.md                      # do not edit this, see README.qmd
├── tests                          # test scripts
└── vignettes                      # articles for pkgdown website
```

## Reference implementations

`Tool1` (`R/Tool1.R`) and `Workflow1` (`R/Workflow1.R`) are the canonical
examples --- follow these when creating new tools or workflows. They demonstrate
the full pattern: schema config, file discovery, raw parsing, and tidy output.

## ftypes (`schema.yaml` → `parse_by_ftype`)

Built-in ftypes handled by `Tool$parse_by_ftype()`:

| ftype          | parser                | delimiter |
| -------------- | --------------------- | --------- |
| `tsv`          | `parse_file`          | `\t`      |
| `csv`          | `parse_file`          | `,`       |
| `tsv-nohead`   | `parse_file_nohead`   | `\t`      |
| `tsv-keyvalue` | `parse_file_keyvalue` | `\t`      |

Child packages add pkg-specific ftypes by overriding `private$extra_ftypes()` ---
return a named list of `ftype -> function(x, table_name)`. Checked before the
switch; unknown ftypes fall through to `nemo_stop`.

## Subclass hooks

Extension points a `Tool` subclass may override in `private`:

- `extra_ftypes()` --- register pkg-specific ftype parsers (see above).
- `refine_files(files)` --- adjust the matched-files tibble inside
  `compute_files()`, applied to the **base prefix before** the disambiguation
  passes. Use it to fold a semantic distinction (e.g. germline/somatic) into
  `prefix` so those files no longer collide and don't pick up a spurious
  `_2`/`_3`. Receives
  `parser/bname/size/lastmodified/path/pattern/prefix/tool_parser`; default is a
  no-op. `Linx`/`Purple`/`Sage` in tidywigits and `DragenTool`/`DragenBcl`/
  `DragenTso`/`Interop` in tidydragen override it.

## Critical gotchas

- TODO tracked in `.claude/TODO.md`
- Schema methods (`get_schema_raw`, `get_schema_tidy`, `get_col_map`) live on
  `Config`, not `Tool`. In subclass `tidy_*` methods use
  `self$config$get_col_map(...)`
- Use accessor methods, not direct field access: `list_files()` not `$files`,
  `get_tbls()` not `$tbls`.

## Key API (`R/`)

| Function                                      | File           | Purpose                                                                           |
| --------------------------------------------- | -------------- | --------------------------------------------------------------------------------- |
| `nemo_write(d, fpfix, format, dbconn, dbtab)` | `write.R`      | Dispatches to correct writer by format                                            |
| `nemo_osfx(fpfix, format)`                    | `write.R`      | Constructs output path with right extension                                       |
| `nemo_out_formats()`                          | `write.R`      | Returns valid format strings: `parquet`, `db`, `tsv`, `csv`, `rds`                |
| `nemo_metadata(files, pkgs, ...)`             | `metadata.R`   | Assembles run-level metadata as a single-row tibble written to `metadata.parquet` |
| `nemo_schema_reactable(tools, pkg, ...)`      | `schema_vis.R` | Interactive reactable schema explorer                                             |
| `nemo_schemavis_data(tools, pkg)`             | `schema_vis.R` | Per-table schema tibble (versions, columns); internal, not exported               |
| `nemo_gha_mermaid(actions_url, deploy_yaml)`  | `gha.R`        | Builds Mermaid CI/CD flowchart from local + remote YAML                           |
| `nemo_uml()`                                  | `uml.R`        | Generates PlantUML SVG from R6 class names                                        |
| `nemo_enframe(x)`                             | `utils.R`      | Named list of tibbles → `name`/`data` tibble; used for 1-file → N-table fan-out   |
| `nemoverse_wf_dispatch(wf)`                   | `utils.R`      | Workflow name (`wigits`/`dragen`/`workflow1`) → workflow class                    |
| `read_parquet_grep(odir, lf, pattern, first)` | `utils.R`      | Read the one parquet in `lf` matching `pattern` (used in `@testexamples`)         |
| `wf_sync_patterns(workflow)`                  | `sync.R`       | Include/exclude tibble for `aws s3 sync`, built from schema `glob` fields         |
| `schema_glob_check(pkg, fixture_dir)`         | `sync.R`       | Fixture files a `pattern` matches but no `glob` covers (0 rows = consistent)      |
| `s3sync(src, dest, pats, workflow, dryrun)`   | `s3.R`         | `aws s3 sync` wrapper; `workflow` pulls patterns from `wf_sync_patterns()`        |

## CLI (`R/cli.R`, `inst/cli/nemo.R`)

Built with `argparse` via `nemo_cli()`. Three subcommands:

| Subcommand | Key args                         | What it does                                                   |
| ---------- | -------------------------------- | -------------------------------------------------------------- |
| `list`     | `-d IN_DIR -f FORMAT -m MAX`     | Lists parsable files; output as `pretty` or `tsv`              |
| `tidy`     | `-d IN_DIR -o OUT_DIR -f FORMAT` | Runs `run()` and writes tidy outputs                           |
| `sync`     | `-s S3_SRC -d DEST`              | `s3sync()` with the workflow's schema-derived include patterns |

All accept `-w WORKFLOW` (omitted when the child CLI fixes `wf`) and `-q`
(quiet). `sync` also accepts `--dryrun` and `--show_patterns` (print the
patterns and exit). `tidy` also accepts:

- `--input_id` --- adds an `input_id` column to all output tables
- `--output_id` / `--ulid` --- adds an `output_id` column (mutually exclusive;
  `--ulid` generates one automatically)
- `--prefix_include` --- adds an `input_prefix` column derived from the input
  filename prefix
- `--include`/`--exclude` --- filter tool parsers (comma-separated)
- `--dbname`/`--dbuser` --- required when `--format db`

## Logging (`R/log.R`)

`log4r`-based, initialised in `.onLoad`. Env vars:

- `NEMO_LOG_ENABLE` --- "FALSE" to disable (default "TRUE")
- `NEMO_LOG_LEVEL` --- "DEBUG", "INFO" (default), "WARN", "ERROR", "FATAL"

Public API: `nemo_log(level, msg, ...)` (sprintf-style), `nemo_log_date()`.

## Testing

See `tidywf/docs/r-pkg/testing.md` for the two-tier convention (manual R6 tests
vs roxytest-generated). Manually-tested classes here: `Tool`, `Tool1`,
`Workflow`, `Workflow1`, `Config`.

## Dev commands

Full Makefile target list (shared with tidywigits/tidydragen):
`tidywf/docs/r-pkg/dev-commands.md`.

`devtools::load_all()` (no make equivalent) to load package interactively:

```r
devtools::load_all()

path <- system.file("extdata/tool1", package = "nemo")
wf <- Workflow$new(name = "test_wf", path = path, tools = list(tool1 = Tool1))
wf$run(output_dir = tempdir(), format = "parquet", input_id = "run1")
```
