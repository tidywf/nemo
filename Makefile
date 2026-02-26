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

bump:
ifndef VERSION
	$(error VERSION is not set. Usage: make bump VERSION=x.y.z)
endif
	$(eval OLD_VERSION := $(shell grep '^Version:' DESCRIPTION | awk '{print $$2}'))
	@bump-my-version bump --new-version $(VERSION)
	@$(MAKE) --no-print-directory build-readme
	@git add .
	@git commit -m "Bump version: $(OLD_VERSION) => $(VERSION)"
