# After `gh auth login`, run from project root:

# 1. Create public repo (change username if needed)
gh repo create bluetooth-messenger --public --source=. --remote=origin --description "Offline Bluetooth messenger with WhatsApp-style UI"

# 2. Push code
git push -u origin main

# 3. Create release tag (triggers APK build)
git tag v0.1.0
git push origin v0.1.0

# 4. Watch build
gh run list --workflow=release-apk.yml

# 5. When done, share this link:
# https://github.com/YOUR_USERNAME/bluetooth-messenger/releases/latest
