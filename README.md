# Download Windows ISO

Bash script to download Windows ISO from Microsoft's website using Docker and Playwright.

## Requirements

1. Have `docker`
2. Have `bash`
3. Have `wget`

## Installation

### On Windows

1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop
2. Run the installer and follow the setup wizard
3. Once installed, open Docker Desktop from the Start menu
4. Create a Docker account or sign in if you already have one
5. Docker will start automatically and you'll see the whale icon in your system tray
6. Verify installation by running `docker --version` in PowerShell or Command Prompt

### On Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation
sudo docker run --rm hello-world
```

### On Linux (Other Distributions)

Refer to the official Docker documentation for your specific distribution:
https://docs.docker.com/engine/install/

## Usage

### Step 1

```
# Default to `Windows 11, English International`
./download.sh [-l LANGUAGE] [-w WINDOWS_VERSION]

# Download Windows 10, English International
./download.sh -l "English International" -w 10

# Download Windows 11, Spanish
./download.sh -l "Español" -w 11
```

### Step 2

Check `./tmp/` for the downloaded ISO.

### Step 3

The script will:
1. Build a Docker image with Playwright installed
2. Run a browser to navigate to the Microsoft Windows {10/11} download page
3. Show support end-of-life warnings
4. Select the product edition and language
5. Output the direct download page URL
6. Note: Microsoft's website may require manual completion of the download
   due to anti-bot measures. The URL output below can be used with wget or a browser.

### Important Warnings

When downloading Windows 10:

- **Mainstream support ended**: October 14, 2025
- **ESU (Extended Support Updates) ends**: October 12, 2027
  (3-year paid program to receive critical and important security updates)
- **Microsoft can withdraw ISO downloads at any time** - the download link may become unavailable without notice
- Consider using Windows 11 for continued security updates and support

### Step 4

The script outputs a download page URL. You can use this URL with wget or a browser:

```bash
# Using wget (may require additional options for Microsoft's site):
wget --content-disposition "URL_OUTPUT"

# Or simply open the URL in a browser and click the download button:
# The URL will be displayed after the script runs
```

## Releases (maintainers)

`release.sh` automates the housekeeping around a release: it removes the Docker
container(s) left by `download.sh`, syncs the working changes and publishes a
GitHub release with a zip asset (plus a `.sha256`).

```bash
./release.sh                   # remove the latest ISO container, sync and publish
./release.sh --all-containers  # purge every container of the ISO image
./release.sh --dry-run         # show what would happen without changing anything
./release.sh -v v2.0.0         # publish an explicit version
./release.sh -m "fix: ..."     # custom commit message
```

Authentication uses a token with `repo` scope, read from an untracked
`./.secrets` file or the `GITHUB_TOKEN` environment variable:

```bash
echo 'GITHUB_TOKEN=ghp_xxx' > .secrets
chmod 600 .secrets
```

Options: `-b/--branch`, `-s/--source`, `-t/--token-file`, `-v/--version`,
`-m/--message`, `-a/--all-containers`, `--no-container`, `-n/--dry-run`, `-h`.
Run `./release.sh --help` for the full list and environment overrides.

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
