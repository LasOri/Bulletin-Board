#!/bin/bash

# Wait for GitHub Actions to complete and gh-pages to be created

echo "⏳ Waiting for GitHub Actions to complete..."
echo "This usually takes 5-10 minutes"
echo ""
echo "🔗 Watch live: https://github.com/LasOri/Bulletin-Board/actions"
echo ""

COUNT=0
MAX_WAIT=20  # Check for 10 minutes (20 * 30 seconds)

while [ $COUNT -lt $MAX_WAIT ]; do
    # Fetch latest from remote
    git fetch --quiet origin 2>/dev/null

    # Check if gh-pages exists
    if git branch -r | grep -q "origin/gh-pages"; then
        echo ""
        echo "🎉 SUCCESS! gh-pages branch has been created!"
        echo ""
        echo "✅ Workflow completed successfully"
        echo ""
        echo "📋 Next Steps:"
        echo ""
        echo "1. Enable GitHub Pages:"
        echo "   https://github.com/LasOri/Bulletin-Board/settings/pages"
        echo ""
        echo "2. Configure:"
        echo "   • Source: Deploy from a branch"
        echo "   • Branch: gh-pages"
        echo "   • Folder: / (root)"
        echo "   • Click: Save"
        echo ""
        echo "3. Wait 1-2 minutes for Pages to build"
        echo ""
        echo "4. Visit your live site:"
        echo "   https://lasori.github.io/Bulletin-Board/"
        echo ""
        exit 0
    fi

    COUNT=$((COUNT + 1))
    ELAPSED=$((COUNT * 30))
    echo "[$ELAPSED seconds] Still building... (Check: $COUNT/$MAX_WAIT)"
    sleep 30
done

echo ""
echo "⏰ 10 minutes elapsed. Checking status..."
echo ""
echo "Please check manually:"
echo "  Actions: https://github.com/LasOri/Bulletin-Board/actions"
echo "  Branches: git fetch && git branch -r"
echo ""
echo "If the workflow is still running, wait a bit longer."
echo "If it failed, click on the workflow to see error logs."
