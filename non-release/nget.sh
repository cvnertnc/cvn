#!/bin/bash

# Kullanıcıdan GitHub repo URL'sini al
read -p "GitHub repository URL'sini girin: " repo_url

# Geçerli bir GitHub URL'si mi kontrol et
if [[ ! "$repo_url" =~ ^https://github.com/([^/]+)/([^/]+)$ ]]; then
    echo "Geçerli bir GitHub URL'si girmediniz."
    exit 1
fi

owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"

# Branch listesini al
branches=$(git ls-remote --heads "https://github.com/$owner/$repo.git" | awk -F'/' '{print $3}')
echo "Mevcut branch'ler:"
select branch in $branches; do
    if [[ -n "$branch" ]]; then
        break
    fi
done

# Workflow dosyalarını al (GitHub API kullanarak .yml dosyalarını alıyoruz)
workflows=$(curl -s "https://api.github.com/repos/$owner/$repo/contents/.github/workflows?ref=$branch" | jq -r '.[].name' | sed 's/\.yml$//')

# Workflow dosyalarını listele
echo "Mevcut workflow dosyaları:"
select workflow in $workflows; do
    if [[ -n "$workflow" ]]; then
        break
    fi
done

# Nightly.link URL'sini oluştur
nightly_url="https://nightly.link/$owner/$repo/workflows/$workflow/$branch"
echo "Oluşturulan Nightly.link URL'si: $nightly_url"

# Lynx ile indirilebilir bağlantıları listele, sadece .zip dosyalarını filtrele
echo "Mevcut indirme bağlantıları (sadece zip dosyaları):"
mapfile -t download_links < <(lynx -listonly -dump "$nightly_url" | sed 's/^[[:space:]]*[0-9]\+\.\s*//' | grep -i '\.zip')

if [[ ${#download_links[@]} -eq 0 ]]; then
    echo "İndirme bağlantısı bulunamadı."
    exit 1
fi

# Kullanıcıya indirme bağlantılarından seçim yaptır
select download_url in "${download_links[@]}"; do
    if [[ -n "$download_url" ]]; then
        break
    fi
done

echo "Seçilen bağlantı: $download_url"
echo "Dosya indiriliyor..."
wget -O "${repo}_${workflow}.zip" "$download_url"
echo "Dosya indirildi: ${repo}_${workflow}.zip"