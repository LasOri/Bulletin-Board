import puppeteer from 'puppeteer';

const MOCK_RSS = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Mock Tech News</title>
    <link>https://example.com</link>
    <description>Mock feed for visual testing</description>
    <item>
      <title>Revolutionary AI Chip Breaks Speed Records</title>
      <link>https://example.com/1</link>
      <description>A new AI accelerator chip has shattered performance benchmarks, achieving 10x faster inference than its closest competitor. The chip uses a novel architecture combining analog and digital computing.</description>
      <pubDate>Thu, 19 Mar 2026 12:00:00 GMT</pubDate>
      <category>Tech</category>
    </item>
    <item>
      <title>SpaceX Launches First Crewed Mission to Mars</title>
      <link>https://example.com/2</link>
      <description>SpaceX has successfully launched the first crewed Starship mission to Mars with a crew of six astronauts. The journey is expected to take approximately seven months.</description>
      <pubDate>Wed, 18 Mar 2026 10:00:00 GMT</pubDate>
      <category>Science</category>
    </item>
    <item>
      <title>Global Markets Rally on Trade Deal</title>
      <link>https://example.com/3</link>
      <description>Stock markets around the world surged after the announcement of a comprehensive trade agreement between major economies. The deal is expected to boost GDP growth by 2%.</description>
      <pubDate>Tue, 17 Mar 2026 08:00:00 GMT</pubDate>
      <category>Business</category>
    </item>
    <item>
      <title>New CRISPR Therapy Cures Genetic Disease</title>
      <link>https://example.com/4</link>
      <description>Scientists have achieved a breakthrough using CRISPR gene editing to cure a previously untreatable genetic disorder in clinical trials.</description>
      <pubDate>Mon, 16 Mar 2026 14:00:00 GMT</pubDate>
      <category>Science</category>
      <enclosure url="https://picsum.photos/800/400?random=4" type="image/jpeg" />
    </item>
    <item>
      <title>World Cup Qualifiers: Stunning Upsets</title>
      <link>https://example.com/5</link>
      <description>Multiple favorites were eliminated in the latest round of World Cup qualifiers, including two former champions.</description>
      <pubDate>Sun, 15 Mar 2026 16:00:00 GMT</pubDate>
      <category>Sports</category>
    </item>
    <item>
      <title>Streaming Wars: New Platform Launches</title>
      <link>https://example.com/6</link>
      <description>A new streaming service backed by major studios launched today with an impressive catalog of exclusive content and competitive pricing.</description>
      <pubDate>Sat, 14 Mar 2026 09:00:00 GMT</pubDate>
      <category>Entertainment</category>
    </item>
    <item>
      <title>Open Source Framework Reaches 1M Stars</title>
      <link>https://example.com/7</link>
      <description>The popular web framework has become the first open-source project to reach one million GitHub stars, reflecting its massive adoption across the industry.</description>
      <pubDate>Fri, 13 Mar 2026 11:00:00 GMT</pubDate>
      <category>Tech</category>
    </item>
    <item>
      <title>Climate Summit Produces Binding Agreement</title>
      <link>https://example.com/8</link>
      <description>World leaders signed a binding climate agreement committing to net-zero emissions by 2040, with enforceable penalties for non-compliance.</description>
      <pubDate>Thu, 12 Mar 2026 15:00:00 GMT</pubDate>
      <category>Politics</category>
    </item>
  </channel>
</rss>`;

const VIEWPORTS = {
    desktop: { width: 1440, height: 900, deviceScaleFactor: 1, isMobile: false, hasTouch: false },
    tablet: { width: 768, height: 1024, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
    mobile: { width: 375, height: 812, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
};

async function interceptCORS(page) {
    await page.setRequestInterception(true);
    page.on('request', (req) => {
        const url = req.url();
        if (url.includes('api.codetabs.com')) {
            req.respond({
                status: 200,
                contentType: 'text/xml; charset=utf-8',
                body: MOCK_RSS,
            });
        } else {
            req.continue();
        }
    });
}

async function auditTouchTargets(page, label) {
    const violations = await page.evaluate(() => {
        const interactive = document.querySelectorAll('button, a, input, [role="button"], [data-action]');
        const issues = [];
        for (const el of interactive) {
            const rect = el.getBoundingClientRect();
            if (rect.width === 0 && rect.height === 0) continue;
            if (rect.width < 44 || rect.height < 44) {
                issues.push({
                    tag: el.tagName,
                    text: el.textContent?.trim().substring(0, 30) || '',
                    classes: el.className?.substring(0, 50) || '',
                    width: Math.round(rect.width),
                    height: Math.round(rect.height),
                    action: el.dataset?.action || '',
                });
            }
        }
        return issues;
    });
    if (violations.length > 0) {
        console.log(`\n  Touch target violations at ${label} (${violations.length}):`);
        for (const v of violations) {
            console.log(`    ${v.width}x${v.height}px — <${v.tag.toLowerCase()}> "${v.text}" .${v.classes} [${v.action}]`);
        }
    } else {
        console.log(`  Touch targets at ${label}: ALL PASS (>= 44px)`);
    }
    return violations;
}

async function auditColors(page) {
    const orangeElements = await page.evaluate(() => {
        const all = document.querySelectorAll('*');
        const orangeHits = [];
        for (const el of all) {
            const style = getComputedStyle(el);
            const bg = style.backgroundColor;
            if (bg.includes('245, 166, 35') || bg.includes('f5a623')) {
                orangeHits.push({
                    tag: el.tagName,
                    text: el.textContent?.trim().substring(0, 30) || '',
                    classes: el.className?.substring(0, 50) || '',
                    bg,
                });
            }
        }
        return orangeHits;
    });
    if (orangeElements.length > 0) {
        console.log(`\n  Orange accent color found (${orangeElements.length} elements):`);
        for (const e of orangeElements) {
            console.log(`    <${e.tag.toLowerCase()}> "${e.text}" bg=${e.bg}`);
        }
    } else {
        console.log('  Color audit: No orange accent backgrounds found');
    }
    return orangeElements;
}

async function auditEmojis(page) {
    const emojiButtons = await page.evaluate(() => {
        const buttons = document.querySelectorAll('.app-toolbar button');
        const hits = [];
        const emojiPattern = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F000}-\u{1FFFF}]/u;
        for (const btn of buttons) {
            if (emojiPattern.test(btn.textContent)) {
                hits.push({ text: btn.textContent.trim().substring(0, 30), classes: btn.className });
            }
        }
        return hits;
    });
    if (emojiButtons.length > 0) {
        console.log(`\n  Emoji in toolbar buttons (${emojiButtons.length}):`);
        for (const e of emojiButtons) {
            console.log(`    "${e.text}" .${e.classes}`);
        }
    } else {
        console.log('  Toolbar emoji audit: CLEAN (no emoji icons)');
    }
    return emojiButtons;
}

async function auditSVGIcons(page) {
    const svgCount = await page.evaluate(() => {
        return document.querySelectorAll('.app-toolbar svg').length;
    });
    console.log(`  SVG icons in toolbar: ${svgCount}`);
    return svgCount;
}

async function auditButtonHierarchy(page) {
    const counts = await page.evaluate(() => {
        return {
            primary: document.querySelectorAll('.toolbar-button--primary').length,
            secondary: document.querySelectorAll('.toolbar-button--secondary').length,
            toggle: document.querySelectorAll('.toolbar-button--toggle').length,
            iconOnly: document.querySelectorAll('.toolbar-button--icon-only').length,
            separators: document.querySelectorAll('.toolbar-separator').length,
            groups: document.querySelectorAll('.toolbar-group').length,
        };
    });
    console.log(`  Button hierarchy: ${counts.primary} primary, ${counts.secondary} secondary, ${counts.toggle} toggle, ${counts.iconOnly} icon-only`);
    console.log(`  Layout: ${counts.groups} groups, ${counts.separators} separators`);
    return counts;
}

(async () => {
    const browser = await puppeteer.launch({
        headless: false,
        args: [
            '--enable-features=Vulkan,UseSkiaRenderer',
            '--enable-webgpu',
            '--enable-unsafe-webgpu',
            '--disable-vulkan-surface',
        ],
        defaultViewport: VIEWPORTS.desktop,
    });

    try {
        const page = await browser.newPage();
        await interceptCORS(page);

        console.log('Loading page (desktop 1440px)...');
        await page.goto('http://localhost:8000', {
            waitUntil: 'networkidle0',
            timeout: 30000,
        });
        await page.waitForSelector('.bulletin-board-app', { timeout: 20000 });
        await new Promise(r => setTimeout(r, 2000));

        console.log('\n=== PHASE 1: Empty State ===');
        await page.screenshot({ path: 'audit-phase1b-empty-desktop.png', fullPage: true });
        console.log('  Screenshot: audit-phase1b-empty-desktop.png');

        console.log('\n=== PHASE 2: Add Feed via Suggested Card ===');
        const addBtn = await page.$('.suggested-feed-card__button');
        if (addBtn) {
            await addBtn.click();
            console.log('  Clicked suggested feed card, waiting for articles...');
            await new Promise(r => setTimeout(r, 5000));

            const articleCount = await page.evaluate(() =>
                document.querySelectorAll('.article-card').length
            );
            console.log(`  Articles rendered: ${articleCount}`);

            console.log('\n=== PHASE 3: Article List Screenshots ===');
            await page.screenshot({ path: 'audit-phase1b-list-desktop.png', fullPage: true });
            console.log('  Screenshot: audit-phase1b-list-desktop.png (1440px)');

            await page.setViewport(VIEWPORTS.tablet);
            await new Promise(r => setTimeout(r, 500));
            await page.screenshot({ path: 'audit-phase1b-list-tablet.png', fullPage: true });
            console.log('  Screenshot: audit-phase1b-list-tablet.png (768px)');

            await page.setViewport(VIEWPORTS.mobile);
            await new Promise(r => setTimeout(r, 500));
            await page.screenshot({ path: 'audit-phase1b-list-mobile.png', fullPage: true });
            console.log('  Screenshot: audit-phase1b-list-mobile.png (375px)');

            console.log('\n=== PHASE 4: Article Detail ===');
            await page.setViewport(VIEWPORTS.desktop);
            await new Promise(r => setTimeout(r, 500));
            const firstCard = await page.$('.article-card');
            if (firstCard) {
                await firstCard.click();
                await new Promise(r => setTimeout(r, 1500));
                await page.screenshot({ path: 'audit-phase1b-detail-desktop.png', fullPage: true });
                console.log('  Screenshot: audit-phase1b-detail-desktop.png');

                await page.setViewport(VIEWPORTS.mobile);
                await new Promise(r => setTimeout(r, 500));
                await page.screenshot({ path: 'audit-phase1b-detail-mobile.png', fullPage: true });
                console.log('  Screenshot: audit-phase1b-detail-mobile.png');

                const closeBtn = await page.$('.article-detail__close-btn, [data-action="collapse-article"]');
                if (closeBtn) await closeBtn.click();
                await new Promise(r => setTimeout(r, 1000));
            }

            console.log('\n=== PHASE 5: Grid View ===');
            await page.setViewport(VIEWPORTS.desktop);
            await new Promise(r => setTimeout(r, 500));
            const gridBtn = await page.$('[data-action="toggle-view-mode"]');
            if (gridBtn) {
                await gridBtn.click();
                await new Promise(r => setTimeout(r, 1000));
                await page.screenshot({ path: 'audit-phase1b-grid-desktop.png', fullPage: true });
                console.log('  Screenshot: audit-phase1b-grid-desktop.png');

                await page.setViewport(VIEWPORTS.tablet);
                await new Promise(r => setTimeout(r, 500));
                await page.screenshot({ path: 'audit-phase1b-grid-tablet.png', fullPage: true });
                console.log('  Screenshot: audit-phase1b-grid-tablet.png');
            }
        } else {
            console.log('  No suggested feed card found (articles may already be loaded)');
        }

        console.log('\n=== PHASE 6: Audits ===');

        console.log('\n--- Touch Target Audit ---');
        await page.setViewport(VIEWPORTS.mobile);
        await new Promise(r => setTimeout(r, 500));
        await auditTouchTargets(page, '375px mobile');

        await page.setViewport(VIEWPORTS.desktop);
        await new Promise(r => setTimeout(r, 500));
        await auditTouchTargets(page, '1440px desktop');

        console.log('\n--- Color Audit ---');
        await auditColors(page);

        console.log('\n--- Emoji Audit ---');
        await auditEmojis(page);

        console.log('\n--- SVG Icon Audit ---');
        await auditSVGIcons(page);

        console.log('\n--- Button Hierarchy Audit ---');
        await auditButtonHierarchy(page);

        console.log('\n=== Test Complete ===');

    } catch (err) {
        console.error('Test failed:', err.message);
        await browser.close();
        process.exit(1);
    }

    await browser.close();
})();
