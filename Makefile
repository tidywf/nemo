.PHONY: all pkgdown test check-pushed bump fmt

air:
	@air format .

# format tracked files changed vs HEAD with the pre-commit hooks' pinned
# air + panache, so the commit hooks find nothing left to reformat
fmt:
	@files=$$(git diff --name-only --diff-filter=d HEAD); \
	if [ -z "$$files" ]; then \
		echo "fmt: no changed files"; \
	elif ! command -v prek >/dev/null 2>&1; then \
		echo "fmt: prek not found, skipping"; \
	else \
		prek run air-format panache-format --hide-status skipped --files $$files || true; \
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

