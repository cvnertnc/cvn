#!/bin/bash

CONFIG_FILE="config.json"

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

# Function to add a repository to config.json
add_repo() {
    read -p "Enter the GitHub repository URL: " repo_url

    if [[ ! "$repo_url" =~ ^https://github.com/([^/]+)/([^/]+)$ ]]; then
        echo "You did not enter a valid GitHub URL."
        exit 1
    fi

    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"

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

    repo_info=$(jq -n --arg owner "$owner" --arg repo "$repo" --arg branch "$branch" --arg workflow "$workflow" \
        '{owner: $owner, repo: $repo, branch: $branch, workflow: $workflow}')

    if [[ -f "$CONFIG_FILE" ]]; then
        jq --argjson new_repo "$repo_info" '.repos += [$new_repo]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
    else
        echo '{"repos": []}' | jq --argjson new_repo "$repo_info" '.repos += [$new_repo]' > "$CONFIG_FILE"
    fi

    echo "Repository added to $CONFIG_FILE"
}

# Function to download repositories from config.json
download_repos() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "No configuration file found."
        exit 1
    fi

    repos=$(jq -r '.repos[] | "\(.owner)/\(.repo)"' "$CONFIG_FILE")

    if [[ -z "$repos" ]]; then
        echo "No repositories found in $CONFIG_FILE."
        exit 1
    fi

    echo "Select a repository to download:"
    select repo in $repos; do
        if [[ -n "$repo" ]]; then
            owner=$(echo "$repo" | awk -F'/' '{print $1}')
            repo_name=$(echo "$repo" | awk -F'/' '{print $2}')

            branch=$(jq -r --arg owner "$owner" --arg repo "$repo_name" '.repos[] | select(.owner == $owner and .repo == $repo) | .branch' "$CONFIG_FILE")
            workflow=$(jq -r --arg owner "$owner" --arg repo "$repo_name" '.repos[] | select(.owner == $owner and .repo == $repo) | .workflow' "$CONFIG_FILE")

            break
        fi
    done

    nightly_url="https://nightly.link/$owner/$repo_name/workflows/$workflow/$branch"
    echo "Created Nightly.link URL: $nightly_url"

    echo "Available download links (only zip files):"
    mapfile -t download_links < <(lynx -listonly -dump "$nightly_url" | sed 's/^[[:space:]]*[0-9]\+\.\s*//' | grep -i '\.zip')

    if [[ ${#download_links[@]} -eq 0 ]]; then
        echo "No download link found."
        exit 1
    fi

    select download_url in "${download_links[@]}"; do
        if [[ -n "$download_url" ]]; then
            break
        fi
    done

    echo "Selected link: $download_url"
    echo "Downloading file..."
    wget -O "${repo_name}_${workflow}.zip" "$download_url"
    echo "File downloaded: ${repo_name}_${workflow}.zip"
}

# Main script logic
case $1 in
    add)
        add_repo
        ;;
    download)
        download_repos
        ;;
    *)
        echo "Usage: $0 {add|download}"
        exit 1
        ;;
esac

