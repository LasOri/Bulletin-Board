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
      <enclosure url="https://picsum.photos/seed/1/800/400" type="image/jpeg" />
    </item>
    <item>
      <title>SpaceX Launches First Crewed Mission to Mars</title>
      <link>https://example.com/2</link>
      <description>SpaceX has successfully launched the first crewed Starship mission to Mars with a crew of six astronauts. The journey is expected to take approximately seven months.</description>
      <pubDate>Wed, 18 Mar 2026 10:00:00 GMT</pubDate>
      <category>Science</category>
      <enclosure url="https://picsum.photos/seed/2/800/400" type="image/jpeg" />
    </item>
    <item>
      <title>Global Markets Rally on Trade Deal</title>
      <link>https://example.com/3</link>
      <description>Stock markets around the world surged after the announcement of a comprehensive trade agreement between major economies. The deal is expected to boost GDP growth by 2%.</description>
      <pubDate>Tue, 17 Mar 2026 08:00:00 GMT</pubDate>
      <category>Business</category>
      <enclosure url="https://picsum.photos/seed/3/800/400" type="image/jpeg" />
    </item>
    <item>
      <title>New CRISPR Therapy Cures Genetic Disease</title>
      <link>https://example.com/4</link>
      <description>Scientists have achieved a breakthrough using CRISPR gene editing to cure a previously untreatable genetic disorder in clinical trials.</description>
      <pubDate>Mon, 16 Mar 2026 14:00:00 GMT</pubDate>
      <category>Science</category>
      <enclosure url="https://picsum.photos/seed/4/800/400" type="image/jpeg" />
    </item>
    <item>
      <title>World Cup Qualifiers: Stunning Upsets</title>
      <link>https://example.com/5</link>
      <description>Multiple favorites were eliminated in the latest round of World Cup qualifiers, including two former champions.</description>
      <pubDate>Sun, 15 Mar 2026 16:00:00 GMT</pubDate>
      <category>Sports</category>
      <enclosure url="https://picsum.photos/seed/5/800/400" type="image/jpeg" />
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
      <enclosure url="https://picsum.photos/seed/7/800/400" type="image/jpeg" />
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

async function auditEmojis(page) {
    const emojiHits = await page.evaluate(() => {
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        const emojiPattern = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F000}-\u{1FFFF}]/u;
        const hits = [];
        while (walker.nextNode()) {
            const text = walker.currentNode.textContent;
            if (emojiPattern.test(text)) {
                const parent = walker.currentNode.parentElement;
                hits.push({
                    text: text.trim().substring(0, 40),
                    tag: parent?.tagName || 'unknown',
                    classes: parent?.className?.substring(0, 60) || '',
                });
            }
        }
        return hits;
    });
    if (emojiHits.length > 0) {
        console.log(`  EMOJI FOUND in DOM (${emojiHits.length}):`);
        for (const e of emojiHits) {
            console.log(`    "${e.text}" in <${e.tag.toLowerCase()}> .${e.classes}`);
        }
    } else {
        console.log('  Full emoji sweep: CLEAN (zero emoji in DOM)');
    }
    return emojiHits;
}

async function auditSVGIcons(page) {
    const svgCount = await page.evaluate(() => {
        return document.querySelectorAll('.app-toolbar svg, .error-message__icon svg, .search-bar__suggestion-icon svg, .article-detail__footer svg').length;
    });
    console.log(`  SVG icons in UI: ${svgCount}`);
    return svgCount;
}

async function auditHeroImages(page) {
    const result = await page.evaluate(() => {
        const heroes = document.querySelectorAll('.article-card__hero');
        const loaded = document.querySelectorAll('.article-card__hero-img.loaded');
        const imgs = document.querySelectorAll('.article-card__hero-img');
        return {
            heroContainers: heroes.length,
            loadedImages: loaded.length,
            totalImages: imgs.length,
        };
    });
    console.log(`  Hero images: ${result.heroContainers} containers, ${result.totalImages} imgs, ${result.loadedImages} loaded`);
    return result;
}

async function auditAnimations(page) {
    const result = await page.evaluate(() => {
        const detail = document.querySelector('.article-detail');
        const overlay = document.querySelector('.article-detail-overlay');
        return {
            hasDetail: !!detail,
            hasOverlay: !!overlay,
            detailAnim: detail ? getComputedStyle(detail).animationName : null,
            overlayAnim: overlay ? getComputedStyle(overlay).animationName : null,
        };
    });
    if (result.hasDetail) {
        console.log(`  Detail panel animation: ${result.detailAnim}`);
        console.log(`  Overlay animation: ${result.overlayAnim}`);
    } else {
        console.log('  No detail panel open (animation check skipped)');
    }
    return result;
}

async function auditGPUCanvases(page) {
    const count = await page.evaluate(() => {
        return document.querySelectorAll('[data-linker-lifecycle] canvas, canvas[data-gpu]').length;
    });
    console.log(`  GPU canvases (lifecycle): ${count}`);
    return count;
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
        await page.screenshot({ path: 'audit-phase2-empty-desktop.png', fullPage: true });
        console.log('  Screenshot: audit-phase2-empty-desktop.png');

        console.log('\n=== PHASE 2: Add Feed ===');
        const addBtn = await page.$('.suggested-feed-card__button');
        if (addBtn) {
            await addBtn.click();
            console.log('  Clicked suggested feed card, waiting for articles...');
            await new Promise(r => setTimeout(r, 8000));

            const articleCount = await page.evaluate(() =>
                document.querySelectorAll('.article-card').length
            );
            console.log(`  Articles rendered: ${articleCount}`);

            console.log('\n=== PHASE 3: Hero Image Loading ===');
            try {
                await page.waitForSelector('.article-card__hero-img.loaded', { timeout: 10000 });
                console.log('  Hero images loaded successfully');
            } catch {
                console.log('  Hero image load timeout (images may not load in headless with CORS proxy)');
            }

            const heroInfo = await auditHeroImages(page);

            console.log('\n=== PHASE 4: Screenshots at 3 Viewports ===');
            await page.screenshot({ path: 'audit-phase2-list-desktop.png', fullPage: true });
            console.log('  Screenshot: audit-phase2-list-desktop.png (1440px)');

            await page.setViewport(VIEWPORTS.tablet);
            await new Promise(r => setTimeout(r, 500));
            await page.screenshot({ path: 'audit-phase2-list-tablet.png', fullPage: true });
            console.log('  Screenshot: audit-phase2-list-tablet.png (768px)');

            await page.setViewport(VIEWPORTS.mobile);
            await new Promise(r => setTimeout(r, 500));
            await page.screenshot({ path: 'audit-phase2-list-mobile.png', fullPage: true });
            console.log('  Screenshot: audit-phase2-list-mobile.png (375px)');

            console.log('\n=== PHASE 5: Article Detail ===');
            await page.setViewport(VIEWPORTS.desktop);
            await new Promise(r => setTimeout(r, 500));
            const firstCard = await page.$('.article-card');
            if (firstCard) {
                await firstCard.click();
                await new Promise(r => setTimeout(r, 1500));

                await auditAnimations(page);

                const detailHero = await page.evaluate(() => {
                    const hero = document.querySelector('.article-detail__hero-img');
                    return hero ? { src: hero.src, loaded: hero.classList.contains('loaded') } : null;
                });
                if (detailHero) {
                    console.log(`  Detail hero image: ${detailHero.loaded ? 'loaded' : 'loading'} (${detailHero.src.substring(0, 50)}...)`);
                }

                await page.screenshot({ path: 'audit-phase2-detail-desktop.png', fullPage: true });
                console.log('  Screenshot: audit-phase2-detail-desktop.png');

                const closeBtn = await page.$('.article-detail__close-btn, [data-action="collapse-article"]');
                if (closeBtn) await closeBtn.click();
                await new Promise(r => setTimeout(r, 1000));
            }

            console.log('\n=== PHASE 6: Grid View ===');
            const gridBtn = await page.$('[data-action="toggle-view-mode"]');
            if (gridBtn) {
                await gridBtn.click();
                await new Promise(r => setTimeout(r, 1000));
                await page.screenshot({ path: 'audit-phase2-grid-desktop.png', fullPage: true });
                console.log('  Screenshot: audit-phase2-grid-desktop.png');
            }
        } else {
            console.log('  No suggested feed card found');
        }

        console.log('\n=== PHASE 7: Audits ===');

        console.log('\n--- Touch Target Audit ---');
        await page.setViewport(VIEWPORTS.mobile);
        await new Promise(r => setTimeout(r, 500));
        await auditTouchTargets(page, '375px mobile');

        await page.setViewport(VIEWPORTS.desktop);
        await new Promise(r => setTimeout(r, 500));

        console.log('\n--- Emoji Sweep ---');
        await auditEmojis(page);

        console.log('\n--- SVG Icon Audit ---');
        await auditSVGIcons(page);

        console.log('\n--- GPU Canvas Audit ---');
        await auditGPUCanvases(page);

        console.log('\n=== Test Complete ===');

    } catch (err) {
        console.error('Test failed:', err.message);
        await browser.close();
        process.exit(1);
    }

    await browser.close();
})();
