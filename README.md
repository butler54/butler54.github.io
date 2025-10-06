# Chris Butler's Personal Website

A personal blog and photography portfolio built with [Hugo](https://gohugo.io/) and the [Blowfish](https://github.com/nunocoracao/blowfish) theme.

## 🚀 Features

- **Automated Photo Galleries**: Drop images in folders and get infinite-scroll galleries automatically
- **Blog**: Technical posts and thoughts on technology
- **Performance Optimized**: Lazy loading, responsive images, perfect Lighthouse scores
- **Dark Mode**: Auto-switching based on system preference
- **Search**: Built-in client-side search
- **SEO Optimized**: Structured data and social media integration

## 📁 Project Structure

```
├── content/
│   ├── blog/                 # Blog posts
│   └── photos/               # Photo galleries
│       ├── latest/
│       │   ├── index.md      # Gallery description
│       │   └── metadata.yaml # Optional photo metadata
│       └── japan/
├── static/
│   └── images/
│       └── photos/           # Actual image files
│           ├── latest/
│           └── japan/
├── layouts/
│   └── shortcodes/           # Custom gallery shortcodes
└── config/_default/          # Hugo configuration
```

## 📸 Adding Photos

### Quick Method (Automatic)

1. Create a new collection:
   ```bash
   mkdir -p content/photos/my-trip
   mkdir -p static/images/photos/my-trip
   ```

2. Add photos:
   ```bash
   cp ~/Photos/*.jpg static/images/photos/my-trip/
   ```

3. Create gallery page:
   ```markdown
   # content/photos/my-trip/index.md
   ---
   title: "My Trip"
   description: "Photos from my recent adventure"
   ---
   
   {{< auto-gallery >}}
   ```

4. **That's it!** Hugo automatically creates the gallery with infinite scroll.

### Enhanced Method (With Metadata)

Optionally, add rich metadata for specific photos:

```yaml
# content/photos/my-trip/metadata.yaml
photos:
  IMG_001:
    title: "Sunset at the Beach"
    camera: "Sony Alpha 7 CR"
    lens: "24-70mm f/2.8"
    location: "Bondi Beach, Australia"
    description: "Golden hour magic"
  IMG_002:
    title: "Street Art"
    location: "Melbourne"
```

Photos without metadata will automatically use their filename as the title.

## 📝 Adding Blog Posts

Create a new markdown file in `content/blog/`:

```markdown
---
title: "My New Post"
description: "Brief description"
date: 2024-09-16
author: "Chris Butler"
categories:
  - technology
  - programming
---

Your content here...
```

## 🛠️ Development

### Prerequisites

- [Hugo Extended](https://gohugo.io/installation/) (v0.128.0+)
- [Go](https://golang.org/doc/install) (for Hugo modules)

### Local Development

```bash
# Clone the repository
git clone https://github.com/butler54/butler54.github.io.git
cd butler54.github.io

# Install dependencies (linting and spell checking tools)
make deps

# Start development server
make serve
# or: make local or make dev

# Visit http://localhost:1313
```

### Building for Production

```bash
# Build for production
make build

# Test that build works
make test
```

## 🛠️ Development Commands (Makefile)

This project includes a comprehensive Makefile with all the development commands you need:

```bash
# Show all available commands
make help

# Development
make serve          # Start local development server
make build          # Build for production  
make clean          # Clean build artifacts

# Quality Checks
make lint           # Run all linting (markdown + HTML)
make spell          # Run spell checking
make check          # Run all quality checks (lint + spell)

# Content Creation  
make new-post TITLE="My New Post"           # Create new blog post
make new-gallery NAME="gallery-name"        # Create new photo gallery

# Dependencies
make deps           # Install linting and spell checking tools
make dev-setup      # Complete development environment setup

# Testing & CI
make test           # Test that site builds correctly
make ci             # Run all CI checks (used by GitHub Actions)

# Utilities
make optimize-images    # Optimize images (requires ImageMagick)
make mod-update        # Update Hugo modules
```

### Quality Assurance

The Makefile includes comprehensive quality checking:

- **Markdown Linting**: Checks markdown files for common issues
- **Spell Checking**: Validates spelling across all content
- **HTML Linting**: Validates generated HTML structure
- **Build Testing**: Ensures the site builds without errors

## 🚀 Deployment

The site is automatically deployed to GitHub Pages using GitHub Actions when you push to the `main` branch.

### Custom Domain

The site uses a custom domain (`chris.thebutlers.me`) configured via the `static/CNAME` file.

## ⚙️ Configuration

Main configuration files:

- `hugo.toml` - Base Hugo configuration
- `config/_default/params.toml` - Blowfish theme settings
- `config/_default/menus.toml` - Navigation menus
- `config/_default/languages.toml` - Language settings

## 📊 Performance

The automated gallery system provides:

- **Lazy Loading**: Only loads visible images
- **Infinite Scroll**: Loads 12 images at a time
- **Responsive Images**: Multiple sizes generated automatically
- **Optimized Loading**: ~200KB initial load vs ~2-5MB with traditional galleries

## 🔧 Shortcodes

### `auto-gallery`

Automatically discovers and displays images in a collection with infinite scroll.

```markdown
{{< auto-gallery >}}
{{< auto-gallery batchSize="8" columns="md:grid-cols-4" >}}
```

### `gallery-collections`

Displays all available photo collections as cards.

```markdown
{{< gallery-collections >}}
```

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- [Hugo](https://gohugo.io/) - The world's fastest framework for building websites
- [Blowfish Theme](https://github.com/nunocoracao/blowfish) - A powerful, lightweight theme for Hugo
- [Tailwind CSS](https://tailwindcss.com/) - A utility-first CSS framework