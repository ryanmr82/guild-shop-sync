# Find and run Inno Setup compiler
$isccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$iscc = $null
foreach ($path in $isccPaths) {
    if (Test-Path $path) {
        $iscc = $path
        break
    }
}

if (-not $iscc) {
    # Search for it
    $found = Get-ChildItem -Path "C:\Program Files*", "$env:LOCALAPPDATA\Programs" -Filter "ISCC.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $iscc = $found.FullName
    }
}

if ($iscc) {
    Write-Host "Found ISCC at: $iscc"
    & $iscc "$PSScriptRoot\GuildShopSync.iss"
} else {
    Write-Host "ERROR: Could not find Inno Setup compiler (ISCC.exe)"
    Write-Host "Please install Inno Setup from: https://jrsoftware.org/isdl.php"
}
