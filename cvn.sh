#!/bin/bash

CONFIG_FILE="config.json"
DOWNLOAD_DIR="downloads"
PATH_FILE="path.json"
BASE_DIR="."

# Function to display help information
show_help() {
    echo "Usage: $0 {-a|-d|-f|-h}"
    echo
    echo "Commands:"
    echo "  -a, add       Add a repository to the configuration file."
    echo "  -d, download   Download repositories."
    echo "                Use '-d n' for dark.sh logic, '-d r' for stab.sh logic, and '-d a' for all."
    echo "  -f, folder    Set the base directory for the configuration file and downloads."
    echo "  -h, help      Display this help message."
    echo
    echo "Examples:"
    echo "  $0 -a                  Add a new repository."
    echo "  $0 -d n                Download using dark.sh logic."
    echo "  $0 -d r                Download using stab.sh logic."
    echo "  $0 -d a                Download all repositories regardless of mode."
    echo "  $0 -f /path/to/dir    Set the base directory to '/path/to/dir'."
}

# Function to set the directory path
set_directory() {
    if [[ -n "$1" ]]; then
        BASE_DIR="$1"
        CONFIG_FILE="$BASE_DIR/$CONFIG_FILE"
        DOWNLOAD_DIR="$BASE_DIR/$DOWNLOAD_DIR"
        mkdir -p "$DOWNLOAD_DIR"
        echo "Directory set to: $BASE_DIR"

        # Save the directory path to path.json
        echo '{"base_dir": "'"$BASE_DIR"'"}' | jq '.' > "$PATH_FILE"
    else
        echo "Usage: cvn -f <path>"
        exit 1
    fi
}

# Function to load the directory path from path.json
load_directory() {
    if [[ -f "$PATH_FILE" ]]; then
        BASE_DIR=$(jq -r '.base_dir' "$PATH_FILE")
        CONFIG_FILE="$BASE_DIR/$CONFIG_FILE"
        DOWNLOAD_DIR="$BASE_DIR/$DOWNLOAD_DIR"
        mkdir -p "$DOWNLOAD_DIR"
    fi
}

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

    if [[ ! "$repo_url" =~ ^https://github.com/([^/]+)/([^/]+)/?$ ]]; then
        echo "Invalid URL format!"
        exit 1
    fi

    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"

    branches=$(git ls-remote --heads "$repo_url" | awk -F'/' '{print $3}')

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

    echo "Select the mode (dark/stab/all):"
    select mode in dark stab all; do
        if [[ -n "$mode" ]]; then
            break
        fi
    done

    repo_info=$(jq -n --arg owner "$owner" --arg repo "$repo" --arg branch "$branch" --arg workflow "$workflow" --arg mode "$mode" \
        '{owner: $owner, repo: $repo, branch: $branch, workflow: $workflow, mode: $mode}')

    if [[ -f "$CONFIG_FILE" ]]; then
        jq --argjson new_repo "$repo_info" '.repos += [$new_repo]' "$CONFIG_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
    else
        echo '{"repos": []}' | jq --argjson new_repo "$repo_info" '.repos += [$new_repo]' > "$CONFIG_FILE"
    fi

    echo "Repository added to $CONFIG_FILE"
}

# Function to download repositories using dark.sh logic
download_with_dark() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "No configuration file found."
        exit 1
    fi

    mkdir -p "$DOWNLOAD_DIR"

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
    echo "Downloading file to $DOWNLOAD_DIR..."
    wget -O "$DOWNLOAD_DIR/${repo_name}_${workflow}.zip" "$download_url"
    echo "File downloaded: $DOWNLOAD_DIR/${repo_name}_${workflow}.zip"
}

# Function to download repositories using stab.sh logic
download_with_stab() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "No configuration file found."
        exit 1
    fi

    mkdir -p "$DOWNLOAD_DIR"

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

            break
        fi
    done

    release_info=$(curl -s "https://api.github.com/repos/$owner/$repo_name/releases/latest")
    asset_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url')

    if [[ -z "$asset_url" ]] || [[ "$asset_url" == "null" ]]; then
        echo "No release found or no asset available!"
        exit 1
    fi

    echo "Downloading: $asset_url"
    wget -q --show-progress -O "$DOWNLOAD_DIR/${asset_url##*/}" "$asset_url"
    echo "Download complete! File: $DOWNLOAD_DIR/${asset_url##*/}"
}

# Function to download all repositories regardless of mode
download_all() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "No configuration file found."
        exit 1
    fi

    mkdir -p "$DOWNLOAD_DIR"

    repos=$(jq -r '.repos[] | "\(.owner)/\(.repo)"' "$CONFIG_FILE")

    if [[ -z "$repos" ]]; then
        echo "No repositories found in $CONFIG_FILE."
        exit 1
    fi

    for repo in $repos; do
        owner=$(echo "$repo" | awk -F'/' '{print $1}')
        repo_name=$(echo "$repo" | awk -F'/' '{print $2}')

        branch=$(jq -r --arg owner "$owner" --arg repo "$repo_name" '.repos[] | select(.owner == $owner and .repo == $repo) | .branch' "$CONFIG_FILE")
        workflow=$(jq -r --arg owner "$owner" --arg repo "$repo_name" '.repos[] | select(.owner == $owner and .repo == $repo) | .workflow' "$CONFIG_FILE")
        mode=$(jq -r --arg owner "$owner" --arg repo "$repo_name" '.repos[] | select(.owner == $owner and .repo == $repo) | .mode' "$CONFIG_FILE")

        if [[ "$mode" == "dark" || "$mode" == "all" ]]; then
            nightly_url="https://nightly.link/$owner/$repo_name/workflows/$workflow/$branch"
            echo "Created Nightly.link URL: $nightly_url"

            echo "Available download links (only zip files) for $repo:"
            mapfile -t download_links < <(lynx -listonly -dump "$nightly_url" | sed 's/^[[:space:]]*[0-9]\+\.\s*//' | grep -i '\.zip')

            if [[ ${#download_links[@]} -eq 0 ]]; then
                echo "No download link found for $repo."
                continue
            fi

            select download_url in "${download_links[@]}"; do
                if [[ -n "$download_url" ]]; then
                    break
                fi
            done

            echo "Selected link: $download_url"
            echo "Downloading file to $DOWNLOAD_DIR..."
            wget -O "$DOWNLOAD_DIR/${repo_name}_${workflow}.zip" "$download_url"
            echo "File downloaded: $DOWNLOAD_DIR/${repo_name}_${workflow}.zip"
        elif [[ "$mode" == "stab" || "$mode" == "all" ]]; then
            release_info=$(curl -s "https://api.github.com/repos/$owner/$repo_name/releases/latest")
            asset_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url')

            if [[ -z "$asset_url" ]] || [[ "$asset_url" == "null" ]]; then
                echo "No release found or no asset available for $repo!"
                continue
            fi

            echo "Downloading: $asset_url"
            wget -q --show-progress -O "$DOWNLOAD_DIR/${asset_url##*/}" "$asset_url"
            echo "Download complete! File: $DOWNLOAD_DIR/${asset_url##*/}"
        fi
    done
}

# Main script logic
case $1 in
    -a|add)
        load_directory
        add_repo
        ;;
    -d|download)
        load_directory
        case $2 in
            n)
                download_with_dark
                ;;
            r)
                download_with_stab
                ;;
            a)
                download_all
                ;;
            *)
                echo "Usage: $0 -d {n|r|a}"
                exit 1
                ;;
        esac
        ;;
    -f|folder)
        set_directory "$2"
        ;;
    -h|help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac

