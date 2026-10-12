from contextlib import nullcontext

from playwright.async_api import async_playwright

from .logging import log


async def down(*, lang: str, timeout: float, windows_version: str = "11") -> str:
    """
    Download Windows ISO from Microsoft's website.

    Args:
        lang: Language selector text (e.g., "English International", "Español")
        timeout: Timeout in milliseconds for element waits
        windows_version: "10" or "11" (default: "11")
    """
    # Validate version
    if windows_version not in ("10", "11"):
        raise ValueError("windows_version must be '10' or '11'")

    # Microsoft download URLs
    # Note: Windows 10 page has a different URL structure
    if windows_version == "10":
        base_url = "https://www.microsoft.com/software-download/windows10"
    else:
        base_url = "https://www.microsoft.com/software-download/windows11"

    # Support end dates
    support_info = {
        "11": {
            "mainstream_end": "January 9, 2024",
            "esu_end": "January 12, 2027",
            "note": "Mainstream support ended. Extended Support Updates (ESU) available until 2027.",
        },
        "10": {
            "mainstream_end": "January 9, 2018",
            "esu_end": "October 10, 2025",
            "note": "Mainstream support ended. ESU available until October 10, 2025. "
                    "Microsoft can withdraw ISO downloads at any time.",
        },
    }

    info = support_info[windows_version]
    log.info("Windows %s support info: mainstream ended %s, ESU ends %s", windows_version,
             info["mainstream_end"], info["esu_end"])

    async with async_playwright() as ctx:
        async with await ctx.chromium.launch() as chrome:
            async with await chrome.new_page() as page:
                with nullcontext():
                    await page.goto(
                        base_url,
                        wait_until="networkidle",
                    )
                    log.info("Page title: %s", page.title)
                    log.info("Page URL: %s", page.url)

                # Dismiss cookie consent banner if present
                try:
                    await page.click("text=Accept", timeout=5000)
                except Exception:
                    log.info("No cookie banner found or already accepted")

                with nullcontext():
                    selector = page.locator("#product-edition")
                    log.info("%s", selector)
                    # Select Windows 10 or Windows 11 edition depending on version
                    if windows_version == "10":
                        # For Windows 10, select the first available edition option
                        try:
                            await selector.select_option(index=0)
                        except Exception:
                            log.warning("Failed to select edition index 0, continuing...")
                    else:
                        # For Windows 11, select index 1 (typically Windows 11)
                        try:
                            await selector.select_option(index=1)
                        except Exception:
                            log.warning("Failed to select edition index 1, continuing...")

                with nullcontext():
                    selector = page.locator("#submit-product-edition")
                    log.info("%s", selector)
                    await selector.click()

                # Wait for page to navigate/load after edition selection
                await page.wait_for_load_state("networkidle", timeout=15000)
                log.info("After edition - Page URL: %s", page.url)

                # Wait a bit for page to stabilize
                await page.wait_for_timeout(2000)

                # Get page content to find download link
                content = await page.content()

                # Strategy 1: Look for href containing '.iso'
                import re
                iso_patterns = re.findall(r'href="([^"]*\.iso[^"]*)"', content)
                log.info("Found %d links with '.iso' in href", len(iso_patterns))

                # Strategy 2: Look for href containing 'download'
                download_patterns = re.findall(r'href="([^"]*download[^"]*)"', content, re.IGNORECASE)
                log.info("Found %d links with 'download' in href (case insensitive)", len(download_patterns))

                # Strategy 3: Look for the specific Microsoft CDN download pattern
                cdn_patterns = re.findall(r'href="([^"]*cdn-dynmedia-1\.microsoft\.com[^"]*)"', content)
                log.info("Found %d links with cdn-dynmedia-1.microsoft.com", len(cdn_patterns))

                # Strategy 4: Try to find the ISO download link
                iso_link = None

                # Try ISO patterns first
                for pattern in iso_patterns:
                    if pattern and (".iso" in pattern.lower()):
                        iso_link = pattern
                        log.info("Found ISO download link: %s", iso_link)
                        break

                # If no ISO pattern, try download patterns with Microsoft CDN
                if not iso_link:
                    for pattern in download_patterns:
                        if pattern and ("cdn" in pattern.lower() or "microsoft.com" in pattern.lower()):
                            # Make sure it's not a tracking URL
                            if not any(skip in pattern.lower() for skip in [
                                "/redirect/", "/u/", "b=", "cn=", "id=",
                                "utm_", "ref=", "src=", "img="
                            ]):
                                iso_link = pattern
                                log.info("Found download link: %s", iso_link)
                                break

                # If still no link, try CDN patterns
                if not iso_link:
                    for pattern in cdn_patterns:
                        if pattern and ("iso" in pattern.lower() or "download" in pattern.lower()):
                            iso_link = pattern
                            log.info("Found download link via CDN: %s", iso_link)
                            break

                # Strategy 5: Find all links and look for the best candidate
                if not iso_link:
                    all_links = re.findall(r'href="([^"]*)"', content)
                    log.info("Total links found: %d", len(all_links))

                    for i, href in enumerate(all_links):
                        if href and "microsoft.com" in href.lower():
                            # Skip common non-download links
                            skip_phrases = ["#", "?=", "javascript:", "mailto:", "tel:",
                                          "/redirect/", "/u/", "b=", "cn=", "id=",
                                          "utm_", "ref=", "src=", "img=",
                                          "privacy", "cookies", "terms"]
                            if not any(skip in href.lower() for skip in skip_phrases):
                                iso_link = href
                                log.info("Selected link index %d: %s", i, href[:100])
                                break

                # Strategy 6: Last resort - find the .iso link explicitly
                if not iso_link:
                    iso_pattern2 = re.search(r'href="([^"]*\.iso[^"]*)"', content)
                    if iso_pattern2:
                        iso_link = iso_pattern2.group(1)
                        log.info("Found ISO link via regex: %s", iso_link)

                if iso_link:
                    log.info("Found download link: %s", iso_link)
                    assert iso_link, "Missing Download Link!"
                    return iso_link

                raise Exception("Could not find download link. Page content sample: " + str(content[:1000]))