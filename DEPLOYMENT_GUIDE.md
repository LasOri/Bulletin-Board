# GitHub Pages Deployment Guide

## Quick Setup (5 minutes)

### Step 1: Check GitHub Actions Status

1. **Visit your GitHub Actions page:**
   ```
   https://github.com/LasOri/Bulletin-Board/actions
   ```

2. **Look for the workflow runs:**
   - You should see "Build and Deploy to GitHub Pages"
   - Check if it's running (yellow circle), failed (red X), or succeeded (green checkmark)

3. **If the workflow hasn't run yet:**
   - It will trigger automatically on your next push
   - Or click "Run workflow" manually

### Step 2: Enable GitHub Pages

Once the workflow has run successfully (green checkmark):

1. **Go to repository settings:**
   ```
   https://github.com/LasOri/Bulletin-Board/settings/pages
   ```

2. **Under "Build and deployment":**
   - **Source**: Select "Deploy from a branch"
   - **Branch**: Select `gh-pages`
   - **Folder**: Select `/ (root)`

3. **Click "Save"**

4. **Wait 1-2 minutes** for GitHub to deploy

5. **Your live site will be at:**
   ```
   https://lasori.github.io/Bulletin-Board/
   ```

---

## Alternative: Manual Deployment (if Actions fail)

If GitHub Actions isn't working, you can deploy manually:

### Option A: Use Carton (Requires WASM SDK download to complete)

```bash
# Check if WASM SDK download finished
ls ~/.carton/sdk/

# If SDK is ready, build the bundle
cd /Users/I525390/Documents/own/Bulletin-Board
/tmp/carton-build/.build/release/carton bundle --release

# This creates Bundle/ directory with:
# - BulletinBoard.wasm
# - BulletinBoard.js

# Copy to deployment directory
mkdir -p dist
cp -r Bundle/* dist/
cp Public/index.html dist/
cp Public/styles.css dist/

# Create gh-pages branch
git checkout -b gh-pages
git add dist/*
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages

# Switch back to main
git checkout main
```

### Option B: Wait for GitHub Actions

The GitHub Actions workflow will automatically:
1. Install Carton in the CI environment
2. Run all 398 tests
3. Build the WASM bundle
4. Create the gh-pages branch
5. Deploy everything

**This is the easiest option - just wait for it to complete!**

---

## Troubleshooting

### "Workflow not found"
- Make sure `.github/workflows/deploy.yml` exists
- Check if Actions are enabled: Settings → Actions → General → Allow all actions

### "gh-pages branch doesn't exist"
- Wait for GitHub Actions to complete first
- The workflow creates this branch automatically
- Or create it manually using Option A above

### "404 Not Found" after deployment
- Wait 2-5 minutes for GitHub Pages to fully deploy
- Check Settings → Pages shows a green "Your site is live" message
- Verify the URL: `https://lasori.github.io/Bulletin-Board/`

### "Build failed in Actions"
- Check the Actions log for specific errors
- Most likely: Carton installation or Swift version issue
- The workflow uses macOS runner with Swift 6.2

---

## What Happens After Deployment

Once deployed, you'll be able to:

1. **Visit the live site** at https://lasori.github.io/Bulletin-Board/
2. **See the loading spinner** while WASM initializes
3. **See security logs** in browser console
4. **Test all interactions**:
   - Search articles
   - Add RSS feeds
   - Refresh feeds
   - Toggle favorites
   - See toast notifications

---

## Expected Console Output

When you visit the live site, you should see:

```
🗞️ Bulletin Board starting...
🗞️ Bulletin Board - Starting...
🛡️  All LINKER security features ENABLED:
   ✅ HTML Sanitization (XSS protection)
   ✅ CSRF Protection
   ✅ Rate Limiting
   ✅ HTTPS Enforcement
   ✅ WebAuthn Hardware-Backed Encryption
   ✅ Content Security Policy
✅ WebGPU supported - enabling GPU effects
   (or: ⚠️ WebGPU not supported - using CSS fallback)
📦 Loading persisted data...
  ℹ️ No persisted data found (first run)
🎨 Mounting UI...
⚡ Event handlers registered
✅ UI mounted successfully
✅ Bulletin Board ready!
```

---

## Next Steps After Deployment

1. **Test in multiple browsers:**
   - Chrome/Edge (WebGPU supported)
   - Safari (CSS fallback)
   - Firefox (CSS fallback)

2. **Test on mobile devices**

3. **Add a test RSS feed:**
   - Click "Add Feed"
   - Try: `https://hnrss.org/newest` (Hacker News)
   - Or: `https://feeds.bbci.co.uk/news/rss.xml` (BBC News)

4. **Share with users for feedback**

5. **Monitor for issues:**
   - Check browser console for errors
   - Test all interactions
   - Verify security features work

---

## Current Deployment Status

✅ Code pushed to GitHub (commit 2baa164)
✅ GitHub Actions workflow configured
⏳ Waiting for Actions to run
⏳ Waiting for gh-pages branch creation
⏳ Waiting for Pages to be enabled

**Next: Visit https://github.com/LasOri/Bulletin-Board/actions to check status**
