#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# Monitor GitHub Actions build status

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║          SecureOS - GitHub Actions Build Monitor                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Monitoring the ISO build on GitHub Actions..."
echo "This will take approximately 40-60 minutes."
echo ""

while true; do
    clear
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║          SecureOS - GitHub Actions Build Monitor                 ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Last updated: $(date)"
    echo ""
    
    gh run list --workflow=build-iso.yml --limit 1
    echo ""
    
    # Get latest run ID
    RUN_ID=$(gh run list --workflow=build-iso.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    
    if [ -n "$RUN_ID" ]; then
        echo "Run ID: $RUN_ID"
        echo ""
        echo "To view live logs in browser:"
        echo "  https://github.com/ssfdre38/SecureOS/actions/runs/$RUN_ID"
        echo ""
        echo "To view logs in terminal:"
        echo "  gh run view $RUN_ID --log"
        echo ""
        
        # Check if completed
        STATUS=$(gh run list --workflow=build-iso.yml --limit 1 --json status --jq '.[0].status')
        if [ "$STATUS" = "completed" ]; then
            CONCLUSION=$(gh run list --workflow=build-iso.yml --limit 1 --json conclusion --jq '.[0].conclusion')
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            if [ "$CONCLUSION" = "success" ]; then
                echo "✅ BUILD SUCCESSFUL!"
                echo ""
                echo "Download the ISO:"
                echo "  gh run download $RUN_ID"
                echo ""
                echo "Or visit:"
                echo "  https://github.com/ssfdre38/SecureOS/actions/runs/$RUN_ID"
            else
                echo "❌ BUILD FAILED: $CONCLUSION"
                echo ""
                echo "View error logs:"
                echo "  gh run view $RUN_ID --log-failed"
            fi
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            break
        fi
    fi
    
    echo "Press Ctrl+C to stop monitoring"
    sleep 30
done
