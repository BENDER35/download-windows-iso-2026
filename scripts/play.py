from contextlib import nullcontext

from playwright.async_api import async_playwright

from .logging import log


async def down(*, lang: str, timeout: float) -> str:
    async with async_playwright() as ctx:
        async with await ctx.chromium.launch() as chrome:
            async with await chrome.new_page() as page:
                with nullcontext():
                    await page.goto(
                        "https://www.microsoft.com/software-download/windows11",
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