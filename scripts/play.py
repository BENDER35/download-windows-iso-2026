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
    base_url = "https://www.microsoft.com/software-download/windows{0}".format(windows_version)

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
                        await selector.select_option(index=0)
                    else:
                        # For Windows 11, select index 1 (typically Windows 11)
                        await selector.select_option(index=1)

                with nullcontext():
                    selector = page.locator("#submit-product-edition")
                    log.info("%s", selector)
                    await selector.click()

                # Wait for page to navigate/load after edition selection
                await page.wait_for_load_state("networkidle", timeout=15000)

                # Wait for language selector to be visible
                await page.wait_for_selector("#product-languages", state="visible", timeout=15000)

                with nullcontext():
                    selector = page.locator("#product-languages")
                    log.info("%s", selector)
                    # Select by index as fallback; the second option is often the desired language
                    await selector.select_option(index=1)

                with nullcontext():
                    selector = page.locator("#submit-sku")
                    log.info("%s", selector)
                    await selector.click()

                # Wait for the download link to appear
                await page.wait_for_selector("a.product-download-type", timeout=15000)

                with nullcontext():
                    selector = page.locator(
                        "a", has=page.locator(".product-download-type")
                    )
                    log.info("%s", selector)
                    uri = await selector.get_attribute("href", timeout=timeout)
                    assert uri, "Missing Download Link!"
                    return uri