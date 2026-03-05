#!/bin/bash

# Bulletin Board Deployment Status Checker
# Check GitHub Actions and Pages deployment status

REPO="LasOri/Bulletin-Board"
PAGES_URL="https://lasori.github.io/Bulletin-Board/"

echo "🗞️  Bulletin Board Deployment Status"
echo "===================================="
echo ""

# Check if gh-pages branch exists
echo "📋 Checking branches..."
if git ls-remote --heads origin gh-pages > /dev/null 2>&1; then
    echo "✅ gh-pages branch exists"
else
    echo "⏳ gh-pages branch not created yet"
    echo "   Waiting for GitHub Actions to complete..."
fi

echo ""

# Try to check if site is live
echo "🌐 Checking if site is live..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$PAGES_URL" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Site is LIVE at: $PAGES_URL"
    echo ""
    echo "🎉 Deployment successful!"
    echo ""
    echo "Next steps:"
    echo "1. Visit: $PAGES_URL"
    echo "2. Open browser console to see logs"
    echo "3. Click 'Add Feed' to add your first RSS feed"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⏳ Site not yet deployed (404)"
    echo ""
    echo "Possible reasons:"
    echo "1. GitHub Actions still running"
    echo "2. GitHub Pages not enabled in settings"
    echo "3. Waiting for Pages to build (can take 2-5 minutes)"
    echo ""
    echo "Action required:"
    echo "1. Visit: https://github.com/$REPO/actions"
    echo "2. Check if workflow completed (green checkmark)"
    echo "3. Visit: https://github.com/$REPO/settings/pages"
    echo "4. Enable Pages: Source = gh-pages branch"
else
    echo "⚠️  Unexpected HTTP code: $HTTP_CODE"
fi

echo ""
echo "🔗 Quick Links:"
echo "   Actions: https://github.com/$REPO/actions"
echo "   Settings: https://github.com/$REPO/settings/pages"
echo "   Live Site: $PAGES_URL"
