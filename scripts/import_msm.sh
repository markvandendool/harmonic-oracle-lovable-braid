#!/bin/bash
set -euo pipefail

# Script to import a repository as a squashed subtree
TARGET_REPO_SSH="$1"
MSM_REPO_SSH="$2"
SUBTREE_PATH="$3"
FEATURE_BRANCH="$4"

# Ensure all parameters are provided
if [ -z "$TARGET_REPO_SSH" ] || [ -z "$MSM_REPO_SSH" ] || [ -z "$SUBTREE_PATH" ] || [ -z "$FEATURE_BRANCH" ]; then
  echo "Usage: $0 TARGET_REPO_SSH MSM_REPO_SSH SUBTREE_PATH FEATURE_BRANCH"
  exit 1
fi

# Check if git-lfs is installed
if ! command -v git-lfs >/dev/null 2>&1; then
  echo "Warning: git-lfs not installed. Large files may cause issues."
  echo "Install with: brew install git-lfs && git lfs install"
fi

# Create and checkout feature branch
git checkout -b "$FEATURE_BRANCH"

# Add the subtree (squashed)
git subtree add --prefix="$SUBTREE_PATH" --squash "$MSM_REPO_SSH" master

# Configure Git LFS if large files are detected
if git ls-files | grep -E '\.(mp3|wav|flac)$'; then
  echo "Large media files detected, configuring Git LFS"
  git lfs track "*.mp3" "*.wav" "*.flac"
  git add .gitattributes
  git commit -m "Add Git LFS tracking for media files"
fi

# Push the feature branch
git push origin "$FEATURE_BRANCH"

# Print PR URL
OWNER=$(echo "$TARGET_REPO_SSH" | sed -E 's/.*:([^/]+)\/.*/\1/')
REPO=$(echo "$TARGET_REPO_SSH" | sed -E 's/.*\/([^.]+).*/\1/')
echo "Open PR: https://github.com/$OWNER/$REPO/compare/$FEATURE_BRANCH"
