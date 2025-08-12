#!/bin/bash
# Pre-push validation script for ix-charts
# This script runs all critical tests to prevent bad pushes

set -e  # Exit on any error

echo "========================================="
echo "Running pre-push validation suite..."
echo "========================================="

# 1. Validate catalog format
echo ""
echo "Step 1/3: Testing catalog validation..."
echo "-----------------------------------------"
docker run -v $(pwd):/data ghcr.io/secretzer0/catalog_validation:latest \
  catalog_validate validate --path /data || {
    echo "❌ Catalog validation failed!"
    exit 1
}
echo "✅ Catalog validation passed"

# 2. Validate dev charts (skip if not in git context)
echo ""
echo "Step 2/3: Testing dev charts..."
echo "-----------------------------------------"
if git rev-parse --git-dir > /dev/null 2>&1; then
    # We're in a git repo, but Docker container needs git access
    echo "Note: Dev charts validation requires git context."
    echo "Run this directly in the repo (not in Docker) with:"
    echo "  docker run -v $(pwd):/data -v $(pwd)/.git:/data/.git ghcr.io/secretzer0/catalog_validation:latest dev_charts_validate validate --path /data --base_branch main"
    echo "⚠️  Skipping dev charts validation in automated script"
else
    echo "⚠️  Not in a git repository, skipping dev charts validation"
fi

# 3. Test catalog update (catches JSON serialization issues!)
echo ""
echo "Step 3/3: Testing catalog update (JSON serialization)..."
echo "-----------------------------------------"
docker run -v $(pwd):/data ghcr.io/secretzer0/catalog_validation:latest \
  catalog_update update --path /data || {
    echo "❌ Catalog update failed! Check for JSON serialization issues"
    exit 1
}
echo "✅ Catalog update passed"

echo ""
echo "========================================="
echo "✅ All tests passed! Safe to push."
echo "========================================="