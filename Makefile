.PHONY: all pkgdown

readme:
	@quarto render README.qmd

air:
	@air format

pkgdown:
	@R -e "pkgdown::build_site()" --quiet --no-restore --no-save

readme-pkgdown: readme pkgdown

roxydoc:
	@R -e "devtools::document()" --quiet --no-restore --no-save

build:
	@R -e "pak::local_install(upgrade = FALSE, dependencies = FALSE)" --quiet --no-restore --no-save

build-readme: build readme
