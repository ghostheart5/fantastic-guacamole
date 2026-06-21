# fantastic-guacamole
ChronoSpark is the future of life management in every possible way.

## Added GitHub-ready project essentials

This repository now includes the core extras you asked for:

- **API key/token leak testing** via GitHub Actions secret scanning (`.github/workflows/secret-scan.yml`)
- **`.gitignore`** for common Flutter/Dart, IDE, and build artifacts
- **`LICENSE`** file (MIT)

## Secret scan behavior

A **Secret Scan** workflow runs automatically on:

- Pull requests
- Pushes to `main`

If a token/API key is detected, the workflow fails so you can remove it before merge.

## Notes

- If your main branch is not named `main`, update the workflow branch list.
- Keep real secrets in GitHub Secrets / environment variables, not in code.
