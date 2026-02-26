# NEWS

## dev (2026-02-26)

- Add support for LinkML schemas
  ([pr33](https://github.com/umccr/nemo/pull/33),
  [iss22](https://github.com/umccr/nemo/issues/22))
- GitHub Actions: refactor deploy workflow for dev and main branches
  ([pr34](https://github.com/umccr/nemo/pull/34))

## v0.0.3 (2026-02-09)

- `nemo_write`: use NA outpath attr for db

## v0.0.2 (2026-02-04)

- Add key-value parser ([pr12](https://github.com/umccr/nemo/pull/12),
  [iss11](https://github.com/umccr/nemo/issues/11))
- Export config writer ([pr13](https://github.com/umccr/nemo/pull/13))
- Add table description to schema getters, contribution docs, pkgdown
  fixes ([pr19](https://github.com/umccr/nemo/pull/19))
- Add `nemo_id` + `nemo_pfix` in class writer
  ([pr21](https://github.com/umccr/nemo/pull/21),
  [iss18](https://github.com/umccr/nemo/issues/18))
  - changed odir to diro arg in nemofy
- list_files: `str_remove` offers more flexibility
  ([pr24](https://github.com/umccr/nemo/pull/24),
  [iss23](https://github.com/umccr/nemo/issues/23))
- Add metadata export functionality
  ([pr25](https://github.com/umccr/nemo/pull/25),
  [iss17](https://github.com/umccr/nemo/issues/17))
  - rename `nemo_id` + `nemo_pfix` to `input_id` + `input_pfix`,
    respectively
  - add `output_id`
- Bugfix: use [`I()`](https://rdrr.io/r/base/AsIs.html) for vroom
  literal data in `empty_tbl`
  ([iss27](https://github.com/umccr/nemo/issues/27),
  [pr28](https://github.com/umccr/nemo/pull/28))

## v0.0.1 (2025-09-07)

Initial release of nemo ([pr5](https://github.com/umccr/nemo/pull/5))

- R pkg skeleton
- Documentation via pkgdown
- CLI
- Logger
- GitHub Actions CI/CD

Fixing issues [iss2](https://github.com/umccr/nemo/issues/2),
[iss3](https://github.com/umccr/nemo/issues/3) and
[iss4](https://github.com/umccr/nemo/issues/4)
