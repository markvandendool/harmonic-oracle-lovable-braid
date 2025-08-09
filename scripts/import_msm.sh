#!/bin/bash
set -euo pipefail

# Script to import MillionSongMind as a squashed commit
TARGET_REPO_SSH="$1"
MSM_REPO_SSH="$2"
SUBTREE_PATH="$3"
FEATURE_BRANCH="$4"

# Ensure all parameters are provided
if [ -z "$TARGET_REPO_SSH" ] || [ -z "$MSM_REPO_SSH" ] || [ -z "$SUBTREE_PATH" ] || [ -z "$FEATURE_BRANCH" ]; then
  echo "Error: Usage: $0 TARGET_REPO_SSH MSM_REPO_SSH SUBTREE_PATH FEATURE_BRANCH"
  exit 1
fi

# Check if git-lfs is installed
if ! command -v git-lfs >/dev/null 2>&1; then
  echo "Warning: git-lfs not installed. Large files may cause issues."
  echo "Install with: brew install git-lfs && git lfs install"
fi

# Check if rsync is installed
if ! command -v rsync >/dev/null 2>&1; then
  echo "Error: rsync not installed. Install with: brew install rsync"
  exit 1
fi

# Ensure we're on main and up to date
git checkout main || { echo "Error: Failed to checkout main"; exit 1; }
git pull --ff-only || { echo "Error: Failed to pull main"; exit 1; }

# Create and checkout feature branch
git checkout -b "$FEATURE_BRANCH" || { echo "Error: Failed to create branch $FEATURE_BRANCH"; exit 1; }

# Clone MSM repo to a temporary directory
TEMP_DIR=$(mktemp -d)
git clone "$MSM_REPO_SSH" "$TEMP_DIR" || { echo "Error: Failed to clone $MSM_REPO_SSH"; exit 1; }
cd "$TEMP_DIR"
git checkout master || { echo "Error: Failed to checkout master"; exit 1; }
cd -

# Copy MSM files to SUBTREE_PATH, including hidden files
mkdir -p "$SUBTREE_PATH" || { echo "Error: Failed to create $SUBTREE_PATH"; exit 1; }
rsync -a --exclude='.git' "$TEMP_DIR/" "$SUBTREE_PATH/" || { echo "Error: Failed to copy files to $SUBTREE_PATH"; exit 1; }

# Add and commit the squashed import
git add "$SUBTREE_PATH" || { echo "Error: Failed to add $SUBTREE_PATH"; exit 1; }
git commit -m "Squashed import of MillionSongMind into $SUBTREE_PATH" || { echo "Error: Failed to commit"; exit 1; }

# Clean up temporary clone
rm -rf "$TEMP_DIR"

# Configure Git LFS if large files are detected
if git ls-files | grep -E '\.(mp3|wav|flac)$'; then
  echo "Large media files detected, configuring Git LFS"
  git lfs track "*.mp3" "*.wav" "*.flac" || { echo "Error: Failed to track LFS files"; exit 1; }
  git add .gitattributes || { echo "Error: Failed to add .gitattributes"; exit 1; }
  git commit -m "Add Git LFS tracking for media files" || { echo "Error: Failed to commit LFS tracking"; exit 1; }
fi

# Push the feature branch
git push origin "$FEATURE_BRANCH" || { echo "Error: Failed to push $FEATURE_BRANCH"; exit 1; }

# Print PR URL
OWNER=$(echo "$TARGET_REPO_SSH" | sed -E 's/.*:([^/]+)\/.*/\1/')
REPO=$(echo "$TARGET_REPO_SSH" | sed -E 's/.*\/([^.]+).*/\1/')
echo "Open PR: https://github.com/$OWNER/$REPO/compare/$FEATURE_BRANCH"
