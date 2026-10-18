.PHONY: all pkgdown test check-pushed bump fmt

air:
	@air format .

# format tracked files changed vs HEAD with the local air + panache (same file
# types and excludes as the pre-commit hooks; versions may differ from the pins)
fmt:
	@files=$$(git diff --name-only --diff-filter=d HEAD); \
	rfiles=$$(printf '%s\n' $$files | grep -E '\.[Rr]$$'); \
	mdfiles=$$(printf '%s\n' $$files | grep -E '\.(qmd|Rmd|md|markdown|mdown|mkd)$$'); \
	if [ -z "$$rfiles$$mdfiles" ]; then echo "fmt: no changed R/Markdown files"; fi; \
	if [ -n "$$rfiles" ]; then \
		if command -v air >/dev/null 2>&1; then air format $$rfiles; \
		else echo "fmt: air not found, skipping R files"; fi; \
	fi; \
	if [ -n "$$mdfiles" ]; then \
		if command -v panache >/dev/null 2>&1; then panache format --force-exclude $$mdfiles; \
		else echo "fmt: panache not found, skipping Markdown files"; fi; \
	fi

readme:
	@quarto render README.qmd

pkgdown:
	@R -e "pkgdown::build_site()" --quiet --no-restore --no-save

readme-pkgdown: readme pkgdown

roxydoc:
	@R -e "devtools::document()" --quiet --no-restore --no-save

install:
	@R CMD INSTALL --no-multiarch .

install-readme: install readme

test: fmt
	@R -e "devtools::test()" --quiet --no-restore --no-save

check:
	@R -e "devtools::check()" --quiet --no-restore --no-save

full: roxydoc test install check

check-pushed:
ifndef BRANCH
	$(error BRANCH is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
	@git fetch --quiet origin $(BRANCH)
	@unpushed=$$(git rev-list --count origin/$(BRANCH)..$(BRANCH)); \
	if [ "$$unpushed" -ne 0 ]; then \
		echo "Error: $$unpushed local commit(s) on '$(BRANCH)' not pushed to origin. Push before bumping."; \
		exit 1; \
	fi
	@echo "'$(BRANCH)' is in sync with origin."

bump: check-pushed
ifndef VERSION
	$(error VERSION is not set. Usage: make bump VERSION=x.y.z BRANCH=dev)
endif
	@gh workflow run bump.yaml --ref $(BRANCH) --field version=$(VERSION)

