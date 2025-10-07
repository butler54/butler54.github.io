# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal blog and photography portfolio built with Hugo and the Blowfish theme. The site features automated photo galleries with infinite scroll, lazy loading, and optional metadata support. It's deployed to GitHub Pages at https://chris.thebutlers.me.

## Common Commands

### Development
```bash
make serve          # Start local dev server at http://localhost:1313
make build          # Build for production (outputs to ./public/)
make clean          # Clean build artifacts and caches
```

### Quality Checks
```bash
make deps           # Install Node.js dependencies (markdownlint, cspell, htmlhint)
make lint           # Run markdown + HTML linting
make spell          # Run spell checking on content
make check          # Run all quality checks (lint + spell)
make test           # Test that site builds without errors
make ci             # Run all CI checks (deps, lint, spell, test)
```

### Content Creation
```bash
make new-post TITLE="My New Post"           # Create new blog post
make new-gallery NAME="gallery-name"        # Create new photo gallery structure
```

### Other
```bash
make mod-update         # Update Hugo modules
make optimize-images    # Optimize images (requires ImageMagick)
```

## Architecture

### Photo Gallery System

The core feature is an automated photo gallery system with these components:

1. **Directory Structure**: Photo galleries have parallel structures:
   - `content/photos/{collection}/index.md` - Gallery description and frontmatter
   - `static/images/photos/{collection}/` - Actual image files
   - `content/photos/{collection}/metadata.yaml` - Optional photo metadata

2. **auto-gallery shortcode** (`layouts/shortcodes/auto-gallery.html`):
   - Automatically discovers images in `static/images/photos/{collection}/`
   - Implements infinite scroll (loads 12 images at a time by default)
   - Supports optional metadata from YAML/JSON/TOML files
   - Provides lightbox modal for viewing images
   - Parameters: `collection`, `batchSize`, `columns`
   - Uses Hugo's `readDir` to discover images at build time
   - Lazy loads images and batches remaining photos as JSON for client-side infinite scroll

3. **gallery-collections shortcode** (`layouts/shortcodes/gallery-collections.html`):
   - Displays all available photo galleries as cards
   - Automatically finds all collections under `content/photos/`

4. **Metadata System**: Photos can have metadata in `metadata.yaml`:
   ```yaml
   photos:
     IMG_001:  # Filename without extension
       title: "Photo Title"
       camera: "Sony Alpha 7 CR"
       lens: "24-70mm f/2.8"
       location: "Location Name"
       date: "2024-09-16"
       description: "Description text"
   ```

### Hugo Configuration

- Uses Blowfish v2 theme via Hugo modules (`module.imports` in hugo.toml)
- Image processing: CatmullRom filter, quality 85, smart anchor
- Markup: Goldmark with unsafe HTML enabled, GitHub syntax highlighting
- Outputs: HTML, RSS, JSON for home page
- Taxonomies: tags, categories, series

### Deployment

- GitHub Actions workflow (`.github/workflows/hugo-deploy.yml`)
- Triggers on push to `main` branch
- Uses Hugo Extended v0.128.0
- Deploys to GitHub Pages
- Custom domain: chris.thebutlers.me (configured via `static/CNAME`)

## Hugo Specifics

- **Hugo Extended required**: Site uses SCSS/SASS features
- **Minimum version**: 0.128.0
- **Theme**: Blowfish v2 (loaded as Hugo module)
- Additional config in `config/_default/` directory (params.toml, menus.toml, languages.toml)

## Adding Photos Workflow

When adding a new photo gallery:

1. Create the gallery structure: `make new-gallery NAME="gallery-name"`
2. Add images to `static/images/photos/gallery-name/`
3. Optionally add metadata in `content/photos/gallery-name/metadata.yaml`
4. The `auto-gallery` shortcode is already included in the generated index.md

Images are automatically discovered at build time - no manual listing required.

## Linting & Quality

- **Markdown linting**: Uses markdownlint-cli2 with config in `.markdownlint-cli2.jsonc`
- **Spell checking**: Uses cspell with custom dictionary in `.cspell.json`
- **HTML linting**: Uses htmlhint with config in `.htmlhintrc`
- All checks run in CI via `make ci`

## Important Notes

- Always run quality checks before committing: `make check`
- The site uses lazy loading and infinite scroll - initial batch loads 12 photos, rest load on scroll
- Photo filenames become default titles if metadata is not provided
- All image paths in shortcodes are relative to `static/` directory
- The Blowfish theme provides the base layout and styling - custom shortcodes extend functionality
