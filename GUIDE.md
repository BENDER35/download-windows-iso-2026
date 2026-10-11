# Didactic Guide: download-windows-iso Script

## Overview

The `download-windows-iso` script automates the download of a Windows 11 ISO file from Microsoft's website. It uses a combination of Bash, Docker, and Playwright (a browser automation library) to:

1. Build a Docker image with Playwright installed.
2. Launch a headless browser to visit the Microsoft Windows 11 download page.
3. Select the desired product edition (e.g., Windows 11) and language.
4. Extract the direct download link for the ISO.
5. Use `wget` to download the ISO to the local `tmp/` directory.

## How It Works

### Step 1: Docker Image Build

The script begins by building a Docker image named `download-windows-iso-2026-bindows` using the project's `Dockerfile`. The Dockerfile:

- Starts from the official `mcr.microsoft.com/playwright/python:latest` image, which includes Playwright and Chromium.
- Copies `requirements.txt` and installs Python dependencies (currently `playwright`).
- Runs `playwright install` to download the Chromium browser executable.
- Copies the local `scripts/` directory into the image.
- Sets the entry point to run the Python module `srv` with the `--language` argument.

### Step 2: Run the Python Application

The script runs `docker compose build` and `docker run` to start the container. The container executes a Python application (`scripts/play.py`) that:

- Launches Chromium in headless mode.
- Navigates to `https://www.microsoft.com/software-download/windows11`.
- Dismisses any cookie consent banner if present.
- Selects the product edition (index 1, typically "Windows 11").
- Clicks the "Submit" button to proceed.
- Waits for the language selector to become visible.
- Selects the language specified via the `-l` or `--language` argument (default: "English International").
- Clicks "Submit" again to proceed to the download page.
- Waits for the download link `<a class="product-download-type">` to appear.
- Extracts the `href` attribute (the direct download URL).
- The Bash script captures this URL from the container's stdout.

### Step 3: Download the ISO

Once the direct download URL is obtained, the Bash script:

- Creates a `tmp/` directory if it doesn't exist.
- Changes to the `tmp/` directory.
- Runs `wget --content-disposition <URL>` to download the ISO file, preserving the original filename.

### Step 4: Usage

```bash
# Default: English International
./download.sh

# Specify a language
./download.sh -l "English International"

# Available languages depend on Microsoft's website; common values include:
# - "English International"
# - "Spanish"
# - "French"
# - etc.
```

## Recent Fixes

- Added `playwright install` to the Dockerfile to ensure the Chromium executable is available.
- Added `wait_for_load_state("networkidle")` after page navigation to ensure resources are loaded.
- Added cookie consent dismissal logic.
- Added explicit waits for element visibility to improve reliability.

## Troubleshooting

If the script fails:

- Ensure Docker is running and accessible.
- Check that the language argument matches exactly what Microsoft displays (case-sensitive).
- The script may fail if Microsoft changes their website layout; in such cases, the Playwright selectors may need updating.