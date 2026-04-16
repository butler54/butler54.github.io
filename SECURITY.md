# Security Policy

## About This Project

This is a personal blog and photography site. It is a static site
built with Hugo and deployed to GitHub Pages.

## Security Practices

- **Pinned dependencies**: All GitHub Actions are pinned to full SHA commits.
- **Build provenance**: SLSA build provenance attestations are generated for each deployment.
- **Dependabot**: Automated dependency updates are enabled for GitHub Actions, npm, and Go modules.
- **OpenSSF Scorecard**: The project is monitored via the [OpenSSF Scorecard](https://securityscorecards.dev/).
- **Least-privilege permissions**: All workflow jobs use explicit, minimal GITHUB_TOKEN permissions.

## Reporting a Vulnerability

If you discover a security vulnerability in the site infrastructure
(workflows, dependencies, configuration), please open an issue or
contact the repository owner directly.
