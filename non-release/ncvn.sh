#!/bin/bash

CONFIG_FILE="/sdcard/cvn/config.json"
BASE_DIR="/sdcard/cvn"

# Required command checks
if ! command -v jq &> /dev/null; then
    echo "jq komutu bulunamadı. Lütfen jq'yu yükleyin."
    echo "jq command not found. Please install jq."
    exit 1
fi
if ! command -v git &> /dev/null; then
    echo "git komutu bulunamadı. Lütfen git'i yükleyin."
    echo "git command not found. Please install git."
    exit 1
fi
if ! command -v lynx &> /dev/null; then
    echo "lynx komutu bulunamadı. Lütfen lynx'i yükleyin."
    echo "lynx command not found. Please install lynx."
    exit 1
fi

# File and directory checks
mkdir -p "$BASE_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"mode": "release", "repositories": [], "language": ""}' > "$CONFIG_FILE"
fi

# Language selection
current_language=`${(jq -r '.language' "}$`CONFIG_FILE")
if [ "$current_language" == "" ]; then
    echo "Lütfen dil seçiniz / Please select a language:"
    echo "1- Türkçe"
    echo "2- English"
    read -p "Seçiminiz / Your choice [1-2]: " language_choice

    case $language_choice in
        1) selected_language="tr" ;;
        2) selected_language="en" ;;
        *) echo "Geçersiz seçim! / Invalid choice!"; exit 1 ;;
    esac

    jq --arg language "`${selected_language" '.language =}$`language' "`${CONFIG_FILE" > temp.json && mv temp.json "}$`CONFIG_FILE"
else
    selected_language=$current_language
fi

main_menu() {
    clear
    if [ "$selected_language" == "tr" ]; then
        echo "MENU"
        echo "1-İndir"
        echo "2-Ayarlar"
        echo "3-Çıkış"
        echo
        read -p "Seçiminiz: " choice
    else
        echo "MENU"
        echo "1-Download"
        echo "2-Settings"
        echo "3-Exit"
        echo
        read -p "Your choice: " choice
    fi

    case $choice in
        1) download ;;
        2) settings ;;
        3) exit 0 ;;
        *)
            if [ "$selected_language" == "tr" ]; then
                echo "Geçersiz seçim!"; sleep 1; main_menu
            else
                echo "Invalid choice!"; sleep 1; main_menu
            fi
            ;;
    esac
}

settings() {
    while true; do
        clear
        current_mode=`${(jq -r '.mode' "}$`CONFIG_FILE")
        if [ "$selected_language" == "tr" ]; then
            echo "AYARLAR"
            echo "1. Modu Değiştir (Mevcut: $current_mode)"
            echo "2. Repo Ekle"
            echo "3. Config dosyasını kontrol et"
            echo "4. Ana Menüye Dön"
            echo
            read -p "Seçiminiz [1-4]: " settings_choice
        else
            echo "SETTINGS"
            echo "1. Change Mode (Current: $current_mode)"
            echo "2. Add Repo"
            echo "3. Check Config File"
            echo "4. Return to Main Menu"
            echo
            read -p "Your choice [1-4]: " settings_choice
        fi

        case $settings_choice in
            1) change_mode ;;
            2) add_repo ;;
            3) check_repo_config ;;
            4) break ;;
            *)
                if [ "$selected_language" == "tr" ]; then
                    echo "Geçersiz seçim!"; sleep 1
                else
                    echo "Invalid choice!"; sleep 1
                fi
                ;;
        esac
    done
    main_menu
}

change_mode() {
    while true; do
        clear
        current_mode=`${(jq -r '.mode' "}$`CONFIG_FILE")
        if [ "$selected_language" == "tr" ]; then
            echo "Modu Değiştir (Mevcut: $current_mode)"
            echo
            echo "1. Release"
            echo "2. Nightly"
            echo "3. Çıkış"
            echo
            read -p "Seçiminiz [1-3]: " mode_choice
        else
            echo "Change Mode (Current: $current_mode)"
            echo
            echo "1. Release"
            echo "2. Nightly"
            echo "3. Exit"
            echo
            read -p "Your choice [1-3]: " mode_choice
        fi

        case $mode_choice in
            1) new_mode="release" ;;
            2) new_mode="nightly" ;;
            3) return ;;
            *)
                if [ "$selected_language" == "tr" ]; then
                    echo "Geçersiz seçim!"; sleep 1; continue
                else
                    echo "Invalid choice!"; sleep 1; continue
                fi
                ;;
        esac

        jq --arg new_mode "`${new_mode" '.mode =}$`new_mode' "`${CONFIG_FILE" > temp.json && mv temp.json "}$`CONFIG_FILE"
        if [ "$selected_language" == "tr" ]; then
            echo "Mod değiştirildi: $new_mode"
        else
            echo "Mode changed: $new_mode"
        fi
        sleep 1
        break
    done
}

add_repo() {
    clear
    if [ "$selected_language" == "tr" ]; then
        echo "Yeni Repo Ekle"
        read -p "Repo Linki (örnek: https://github.com/owner/repo): " repo_url
    else
        echo "Add New Repo"
        read -p "Repo Link (example: https://github.com/owner/repo): " repo_url
    fi

    # URL validation
    if [[ ! "`${repo_url" =~ ^https://github.com/([^/]+)/([^/]+)}$` ]]; then
        if [ "$selected_language" == "tr" ]; then
            echo "Geçersiz GitHub URL formatı!"
        else
            echo "Invalid GitHub URL format!"
        fi
        sleep 1
        return
    fi

    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"

    # Branch selection
    if [ "$selected_language" == "tr" ]; then
        echo "Branch'ler alınıyor..."
    else
        echo "Fetching branches..."
    fi
    branches=(`${(git ls-remote --heads "}$`repo_url" | awk -F'/' '{print $3}'))

    if [ ${#branches[@]} -eq 0 ]; then
        if [ "$selected_language" == "tr" ]; then
            echo "Hata: Branch bulunamadı!"
        else
            echo "Error: No branches found!"
        fi
        sleep 1
        return
    fi

    PS3="Select a branch (1-${#branches[@]}): "
    select branch in "${branches[@]}"; do
        [[ -n $branch ]] && break
        if [ "$selected_language" == "tr" ]; then
            echo "Geçersiz seçim!"
        else
            echo "Invalid selection!"
        fi
    done

    # Mode selection
    PS3="Select a mode: "
    select mode in "release" "nightly"; do
        [[ -n $mode ]] && break
        if [ "$selected_language" == "tr" ]; then
            echo "Geçersiz seçim!"
        else
            echo "Invalid selection!"
        fi
    done

    # Nightly specific config
    workflow=""
    if [ "$mode" = "nightly" ]; then
        if [ "$selected_language" == "tr" ]; then
            echo "Workflow dosyaları aranıyor..."
        else
            echo "Searching for workflow files..."
        fi
        workflows_response=`${(curl -s "https://api.github.com/repos/}$`owner/`${repo/contents/.github/workflows?ref=}$`branch")

        if [ $? -ne 0 ]; then
            if [ "$selected_language" == "tr" ]; then
                echo "Workflow bulunamadı!"
                read -p "Workflow adı girin: " workflow
            else
                echo "Workflow not found!"
                read -p "Enter workflow name: " workflow
            fi
        else
            workflows=(`${(echo "}$`workflows_response" | jq -r '.[].name' | grep -E '\.ya?ml`${' | sed 's/\.ya\?ml}$`//'))

            if [ ${#workflows[@]} -eq 0 ]; then
                if [ "$selected_language" == "tr" ]; then
                    echo "Workflow dosyası bulunamadı!"
                    read -p "Workflow adı girin: " workflow
                else
                    echo "Workflow file not found!"
                    read -p "Enter workflow name: " workflow
                fi
            else
                PS3="Select a workflow: "
                select workflow in "${workflows[@]}"; do
                    [[ -n $workflow ]] && break
                    if [ "$selected_language" == "tr" ]; then
                        echo "Geçersiz seçim!"
                    else
                        echo "Invalid selection!"
                    fi
                done
            fi
        fi
    fi

    # Save to config
    jq --arg repo "$repo_url" \
       --arg branch "$branch" \
       --arg mode "$mode" \
       --arg workflow "$workflow" \
       '.repositories += [{"repo": `${repo, "branch":}$`branch, "mode": `${mode, "workflow":}$`workflow}]' \
       "`${CONFIG_FILE" > temp.json && mv temp.json "}$`CONFIG_FILE"

    if [ "$selected_language" == "tr" ]; then
        echo "Repo eklendi!"
    else
        echo "Repo added!"
    fi
    sleep 1
}

check_repo_config() {
    clear
    if [ "$selected_language" == "tr" ]; then
        echo "=== REPO AYAR KONTROLÜ ==="
    else
        echo "=== REPO CONFIG CHECK ==="
    fi
    repo_count=`${(jq '.repositories | length' "}$`CONFIG_FILE")

    if [ "$repo_count" -eq 0 ]; then
        if [ "$selected_language" == "tr" ]; then
            echo "Konfigürasyon dosyasında ekli repo bulunmuyor."
        else
            echo "No repos found in the config file."
        fi
        read -p "Press Enter to continue..."
        return
    fi

    has_error=0

    for ((i=0; i<repo_count; i++)); do
        repo_url=`${(jq -r ".repositories[}$`i].repo" "$CONFIG_FILE")
        branch=`${(jq -r ".repositories[}$`i].branch" "$CONFIG_FILE")
        mode=`${(jq -r ".repositories[}$`i].mode" "$CONFIG_FILE")
        workflow=`${(jq -r ".repositories[}$`i].workflow" "$CONFIG_FILE")

        if [ "$selected_language" == "tr" ]; then
            echo "Kontrol ediliyor: $repo_url"
        else
            echo "Checking: $repo_url"
        fi

        # Branch check
        if [ -z "$branch" ]; then
            if [ "$selected_language" == "tr" ]; then
                echo "  -> Hata: Branch değeri boş!"
            else
                echo "  -> Error: Branch value is empty!"
            fi
            has_error=1
        fi

        # Mode check
        if [[ "`${mode" != "release" && "}$`mode" != "nightly" ]]; then
            if [ "$selected_language" == "tr" ]; then
                echo "  -> Hata: Mode değeri geçersiz! ($mode)"
            else
                echo "  -> Error: Mode value is invalid! ($mode)"
            fi
            has_error=1
        fi

        # Workflow check for nightly mode
        if [ "`${mode" = "nightly" ] && [ -z "}$`workflow" ]; then
            if [ "$selected_language" == "tr" ]; then
                echo "  -> Hata: Nightly modunda workflow değeri boş veya geçersiz!"
            else
                echo "  -> Error: Workflow value is empty or invalid in nightly mode!"
            fi
            has_error=1
        fi

        echo
    done

    if [ $has_error -eq 0 ]; then
        if [ "$selected_language" == "tr" ]; then
            echo "Tüm repo ayarları uygun."
        else
            echo "All repo settings are valid."
        fi
    else
        if [ "$selected_language" == "tr" ]; then
            echo "Yukarıdaki hataları gözden geçiriniz."
        else
            echo "Please review the errors above."
        fi
    fi

    read -p "Press Enter to continue..."
}

download() {
    clear
    repositories=`${(jq -c '.repositories[]' "}$`CONFIG_FILE")

    while read -r repo; do
        repo_url=`${(echo "}$`repo" | jq -r '.repo')
        branch=`${(echo "}$`repo" | jq -r '.branch')
        mode=`${(echo "}$`repo" | jq -r '.mode')
        workflow=`${(echo "}$`repo" | jq -r '.workflow')

        # Extract owner/repo from URL
        [[ $repo_url =~ https://github.com/([^/]+)/([^/]+) ]]
        owner="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"

        if [ "$selected_language" == "tr" ]; then
            echo "İşleniyor: `${owner/}$`repo_name ($mode)"
        else
            echo "Processing: `${owner/}$`repo_name ($mode)"
        fi
        mkdir -p "`${BASE_DIR/}$`owner/$repo_name"

        if [ "$mode" = "release" ]; then
            # Release download logic
            latest_release=`${(curl -s "https://api.github.com/repos/}$`owner/$repo_name/releases/latest" | jq -r '.assets[0].browser_download_url')
            if [ -n "$latest_release" ]; then
                if [ "$selected_language" == "tr" ]; then
                    echo "İndiriliyor: $latest_release"
                else
                    echo "Downloading: $latest_release"
                fi
                wget -q --show-progress "`${latest_release" -P "}$`BASE_DIR/`${owner/}$`repo_name"
            else
                if [ "$selected_language" == "tr" ]; then
                    echo "Release bulunamadı!"
                else
                    echo "Release not found!"
                fi
                read -p "Press Enter to continue..."
            fi
        else
            # Nightly download logic
            if [ -n "$workflow" ]; then
                nightly_url="https://nightly.link/`${owner/}$`repo_name/workflows/`${workflow/}$`branch"
                if [ "$selected_language" == "tr" ]; then
                    echo "Nightly Link: $nightly_url"
                else
                    echo "Nightly Link: $nightly_url"
                fi

                # Extract download URL
                download_url=`${(lynx -listonly -nonumbers -dump "}$`nightly_url" | grep -E '\.zip$' | head -1)

                if [ -n "$download_url" ]; then
                    if [ "$selected_language" == "tr" ]; then
                        echo "İndiriliyor: $download_url"
                    else
                        echo "Downloading: $download_url"
                    fi
                    wget -q --show-progress "`${download_url" -O "}$`BASE_DIR/`${owner/}$`repo_name/nightly_build.zip"
                else
                    if [ "$selected_language" == "tr" ]; then
                        echo "İndirme bağlantısı bulunamadı!"
                    else
                        echo "Download link not found!"
                    fi
                    read -p "Press Enter to continue..."
                fi
            else
                if [ "$selected_language" == "tr" ]; then
                    echo "Workflow tanımlanmamış!"
                else
                    echo "Workflow not defined!"
                fi
            fi
        fi
        echo
    done <<< "$repositories"

    if [ "$selected_language" == "tr" ]; then
        echo "İşlem tamamlandı!"
    else
        echo "Process completed!"
    fi
    read -p "Press Enter to continue..."
    main_menu
}

main_menu
