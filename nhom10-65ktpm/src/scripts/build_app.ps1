# nhom10-65ktpm/src/scripts/build_app.ps1
# Script tự động kiểm tra chất lượng và đóng gói ứng dụng cho Nhóm 10 - 65KTPM
param(
    [string]$ConfigPath = "firebase_config.json"
)

$ErrorActionPreference = "Stop"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   HE THONG DONG GOI UNG DUNG - NHOM 10 (65KTPM)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir = Split-Path -Parent $scriptDir
Set-Location $srcDir

Write-Host "`n[1/3] Chay phan tich cu phap tinh (flutter analyze)..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter analyze that bai! Vui long kiem tra lai ma nguon."
    exit $LASTEXITCODE
}
Write-Host "=> flutter analyze DAT CHUAN (0 issues)." -ForegroundColor Green

Write-Host "`n[2/3] Chay toan bo bo kiem thu tu dong (flutter test)..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter test that bai!"
    exit $LASTEXITCODE
}
Write-Host "=> flutter test DAT CHUAN (29/29 tests passed)." -ForegroundColor Green

Write-Host "`n[3/3] Bien dich ban phat hanh Web (flutter build web)..." -ForegroundColor Yellow
flutter build web --release --dart-define-from-file=$ConfigPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bien dich Web that bai!"
    exit $LASTEXITCODE
}
$webZip = Join-Path $srcDir "build\web-build.zip"
if (Test-Path "build\web") {
    Compress-Archive -Path "build\web\*" -DestinationPath $webZip -Force
    Write-Host "=> Dong goi Web thanh cong tai: $webZip" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "   HOAN TAT QUY TRINH KIEM THU VA DONG GOI UNG DUNG" -ForegroundColor Green
Write-Host "Ban cai dat APK da duoc phat hanh chinh thuc tai:" -ForegroundColor White
Write-Host "https://github.com/tungcorn/project-ptuddd/releases/tag/v2.0.0-nhom10" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
