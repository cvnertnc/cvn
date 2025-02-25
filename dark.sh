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

# Get the GitHub repo URL from the user
read -p "Enter the GitHub repository URL: " repo_url

# Check if it is a valid GitHub URL
if [[ ! "$repo_url" =~ ^https://github.com/([^/]+)/([^/]+)$ ]]; then
    echo "You did not enter a valid GitHub URL."
    exit 1
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"

# Get the list of branches
branches=$(git ls-remote --heads "https://github.com/$owner/$repo.git" | awk -F'/' '{print $3}')

if [[ -z "$branches" ]]; then
    read -p "Could not retrieve branches automatically. Please enter the branch name manually: " branch
else
    echo "Available branches:"
    select branch in $branches; do
        if [[ -n "$branch" ]]; then
            break
        fi
    done
fi

# Get workflow files (using GitHub API to get .yml files)
workflows=$(curl -s "https://api.github.com/repos/$owner/$repo/contents/.github/workflows?ref=$branch" | jq -r '.[].name' | sed 's/\.yml$//')

if [[ -z "$workflows" ]]; then
    read -p "Could not retrieve workflows automatically. Please enter the workflow name manually: " workflow
else
    echo "Available workflow files:"
    select workflow in $workflows; do
        if [[ -n "$workflow" ]]; then
            break
        fi
    done
fi

# Create Nightly.link URL
nightly_url="https://nightly.link/$owner/$repo/workflows/$workflow/$branch"
echo "Created Nightly.link URL: $nightly_url"

# List downloadable links with Lynx, filter only .zip files
echo "Available download links (only zip files):"
mapfile -t download_links < <(lynx -listonly -dump "$nightly_url" | sed 's/^[[:space:]]*[0-9]\+\.\s*//' | grep -i '\.zip')

if [[ ${#download_links[@]} -eq 0 ]]; then
    echo "No download link found."
    exit 1
fi

# Let the user choose from the download links
select download_url in "${download_links[@]}"; do
    if [[ -n "$download_url" ]]; then
        break
    fi
done

echo "Selected link: $download_url"
echo "Downloading file..."
wget -O "${repo}_${workflow}.zip" "$download_url"
echo "File downloaded: ${repo}_${workflow}.zip"
