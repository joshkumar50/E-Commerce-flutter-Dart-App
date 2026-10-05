param (
    [Parameter(Mandatory=$true)]
    [string]$ApkPath
)

Write-Host "Verifying $ApkPath for leaked secrets..."
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null
Expand-Archive -Path $ApkPath -DestinationPath $TmpDir -Force

$AssetsDir = Join-Path $TmpDir "assets\flutter_assets"
if (Test-Path $AssetsDir) {
    $Matches = Select-String -Path "$AssetsDir\*.*" -Pattern "eyJhbGciOiJIUzI1Ni|-----BEGIN|service_role" -Recurse -ErrorAction SilentlyContinue
    if ($Matches) {
        Write-Host "FAIL: Leaked secret detected in flutter_assets!" -ForegroundColor Red
        Remove-Item -Path $TmpDir -Recurse -Force
        exit 1
    }
}

Write-Host "PASS: No secrets detected in release artifacts." -ForegroundColor Green
Remove-Item -Path $TmpDir -Recurse -Force
exit 0
