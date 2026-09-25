# YFC Fellowship Landing Page Deployment Script
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "   YFC Fellowship Landing Page Deployment    " -ForegroundColor Red
Write-Host "=============================================" -ForegroundColor Yellow

# 1. Ensure app_icon.png exists in web directory
if (-not (Test-Path "web\app_icon.png")) {
    Copy-Item -Path "assets\images\app_icon.png" -Destination "web\app_icon.png" -Force
    Write-Host "[✓] Copied glowing ruby-and-gold YFC logo asset to web/app_icon.png" -ForegroundColor Green
} else {
    Write-Host "[✓] YFC logo emblem present at web/app_icon.png" -ForegroundColor Green
}

# 2. Ensure index.html exists
if (-not (Test-Path "web\index.html")) {
    Copy-Item -Path "web\landing_page.html" -Destination "web\index.html" -Force
    Write-Host "[✓] Created web/index.html from landing_page.html" -ForegroundColor Green
} else {
    Write-Host "[✓] Landing page entrypoint ready at web/index.html" -ForegroundColor Green
}

Write-Host "`nDeployment Commands for Platforms:" -ForegroundColor Yellow

Write-Host "`n--- 1. Vercel Deployment (Instant Global CDN) ---" -ForegroundColor Cyan
Write-Host "Command: npx vercel deploy --prod web" -ForegroundColor White
Write-Host "Direct Temporary URL: npx vercel deploy --temporary web" -ForegroundColor White

Write-Host "`n--- 2. GitHub Pages Deployment ---" -ForegroundColor Cyan
Write-Host "Command: npx gh-pages -d web" -ForegroundColor White

Write-Host "`n--- 3. Firebase Hosting Deployment ---" -ForegroundColor Cyan
Write-Host "Command: firebase deploy --only hosting" -ForegroundColor White

Write-Host "`n--- 4. Local Test Preview Server ---" -ForegroundColor Cyan
Write-Host "Command: npx serve web" -ForegroundColor White
