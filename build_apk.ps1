# build_apk.ps1 — Build release APK and copy to Desktop for easy sharing
# Run from project root: .\build_apk.ps1

$ProjectRoot = $PSScriptRoot
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$OutputName  = "SLC_GPS_Map_Camera_Pro.apk"
$OutputPath  = Join-Path $DesktopPath $OutputName

# Known APK location (junction: android/app/build -> C:\builds\gps_app_build)
$JunctionApk = "C:\builds\gps_app_build\outputs\apk\release\app-release.apk"
# Standard Flutter output (when no junction is present)
$StandardApk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"

Write-Host "`n=== Building release APK ===" -ForegroundColor Cyan
Set-Location $ProjectRoot
flutter build apk --release

# Find the APK — check junction path first, then standard path
if (Test-Path $JunctionApk) {
    $SourceApk = $JunctionApk
} elseif (Test-Path $StandardApk) {
    $SourceApk = $StandardApk
} else {
    Write-Host "`n[ERROR] APK not found. Check build output above." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Copying APK to Desktop ===" -ForegroundColor Cyan
Copy-Item -Path $SourceApk -Destination $OutputPath -Force
Write-Host "Done! APK is at: $OutputPath" -ForegroundColor Green
Write-Host "File size: $([math]::Round((Get-Item $OutputPath).Length / 1MB, 1)) MB" -ForegroundColor Green
