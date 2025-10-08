# Hugo Site Makefile
# Personal blog and photography site

.PHONY: help serve build clean lint spell check install deps

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Local development
serve: ## Start local development server
	@echo "Starting Hugo development server..."
	@hugo server --port 1313 --bind 0.0.0.0 --buildDrafts --buildFuture

local: serve ## Alias for serve

dev: serve ## Alias for serve

# Production build
build: ## Build site for production
	@echo "Building site for production..."
	@rm -rf public
	@hugo --minify
	@echo "✅ Production build complete in ./public/"

# Clean build artifacts
clean: ## Clean build artifacts and caches
	@echo "Cleaning build artifacts..."
	@rm -rf public
	@rm -rf resources/_gen
	@rm -rf .hugo_build.lock
	@echo "✅ Clean complete"

# Install dependencies
install: deps ## Install all dependencies

deps: ## Install required tools and dependencies
	@echo "Installing dependencies..."
	@command -v hugo >/dev/null 2>&1 || (echo "❌ Hugo not found. Install from https://gohugo.io/installation/" && exit 1)
	@command -v npm >/dev/null 2>&1 || (echo "❌ npm not found. Install Node.js from https://nodejs.org/" && exit 1)
	@echo "Installing Node.js packages..."
	@npm install --save-dev markdownlint-cli2 cspell htmlhint
	@echo "✅ Dependencies installed"

# Linting
lint: ## Run all linting checks
	@echo "Running linting checks..."
	@$(MAKE) lint-markdown
	@$(MAKE) lint-html
	@echo "✅ All linting checks passed"

lint-markdown: ## Lint markdown files
	@echo "Linting markdown files..."
	@test -f node_modules/.bin/markdownlint-cli2 || (echo "❌ markdownlint-cli2 not found. Run 'make deps' first" && exit 1)
	@npx markdownlint-cli2 "content/**/*.md" "README.md" || (echo "❌ Markdown linting failed" && exit 1)
	@echo "✅ Markdown linting passed"

lint-html: ## Lint generated HTML (requires build first)
	@echo "Linting HTML files..."
	@if [ ! -d "public" ]; then echo "❌ No public directory found. Run 'make build' first" && exit 1; fi
	@test -f node_modules/.bin/htmlhint || (echo "❌ htmlhint not found. Run 'make deps' first" && exit 1)
	@npx htmlhint "public/**/*.html" --config .htmlhintrc || (echo "❌ HTML linting failed" && exit 1)
	@echo "✅ HTML linting passed"

# Spell checking
spell: ## Run spell checking on content
	@echo "Running spell check..."
	@test -f node_modules/.bin/cspell || (echo "❌ cspell not found. Run 'make deps' first" && exit 1)
	@npx cspell "content/**/*.md" "README.md" --config .cspell.json || (echo "❌ Spell check failed" && exit 1)
	@echo "✅ Spell check passed"

spell-interactive: ## Run interactive spell checking
	@echo "Running interactive spell check..."
	@test -f node_modules/.bin/cspell || (echo "❌ cspell not found. Run 'make deps' first" && exit 1)
	@npx cspell "content/**/*.md" "README.md" --config .cspell.json --show-suggestions

# Quality checks
check: lint spell ## Run all quality checks (lint + spell)

# Test build
test: ## Test that the site builds without errors
	@echo "Testing build..."
	@hugo --destination ./test-build --minify
	@rm -rf ./test-build
	@echo "✅ Build test passed"

# Development helpers
new-post: ## Create a new blog post (usage: make new-post TITLE="My New Post")
	@if [ -z "$(TITLE)" ]; then echo "❌ Please provide a title: make new-post TITLE=\"My New Post\""; exit 1; fi
	@hugo new blog/$(shell echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$$//g').md
	@echo "✅ New post created"

new-gallery: ## Create a new photo gallery (usage: make new-gallery NAME="gallery-name")
	@if [ -z "$(NAME)" ]; then echo "❌ Please provide a gallery name: make new-gallery NAME=\"gallery-name\""; exit 1; fi
	@mkdir -p content/photos/$(NAME)
	@mkdir -p assets/images/photos/$(NAME)
	@echo '---\ntitle: "$(NAME)"\ndescription: "Description for $(NAME) gallery"\ndate: $(shell date +%Y-%m-%d)\nshowTableOfContents: false\nshowBreadcrumbs: true\nshowDate: true\nshowAuthor: false\n---\n\n{{< auto-gallery collection="$(NAME)" >}}' > content/photos/$(NAME)/index.md
	@echo "✅ New gallery '$(NAME)' created"
	@echo "   - Add photos to: assets/images/photos/$(NAME)/"
	@echo "   - Edit content at: content/photos/$(NAME)/index.md"

# Deploymentmake 
deploy: build ## Build and prepare for deployment
	@echo "Site ready for deployment in ./public/"
	@echo "Commit and push to trigger GitHub Actions deployment"

# Hugo module management
mod-update: ## Update Hugo modules
	@echo "Updating Hugo modules..."
	@hugo mod get -u
	@hugo mod tidy
	@echo "✅ Hugo modules updated"

mod-vendor: ## Vendor Hugo modules
	@echo "Vendoring Hugo modules..."
	@hugo mod vendor
	@echo "✅ Hugo modules vendored"

# Image optimization
optimize-images: ## Optimize images in assets/images/photos/ (requires imagemagick)
	@echo "Optimizing images..."
	@command -v convert >/dev/null 2>&1 || (echo "❌ ImageMagick not found. Install with: brew install imagemagick" && exit 1)
	@find assets/images/photos -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" | while read img; do \
		echo "Optimizing $$img..."; \
		convert "$$img" -quality 85 -strip "$$img.tmp" && mv "$$img.tmp" "$$img"; \
	done
	@echo "✅ Image optimization complete"

# CI/CD helpers
ci: deps lint spell test ## Run all CI checks

# Development workflow
dev-setup: deps ## Complete development setup
	@echo "Setting up development environment..."
	@$(MAKE) clean
	@$(MAKE) mod-update
	@echo "✅ Development setup complete"

# Watch for changes and rebuild
watch: ## Watch for changes and rebuild (alternative to serve)
	@echo "Watching for changes..."
	@hugo server --watch --buildDrafts --buildFuture --port 1313
