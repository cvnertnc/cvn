# 🚀 CVN Package Installation Guide 🚀

Download and install the CVN tool for managing GitHub repositories. Works on both Termux (Android) and Ubuntu (Linux).

## 📼 Example Usage Video
[Watch the video for CVN usage](https://t.me/cvnertnc/158)

## 📦 Package Includes:
- CVN script for managing/downloading repos.
- Config files: `config.json`, `path.json`.
- Dependencies: `jq`, `git`, `wget`, `lynx`.

## ⬇️ Download:
- **Ubuntu**: [cvn-package-ubuntu.deb](https://github.com/cvnertnc/cvn/releases/latest)
- **Termux**: [cvn-package-termux.tar.gz](https://github.com/cvnertnc/cvn/releases/latest)

## 🛠️ Ubuntu Installation:
1. **Install:**
```bash
sudo dpkg -i cvn-package-ubuntu.deb
sudo apt install -f
```

2. Test:

```bash
cvn -h
```

📱 Termux Installation:

1. Extract:

```bash
tar -xzvf cvn-package-termux.tar.gz -C $PREFIX
```

2. Install dependencies:

```bash
pkg install jq git wget lynx
```

3. Test:

```bash
cvn -h
```

❓ Help & Support:

Commands: cvn -h

Report issues: [Telegram Group](https://t.me/cvnertnc_chat)

Developer: https://t.me/the_CEHunter

Enjoy! 🎉
