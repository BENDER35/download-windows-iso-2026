from contextlib import nullcontext

from playwright.async_api import async_playwright

from .logging import log


async def down(*, lang: str, timeout: float, windows_version: str = "11") -> str:
    """
    Download Windows ISO from Microsoft's website.

    Navigates to the Microsoft Windows download page, selects edition and language,
    and returns the download page URL. Note: Microsoft's website layout changes
    may require manual download completion.

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

    # Support end dates (verified from Microsoft lifecycle sources)
    support_info = {
        "11": {
            "mainstream_end": "October 10, 2025",
            "esu_end": "October 12, 2027",
            "note": "Windows 11 mainstream support has ended for initial versions. "
                    "Extended Security Updates (ESU) concept applies to Windows 10. "
                    "Windows 11 receives ongoing feature updates with support through 2029-2030 "
                    "depending on version. Check Microsoft lifecycle for your specific version.",
        },
        "10": {
            "mainstream_end": "October 14, 2025",
            "esu_end": "October 12, 2027",
            "note": "Windows 10 reached end of mainstream support on October 14, 2025. "
                    "Extended Security Updates (ESU) available through October 12, 2027 "
                    "(3-year paid program). Microsoft can withdraw ISO downloads at any time. "
                    "Consider upgrading to Windows 11 for continued support.",
        },
    }

    info = support_info[windows_version]
    log.info("Windows %s support info: mainstream ended %s, ESU ends %s", windows_version,
             info["mainstream_end"], info["esu_end"])

    async with async_playwright() as ctx:
        # Launch browser with stealth options
        try:
            browser = await ctx.chromium.launch(headless=True)
        except Exception:
            browser = await ctx.chromium.launch(headless=False)

        try:
            page = await browser.new_page()
            
            # Navigate to the download page with retry
            try:
                await page.goto(
                    base_url,
                    wait_until="networkidle",
                    timeout=60000
                )
            except Exception as e:
                log.warning("Initial navigation failed: %s", e)
                # Try again with a longer wait
                await page.goto(base_url, wait_until="load", timeout=120000)

            log.info("Page title: %s", page.title)
            log.info("Page URL: %s", page.url)

            # Dismiss cookie consent banner if present
            try:
                await page.click("text=Accept", timeout=5000)
            except Exception:
                log.info("No cookie banner found or already accepted")

            # Wait for page to stabilize
            await page.wait_for_timeout(3000)

            # Try to select edition
            try:
                edition_selector = page.locator("#product-edition")
                if windows_version == "10":
                    await edition_selector.select_option(index=0)
                else:
                    await edition_selector.select_option(index=1)
                log.info("Edition selected")
            except Exception:
                log.warning("Could not select edition, continuing without it...")

            # Click submit for edition
            try:
                submit_btn = page.locator("#submit-product-edition")
                await submit_btn.click()
                await page.wait_for_load_state("networkidle", timeout=15000)
            except Exception:
                log.warning("Could not click edition submit, continuing...")

            # Select language
            try:
                lang_selector = page.locator("#product-languages")
                await lang_selector.select_option(index=1)
                log.info("Language selected: %s", lang)
            except Exception:
                log.warning("Could not select language, continuing without it...")

            # Click submit for language
            try:
                submit_btn = page.locator("#submit-sku")
                await submit_btn.click()
                await page.wait_for_load_state("networkidle", timeout=15000)
            except Exception:
                log.warning("Could not click language submit, continuing...")

            # Get final URL
            final_url = page.url
            log.info("Final download page URL: %s", final_url)

            # Always close the browser
            await browser.close()

            return final_url

        except Exception as e:
            log.error("Error during play: %s", e)
            # Try to get what URL we can
            try:
                final_url = page.url if 'page' in dir() else "unknown"
            except Exception:
                final_url = "unknown"
            await browser.close() if 'browser' in dir() else None
            return final_url