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

# En uygun indirme bağlantısını al ve dosyayı indir
download_url=$(lynx -listonly -nonumbers -dump "$nightly_url" | sed -n '2p')

if [[ -n "$download_url" ]]; then
    echo "Dosya indiriliyor: $download_url"
    wget -O "${repo}_${workflow}.zip" "$download_url"
    echo "Dosya indirildi: ${repo}_${workflow}.zip"
else
    echo "İndirme bağlantısı bulunamadı."
    exit 1
fi
