import puppeteer from 'puppeteer-core';

const routes = [
    { id: 1, s: "Hinjewadi", d: "Magarpatta" }
];

const times = [
    { tId: "T1", timeStr: "07:00", epoch: 1776648600 },
    { tId: "T2", timeStr: "11:00", epoch: 1776663000 },
    { tId: "T3", timeStr: "15:00", epoch: 1776677400 },
    { tId: "T4", timeStr: "19:00", epoch: 1776691800 }
];

const sleep = ms => new Promise(r => setTimeout(r, ms));
const artifactsDir = "/home/jayant/.gemini/antigravity/brain/2ed068b0-704c-458c-a1ad-d437c2b53465";

(async () => {
    console.log("Starting script...");
    try {
        const browser = await puppeteer.launch({
            executablePath: '/usr/bin/google-chrome-stable',
            headless: 'new',
            args: ['--no-sandbox', '--disable-setuid-sandbox', '--window-size=1440,900']
        });
        console.log("Browser launched.");
        const page = await browser.newPage();
        await page.setViewport({ width: 1440, height: 900 });

        for (const route of routes) {
            for (const time of times) {
                console.log(`Processing Route ${route.id} at ${time.tId}...`);
                await page.goto('http://localhost:5173', { waitUntil: 'networkidle0' });
                await page.waitForSelector('#source-input');
                // Inject robust datetime string to App backend directly
                await page.evaluate((isoStr) => window.forceTime = isoStr, `2026-04-20T${time.timeStr}:00+05:30`);

                await page.focus('#source-input');
                await page.keyboard.type(route.s);
                await sleep(1000);
                await page.waitForSelector('#source-dropdown .autocomplete-item');
                await page.click('#source-dropdown .autocomplete-item');

                await page.focus('#dest-input');
                await page.keyboard.type(route.d);
                await sleep(1000);
                await page.waitForSelector('#dest-dropdown .autocomplete-item');
                await page.click('#dest-dropdown .autocomplete-item');

                await page.click('#find-routes-btn');
                
                try {
                    await page.waitForSelector('.route-card', { timeout: 30000 });
                    await sleep(500);

                    const overviewFile = `${artifactsDir}/Route${route.id}_${time.tId}_Overview.png`;
                    await page.screenshot({ path: overviewFile });
                    console.log(`Saved ${overviewFile}`);
                    
                    // Click the top route to select it
                    await page.click('.route-card');
                    await sleep(500);

                    // Click expand button to view itinerary
                    await page.waitForSelector('.route-card__expand-btn', { timeout: 5000 });
                    await page.click('.route-card__expand-btn');

                    await page.waitForSelector('.itinerary', { timeout: 5000 });
                    await sleep(500);

                    const itineraryPanel = await page.$('.sidebar__results');
                    const itineraryFile = `${artifactsDir}/Route${route.id}_${time.tId}_Itinerary.png`;
                    await itineraryPanel.screenshot({ path: itineraryFile });
                    console.log(`Saved ${itineraryFile}`);
                } catch (e) {
                    console.error(`Failed to process Route ${route.id} at ${time.tId}: ${e.message}`);
                }
                
                // Render Google Maps for THIS exact time
                try {
                    console.log(`Processing GMaps Route ${route.id} at ${time.tId}...`);
                    await page.goto(`https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent(route.s + " Pune")}&destination=${encodeURIComponent(route.d + " Pune")}&travelmode=transit&dir_flg=r&date=2026-04-20&time=${time.timeStr.replace(':','')}`, {waitUntil: 'networkidle2'});
                    await sleep(4000);
                    const gmapsFile = `${artifactsDir}/GMaps_Route${route.id}_${time.tId}.png`;
                    await page.screenshot({ path: gmapsFile });
                    console.log(`Saved ${gmapsFile}`);
                } catch (e) {
                    console.error(`Failed GMaps for Route ${route.id} ${time.tId}: ${e.message}`);
                }
            }
        }

        await browser.close();
        console.log("All screenshots captured!");
    } catch (e) {
        console.error("Top level error:", e);
    }
})();
