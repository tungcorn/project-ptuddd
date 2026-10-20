# nhom10-65ktpm/scripts/publish_release.ps1
# ==============================================================================
# PIPELINE TU DONG HOA PHAT HANH RELEASE (LOCAL CD RUNNER) - NHOM 10 (65KTPM)
# ==============================================================================
# Pipeline nay thuc hien quy trinh CD tu dong hoa 100%:
# 1. Kiem tra moi truong va cong cu (Flutter, Git, GitHub CLI).
# 2. Doc phien ban tu pubspec.yaml va khoi tao Git Tag.
# 3. Chay Quality Gates: flutter analyze (0 issue) & flutter test (29/29 pass).
# 4. Dong goi ban Web Release & nen tap tin web-build.zip.
# 5. Kiem tra hoac thu thap ban Android APK release san co.
# 6. Tinh toan ma bam toan ven SHA-256.
# 7. Tu dong tao hoac cap nhat GitHub Release qua gh CLI tren repository.
# ==============================================================================

param(
    [string]$Tag = "",
    [string]$Repo = "tungcorn/project-ptuddd",
    [string]$TargetBranch = "nhom/nhom10-65ktpm",
    [string]$ConfigPath = "firebase_config.json",
    [string]$ApkPath = "",
    [switch]$SkipTests = $false,
    [switch]$SkipBuildWeb = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   LOCAL CD PIPELINE: AUTOMATED RELEASE - NHOM 10 (65KTPM)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$srcDir = Join-Path $projectRoot "src"

if (-not (Test-Path $srcDir)) {
    Write-Error "Khong tim thay thu muc ma nguon: $srcDir"
    exit 1
}

Set-Location $srcDir

# ------------------------------------------------------------------------------
# 1. KIEM TRA DIEU KIEN MOI TRUONG
# ------------------------------------------------------------------------------
Write-Host "`n[1/6] Kiem tra moi truong thuc thi..." -ForegroundColor Yellow

# Kiem tra gh cli
try {
    $ghUser = (gh api user --jq .login 2>$null)
    if (-not $ghUser) {
        Write-Error "GitHub CLI (gh) chua duoc dang nhap. Vui long chay 'gh auth login' truoc."
        exit 1
    }
    Write-Host "  -> GitHub CLI: Da xac thuc voi tai khoan @$ghUser" -ForegroundColor Green
} catch {
    Write-Error "Khong the goi lenh 'gh'. Vui long cai dat GitHub CLI."
    exit 1
}

# Kiem tra branch hien tai
$currentBranch = (git -C $projectRoot branch --show-current 2>$null)
Write-Host "  -> Nhanh Git hien tai: $currentBranch" -ForegroundColor Gray

# ------------------------------------------------------------------------------
# 2. XAC DINH PHIEN BAN & TAG
# ------------------------------------------------------------------------------
Write-Host "`n[2/6] Doc phien ban tu pubspec.yaml..." -ForegroundColor Yellow
$pubspecPath = Join-Path $srcDir "pubspec.yaml"
$versionRaw = (Get-Content $pubspecPath | Select-String -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value.Trim()
$versionClean = ($versionRaw -split "\+")[0]

if (-not $Tag) {
    $Tag = "v$versionClean-nhom10"
}

Write-Host "  -> Phien ban ung dung: $versionRaw" -ForegroundColor Green
Write-Host "  -> Tag phat hanh: $Tag" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 3. CHAY QUALITY GATES (TESTING & ANALYSIS)
# ------------------------------------------------------------------------------
if ($SkipTests) {
    Write-Host "`n[3/6] Bo qua Quality Gates (--SkipTests duoc bat)." -ForegroundColor Magenta
} else {
    Write-Host "`n[3/6] Kiem tra chat luong (Quality Gates)..." -ForegroundColor Yellow
    
    Write-Host "  -> [CI 1/2] Chay phan tich cu phap tinh (flutter analyze)..." -ForegroundColor Gray
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Quality Gate that bai: flutter analyze co loi hoac canh bao!"
        exit $LASTEXITCODE
    }
    Write-Host "     => DAT CHUAN: 0 issues." -ForegroundColor Green

    Write-Host "  -> [CI 2/2] Chay kiem thu tu dong (flutter test)..." -ForegroundColor Gray
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Quality Gate that bai: Toan bo cac bai test phai PASS!"
        exit $LASTEXITCODE
    }
    Write-Host "     => DAT CHUAN: 100% test cases PASSED." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 4. BIEN DICH & DONG GOI SAN PHAM (BUILDING & PACKAGING)
# ------------------------------------------------------------------------------
Write-Host "`n[4/6] Dong goi san pham phat hanh..." -ForegroundColor Yellow
$buildDir = Join-Path $srcDir "build"
$webZipPath = Join-Path $buildDir "studydoc-manager-$versionClean-web.zip"

if (-not $SkipBuildWeb) {
    Write-Host "  -> [CD 1/2] Bien dich Web Release (flutter build web)..." -ForegroundColor Gray
    flutter build web --release --dart-define-from-file=$ConfigPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Bien dich Web that bai!"
        exit $LASTEXITCODE
    }
    
    Write-Host "  -> [CD 2/2] Nen tap tin Web Application..." -ForegroundColor Gray
    if (Test-Path "$buildDir\web") {
        if (Test-Path $webZipPath) { Remove-Item $webZipPath -Force }
        Compress-Archive -Path "$buildDir\web\*" -DestinationPath $webZipPath -Force
        Write-Host "     => Tao goi Web zip thanh cong: $webZipPath" -ForegroundColor Green
    }
}

# Tim tap tin APK hop le
$candidateApk = ""
if ($ApkPath -and (Test-Path $ApkPath)) {
    $candidateApk = $ApkPath
} elseif (Test-Path "$buildDir\app\outputs\flutter-apk\app-release.apk") {
    $candidateApk = "$buildDir\app\outputs\flutter-apk\app-release.apk"
} else {
    # Thu tim trong thu muc goc hoc tap hoac cache
    $externalApk = "D:\Hoc\Android\TH\th1_qly_hoc_tap\build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $externalApk) {
        $candidateApk = $externalApk
    }
}

$finalApkPath = ""
if ($candidateApk -and (Test-Path $candidateApk)) {
    $finalApkPath = Join-Path $buildDir "studydoc-manager-$versionClean-android.apk"
    Copy-Item $candidateApk $finalApkPath -Force
    Write-Host "  -> [APK] Su dung ban APK phat hanh tai: $finalApkPath" -ForegroundColor Green
} else {
    Write-Host "  -> [CANH BAO] Khong tim thay ban APK. Chi phat hanh goi Web." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 5. TINH TOAN MA BAM SHA-256 CHECKSUḾ
# ------------------------------------------------------------------------------
Write-Host "`n[5/6] Tinh toan ma bam toan ven SHA-256..." -ForegroundColor Yellow
$assetsToUpload = @()

if (Test-Path $webZipPath) {
    $webHash = (Get-FileHash -Path $webZipPath -Algorithm SHA256).Hash
    $webSize = [math]::Round((Get-Item $webZipPath).Length / 1MB, 2)
    Write-Host "  -> Web Zip ($webSize MB): $webHash" -ForegroundColor Gray
    $assetsToUpload += $webZipPath
}

$apkHash = "N/A"
$apkSize = "N/A"
if ($finalApkPath -and (Test-Path $finalApkPath)) {
    $apkHash = (Get-FileHash -Path $finalApkPath -Algorithm SHA256).Hash
    $apkSize = [math]::Round((Get-Item $finalApkPath).Length / 1MB, 2)
    Write-Host "  -> Android APK ($apkSize MB): $apkHash" -ForegroundColor Gray
    $assetsToUpload += $finalApkPath
}

if ($assetsToUpload.Count -eq 0) {
    Write-Error "Khong co tap tin nao de dong goi phat hanh!"
    exit 1
}

# ------------------------------------------------------------------------------
# 6. PHAT HANH RELEASE TREN GITHUB (gh release)
# ------------------------------------------------------------------------------
Write-Host "`n[6/6] Phat hanh Release len GitHub ($Repo)..." -ForegroundColor Yellow

$releaseTitle = "Nhom 10 - 65KTPM: Ban phat hanh ung dung Quan ly tai lieu ($Tag)"
$nowStr = (Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
$notesList = [System.Collections.Generic.List[string]]::new()
$notesList.Add("### Ban phat hanh chinh thuc - Do an Phat trien Ung dung Di dong")
$notesList.Add("- **Nhom thuc hien**: Nhom 10 - Lop 65KTPM")
$notesList.Add("- **Thanh vien**: Ngo Quang Tung (Nhom truong), Nguyen Hai Ninh, Dao Ngoc Dinh, Pham Ngoc Bach")
$notesList.Add("- **Giang vien huong dan**: Thay Do Oanh Cuong")
$notesList.Add("- **Thoi gian khoi tao**: $nowStr")
$notesList.Add("")
$notesList.Add("#### Danh sach tap tin dinh kem:")
$notesList.Add("1. `studydoc-manager-$versionClean-android.apk` (Dung luong: ~$apkSize MB)")
$notesList.Add("2. `studydoc-manager-$versionClean-web.zip` (Dung luong: ~$webSize MB)")
$notesList.Add("")
$notesList.Add("#### Bang ma bam toan ven (SHA-256 Checksums):")
$notesList.Add("- **Android APK**: $apkHash")
$notesList.Add("- **Web Build Zip**: $webHash")
$releaseNotes = [string]::Join("`n", $notesList)

# Kiem tra xem Release da ton tai chua
$existingRelease = (gh release view $Tag --repo $Repo 2>$null)
if ($existingRelease) {
    Write-Host "  -> Tag '$Tag' da ton tai tren GitHub. Dang tai de tai nguyen (clobber)..." -ForegroundColor Yellow
    foreach ($file in $assetsToUpload) {
        gh release upload $Tag $file --repo $Repo --clobber
    }
} else {
    Write-Host "  -> Dang khoi tao Release moi '$Tag' tren GitHub..." -ForegroundColor Cyan
    $assetArgs = $assetsToUpload | ForEach-Object { "`"$_`"" }
    $cmd = "gh release create $Tag $assetArgs --repo $Repo --target $TargetBranch --title `"$releaseTitle`" --notes `"$releaseNotes`""
    Invoke-Expression $cmd
}

$releaseUrl = "https://github.com/$Repo/releases/tag/$Tag"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   DA HOAN TAT TU DONG HOA CD: PHAT HANH RELEASE THANH CONG!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Dia chi Release: $releaseUrl" -ForegroundColor Cyan
Write-Host "Cac tap tin dinh kem:" -ForegroundColor White
$assetsToUpload | ForEach-Object { Write-Host "  + $_" -ForegroundColor Gray }
Write-Host "==========================================================" -ForegroundColor Green
