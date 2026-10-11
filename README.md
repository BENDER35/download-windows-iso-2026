# Download Windows ISO

Bash script to download Windows ISO from Microsoft's website using Docker and Playwright.

## Requirements

1. Have `docker`
2. Have `bash`
3. Have `wget`

## Usage

### Step 1

```
# Default to `English International`
./download.sh [-l LANGUAGE]
```

### Step 2

Check `./tmp/` for the downloaded ISO.

### Step 3

The script will:
1. Build a Docker image with Playwright installed
2. Run a browser to navigate to the Microsoft Windows 11 download page
3. Select the product edition and language
4. Extract the direct download link
5. Use `wget` to download the ISO to the `tmp/` directory
