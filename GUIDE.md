# Didactic Guide: download-windows-iso Script

## Overview

The `download-windows-iso` script automates the navigation of the Microsoft Windows 10/11 download page using Docker and Playwright. It selects the desired product edition and language, and outputs the download page URL. Note: Microsoft's website layout changes and anti-bot measures may require manual completion of the download.

1. Build a Docker image with Playwright installed.
2. Launch a headless browser to visit the Microsoft Windows 10/11 download page.
3. Select the desired product edition (e.g., Windows 10 or Windows 11) and language.
4. Output the download page URL.
5. Note: Microsoft's website layout changes and anti-bot measures may require manual download completion.

## How It Works

### Step 1: Docker Image Build

The script begins by building a Docker image named `download-windows-iso-2026-bindows` using the project's `Dockerfile`. The Dockerfile:

- Starts from the official `mcr.microsoft.com/playwright/python:latest` image, which includes Playwright and Chromium.
- Copies `requirements.txt` and installs Python dependencies (currently `playwright`).
- Runs `playwright install` to download the Chromium browser executable.
- Copies the local `scripts/` directory into the image.
- Sets the entry point to run the Python module `srv` with the `--language` and `--windows-version` arguments.

### Step 2: Run the Python Application

The script runs `docker compose build` and `docker run` to start the container. The container executes a Python application (`scripts/play.py`) that:

- Launches Chromium in headless mode.
- Navigates to `https://www.microsoft.com/software-download/windows{10/11}` (depends on the `-w` argument).
- Dismisses any cookie consent banner if present.
- Selects the product edition based on the Windows version selected.
- Clicks the "Submit" button to proceed.
- Waits for the language selector to become visible.
- Selects the language specified via the `-l` or `--language` argument (default: "English International").
- Clicks "Submit" again to proceed to the download page.
- Gets the final page URL after all selections.
- The Bash script captures this URL from the container's stdout.

### Step 3: Download the ISO

Once the direct download page URL is obtained from the script:

- Creates a `tmp/` directory if it doesn't exist.
- Changes to the `tmp/` directory.
- The user can run `wget --content-disposition <URL>` to download the ISO file, preserving the original filename.
- Note: Microsoft's website may require manual interaction to complete the download due to anti-bot measures.

### Step 4: Usage

```bash
# Default: Windows 11, English International
./download.sh

# Download Windows 10, English International
./download.sh -l "English International" -w 10

# Download Windows 11, Spanish
./download.sh -l "Spanish" -w 11

# Available languages depend on Microsoft's website; common values include:
# - "English International"
# - "Spanish"
# - "French"
# - etc.
```

### Important Warnings for Windows 10

When downloading Windows 10:

- **Mainstream support ended**: October 14, 2025
- **ESU (Extended Support Updates) ends**: October 12, 2027
  (3-year paid program to receive critical and important security updates)
- **Microsoft can withdraw ISO downloads at any time** - the download link may become unavailable without notice
- Consider using Windows 11 for continued security updates and support

## Recent Fixes

- Added `playwright install` to the Dockerfile to ensure the Chromium executable is available.
- Added `wait_for_load_state("networkidle")` after page navigation to ensure resources are loaded.
- Added cookie consent dismissal logic.
- Added explicit waits for element visibility to improve reliability.
- Added Windows 10/11 version selection support.
- Updated to output download page URL due to Microsoft website layout changes.

## Troubleshooting

If the script fails:

- Ensure Docker is running and accessible.
- Check that the language argument matches exactly what Microsoft displays (case-sensitive).
- Verify the Windows version argument is either "10" or "11".
- The script may fail if Microsoft changes their website layout; in such cases, the Playwright selectors may need updating.
- The output URL can be used with wget or a browser; Microsoft's site may require additional interaction.




ATTENTION, NOTICE (October 12, 2026): microsoft will cut off starting June 19,
2027 the access to windows update for all the computers that have windows 10
without ESU and below (the previous block was up to windows vista-server 2008
without R2), this logically affects the server versions (server 2008 R2 up to
server 2019, from server 2022 onwards, the windows update closure doesn't
affect it), this is due to the expiry of the root certificates of the update
service that expire as of this date, if you want to take a look at the official
link of the microsoft news, here it is (use the browser translation, it's in
English):

https://techcommunity.microsoft.com/blog/windows-itpro-blog/prepare-for-windows-update-certificate-rotation-in-2027/4562463

remember that root certificates are part of internet browsing, one of the
characteristics of the https protocol is that now everything that is transferred
to the router is encrypted (previously it wasn't so), but for programs used to
analyze everything that is transferred on a home network like wireshark to have
no effect (no sensitive data is seen), the root certificates must work and be
up to date, if they don't work, it gives a certificate error in the browser and
the programs that connect to the internet will stop working, you have to take
this into account when using an old windows installed on the computer (by the
way, the windows update closure also affects virtual machines, i.e., the PCs
booted inside a physical machine).

when the expiry date of the root certificate arrives it's possible that the
offices installed on windows without support give errors checking updates (up
to 10 and server 2019 which are client and server respectively you can install
the 2021-365, 7 and 8, up to office 2016), this being solved by deactivating
the office updates (when the expiry date of said root certificates arrives).

in the previous window (automatic updates were imposed starting from windows
2000) it didn't give any kind of failure when booting the operating system,
only when opening the microsoft update page or starting the windows update.
(I experienced the previous update closure window).

in case it's windows 10 with ESU, windows 11 24H2, LTSC servers of 2019 and
2016 and server 2022, microsoft has put as the official method to solve the
problem, the update, i.e., you'll have to update the second Tuesday of each
month until the date of June 19, 2027 in which already...piano, piano (you'll
understand what I'm telling you).

in case you come across this type of computers, these are the paths you have:

-  buy the ESU (windows 10) (in the case of countries of the european union, it has no cost)
-  patch the update to access the ESU, the only patch (and recommended for windows 10) is the MAS (microsoft activation script)
-  install an unofficial patch to update the root certificates, which is the legacy update
-  in the case of compatible versions (it's not mandatory for now from 11 24H2, windows 10 without ESU is essential
half-way) accept the updates to major versions of windows via update or doing an update from the windows installation
media.
-  keep the windows installation and do a dual boot with linux (not advisable).
-  uninstall windows and install linux together with a windows virtual machine (there everything is allowed, from originals to modified ones)

in case you choose the sensible option (the last one), remember that you must
set up vmware or virtualbox on linux (install linux on the computer logically)
and the virtual machine with the windows of your choice (that there you can
indeed install old windows) in an official way until June 2027, afterwards it
won't work and you'll only be able to install and update this type of PCs by
unofficial methods.

in case you've lost your job or the course for having told you this
inconvenience, good luck in your job search or in the course search (which I
hope you find), with all these clues I tell you you'll see how surely in the
end you find the dreamed job or course.