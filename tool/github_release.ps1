# Publish BT Messenger to GitHub Releases (Android APK)
# Run in PowerShell from project root after: gh auth login

$ErrorActionPreference = "Stop"
$env:Path = "C:\Program Files\GitHub CLI;" + $env:Path

Write-Host "BT Messenger - GitHub Release" -ForegroundColor Green

# Check GitHub login
try {
    gh auth status | Out-Null
} catch {
    Write-Host "`nGitHub login required. Run:" -ForegroundColor Yellow
    Write-Host "  gh auth login" -ForegroundColor Cyan
    Write-Host "Then run this script again.`n"
    exit 1
}

Set-Location $PSScriptRoot\..

$repoName = "Blutooth-messeager"
$remoteUrl = "https://github.com/mohanrajcyber/Blutooth-messeager.git"
$tag = "v0.1.0"

# Create repo if missing
$remotes = git remote 2>$null
if (-not ($remotes -contains "origin")) {
    Write-Host "Adding remote: $remoteUrl" -ForegroundColor Cyan
    git remote add origin $remoteUrl
} else {
    git remote set-url origin $remoteUrl
    Write-Host "Remote set to: $remoteUrl" -ForegroundColor Gray
}

Write-Host "Pushing code..." -ForegroundColor Cyan
git push -u origin main

# Create tag if not exists
$existingTag = git tag -l $tag
if (-not $existingTag) {
    Write-Host "Creating tag $tag..." -ForegroundColor Cyan
    git tag $tag
    git push origin $tag
} else {
    Write-Host "Tag $tag already exists. Push again to re-run build:" -ForegroundColor Yellow
    Write-Host "  git push origin $tag" -ForegroundColor Cyan
}

Write-Host "`nGitHub Actions is building your APK..." -ForegroundColor Green
Write-Host "Watch progress:" -ForegroundColor Gray
Write-Host "  gh run list --workflow=release-apk.yml" -ForegroundColor Cyan

$user = gh api user -q .login
Write-Host "`nShare this install link when build finishes (~5 min):" -ForegroundColor Green
Write-Host "  https://github.com/$user/$repoName/releases/latest" -ForegroundColor Yellow
