#!/bin/bash

CONFIG_FILE="/sdcard/cvn/config.json"
BASE_DIR="/sdcard/cvn"

# Required command checks
if ! command -v jq &> /dev/null; then
    echo "jq command not found. Please install jq."
    exit 1
fi
if ! command -v git &> /dev/null; then
    echo "git command not found. Please install git."
    exit 1
fi
if ! command -v lynx &> /dev/null; then
    echo "lynx command not found. Please install lynx."
    exit 1
fi

# File and directory checks
mkdir -p "$BASE_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"mode": "release", "repositories": []}' > "$CONFIG_FILE"
fi

main_menu() {
    clear
    echo "MENU"
    echo "1-Download"
    echo "2-Settings"
    echo "3-Exit"
    echo
    read -p "Your choice: " choice

    case $choice in
        1) download ;;
        2) settings ;;
        3) exit 0 ;;
        *) echo "Invalid choice!"; sleep 1; main_menu ;;
    esac
}

settings() {
    while true; do
        clear
        current_mode=$(jq -r '.mode' "$CONFIG_FILE")
        echo "SETTINGS"
        echo "1. Change Mode (Current: $current_mode)"
        echo "2. Add Repo"
        echo "3. Check Config File"
        echo "4. Return to Main Menu"
        echo
        read -p "Your choice [1-4]: " settings_choice

        case $settings_choice in
            1) change_mode ;;
            2) add_repo ;;
            3) check_repo_config ;;
            4) break ;;
            *) echo "Invalid choice!"; sleep 1 ;;
        esac
    done
    main_menu
}

change_mode() {
    while true; do
        clear
        current_mode=$(jq -r '.mode' "$CONFIG_FILE")
        echo "Change Mode (Current: $current_mode)"
        echo
        echo "1. Release"
        echo "2. Nightly"
        echo "3. Exit"
        echo
        read -p "Your choice [1-3]: " mode_choice

        case $mode_choice in
            1) new_mode="release" ;;
            2) new_mode="nightly" ;;
            3) return ;;
            *) echo "Invalid choice!"; sleep 1; continue ;;
        esac

        jq --arg new_mode "$new_mode" '.mode = $new_mode' "$CONFIG_FILE" > temp.json && mv temp.json "$CONFIG_FILE"
        echo "Mode changed: $new_mode"
        sleep 1
        break
    done
}

add_repo() {
    clear
    echo "Add New Repo"
    read -p "Repo Link (example: https://github.com/owner/repo): " repo_url

    # URL validation
    if [[ ! "$repo_url" =~ ^https://github.com/([^/]+)/([^/]+)$ ]]; then
        echo "Invalid GitHub URL format!"
        sleep 1
        return
    fi

    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"

    # Branch selection
    echo "Fetching branches..."
    branches=($(git ls-remote --heads "$repo_url" | awk -F'/' '{print $3}'))

    if [ ${#branches[@]} -eq 0 ]; then
        echo "Error: No branches found!"
        sleep 1
        return
    fi

    PS3="Select a branch (1-${#branches[@]}): "
    select branch in "${branches[@]}"; do
        [[ -n $branch ]] && break
        echo "Invalid selection!"
    done

    # Mode selection
    PS3="Select a mode: "
    select mode in "release" "nightly"; do
        [[ -n $mode ]] && break
        echo "Invalid selection!"
    done

    # Nightly specific config
    workflow=""
    if [ "$mode" = "nightly" ]; then
        echo "Searching for workflow files..."
        workflows_response=$(curl -s "https://api.github.com/repos/$owner/$repo/contents/.github/workflows?ref=$branch")

        if [ $? -ne 0 ]; then
            echo "Workflow not found!"
            read -p "Enter workflow name: " workflow
        else
            workflows=($(echo "$workflows_response" | jq -r '.[].name' | grep -E '\.ya?ml$' | sed 's/\.ya\?ml$//'))

            if [ ${#workflows[@]} -eq 0 ]; then
                echo "Workflow file not found!"
                read -p "Enter workflow name: " workflow
            else
                PS3="Select a workflow: "
                select workflow in "${workflows[@]}"; do
                    [[ -n $workflow ]] && break
                    echo "Invalid selection!"
                done
            fi
        fi
    fi

    # Save to config
    jq --arg repo "$repo_url" \
       --arg branch "$branch" \
       --arg mode "$mode" \
       --arg workflow "$workflow" \
       '.repositories += [{"repo": $repo, "branch": $branch, "mode": $mode, "workflow": $workflow}]' \
       "$CONFIG_FILE" > temp.json && mv temp.json "$CONFIG_FILE"

    echo "Repo added!"
    sleep 1
}

check_repo_config() {
    clear
    echo "=== REPO CONFIG CHECK ==="
    repo_count=$(jq '.repositories | length' "$CONFIG_FILE")

    if [ "$repo_count" -eq 0 ]; then
        echo "No repos found in the config file."
        read -p "Press Enter to continue..."
        return
    fi

    has_error=0

    for ((i=0; i<repo_count; i++)); do
        repo_url=$(jq -r ".repositories[$i].repo" "$CONFIG_FILE")
        branch=$(jq -r ".repositories[$i].branch" "$CONFIG_FILE")
        mode=$(jq -r ".repositories[$i].mode" "$CONFIG_FILE")
        workflow=$(jq -r ".repositories[$i].workflow" "$CONFIG_FILE")

        echo "Checking: $repo_url"

        # Branch check
        if [ -z "$branch" ]; then
            echo "  -> Error: Branch value is empty!"
            has_error=1
        fi

        # Mode check
        if [[ "$mode" != "release" && "$mode" != "nightly" ]]; then
            echo "  -> Error: Mode value is invalid! ($mode)"
            has_error=1
        fi

        # Workflow check for nightly mode
        if [ "$mode" = "nightly" ] && [ -z "$workflow" ]; then
            echo "  -> Error: Workflow value is empty or invalid in nightly mode!"
            has_error=1
        fi

        echo
    done

    if [ $has_error -eq 0 ]; then
        echo "All repo settings are valid."
    else
        echo "Please review the errors above."
    fi

    read -p "Press Enter to continue..."
}

download() {
    clear
    repositories=$(jq -c '.repositories[]' "$CONFIG_FILE")

    while read -r repo; do
        repo_url=$(echo "$repo" | jq -r '.repo')
        branch=$(echo "$repo" | jq -r '.branch')
        mode=$(echo "$repo" | jq -r '.mode')
        workflow=$(echo "$repo" | jq -r '.workflow')

        # Extract owner/repo from URL
        [[ $repo_url =~ https://github.com/([^/]+)/([^/]+) ]]
        owner="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"

        echo "Processing: $owner/$repo_name ($mode)"
        mkdir -p "$BASE_DIR/$owner/$repo_name"

        if [ "$mode" = "release" ]; then
            # Release download logic
            latest_release=$(curl -s "https://api.github.com/repos/$owner/$repo_name/releases/latest" | jq -r '.assets[0].browser_download_url')
            if [ -n "$latest_release" ]; then
                echo "Downloading: $latest_release"
                wget -q --show-progress "$latest_release" -P "$BASE_DIR/$owner/$repo_name"
            else
                echo "Release not found!"
                read -p "Press Enter to continue..."
            fi
        else
            # Nightly download logic
            if [ -n "$workflow" ]; then
                nightly_url="https://nightly.link/$owner/$repo_name/workflows/$workflow/$branch"
                echo "Nightly Link: $nightly_url"

                # Extract download URL
                download_url=$(lynx -listonly -nonumbers -dump "$nightly_url" | grep -E '\.zip$' | head -1)

                if [ -n "$download_url" ]; then
                    echo "Downloading: $download_url"
                    wget -q --show-progress "$download_url" -O "$BASE_DIR/$owner/$repo_name/nightly_build.zip"
                else
                    echo "Download link not found!"
                    read -p "Press Enter to continue..."
                fi
            else
                echo "Workflow not defined!"
            fi
        fi
        echo
    done <<< "$repositories"

    echo "Process completed!"
    read -p "Press Enter to continue..."
    main_menu
}

main_menu
