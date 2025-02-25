#!/bin/bash

# Required tools check
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed. Please install jq."
    exit 1
fi
if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed. Please install git."
    exit 1
fi
if ! command -v wget &> /dev/null; then
    echo "ERROR: wget is not installed. Please install wget."
    exit 1
fi

# Get repo URL
read -p "Enter the GitHub repository URL: " repo_url

# URL validation
if [[ ! "$repo_url" =~ ^https://github.com/([^/]+)/([^/]+)/?$ ]]; then
    echo "Invalid URL format!"
    exit 1
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"

# List branches
echo "Fetching branches..."
branches=$(git ls-remote --heads "$repo_url" | awk -F'/' '{print $3}')

if [ -z "$branches" ]; then
    read -p "Could not retrieve branches automatically. Please enter the branch name manually: " selected_branch
else
    IFS=$'\n' read -rd '' -a branch_array <<< "$branches"

    # Branch selection
    PS3="Select a branch (1-${#branch_array[@]}): "
    select selected_branch in "${branch_array[@]}"; do
        [[ -n $selected_branch ]] && break
        echo "Invalid selection!"
    done
fi

# Find the latest release
echo "Searching for the latest release..."
release_info=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/latest")
asset_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url')

if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
    echo "No release found or no asset available!"
    exit 1
fi

# Download process
echo "Downloading: $asset_url"
wget -q --show-progress -O "${asset_url##*/}" "$asset_url"

echo "Download complete! File: ${asset_url##*/}"
