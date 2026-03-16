# Compilador ps2exe - SIMPLE Y LIMPIO

param(
    [string]$InputFile = "extractor_final.ps1",
    [string]$OutputName = "NetworkDriveExtractor",
    [string]$OutputDir = "dist"
)

if (-not (Test-Path $InputFile)) {
    Write-Host "ERROR: No se encontro $InputFile" -ForegroundColor Red
    exit 1
}

# Verificar ps2exe
$ps2exeExists = $false
try {
    $module = Get-Module -Name ps2exe -ListAvailable -ErrorAction SilentlyContinue
    if ($module) { $ps2exeExists = $true }
}
catch { }

if (-not $ps2exeExists) {
    Write-Host "Instalando ps2exe..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Force -ErrorAction Stop -WarningAction SilentlyContinue
        Import-Module ps2exe -Force
    }
    catch {
        Write-Host "ERROR: No se pudo instalar ps2exe" -ForegroundColor Red
        exit 1
    }
}

# Crear directorio
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "Compilando..." -ForegroundColor White

$outputPath = Join-Path $OutputDir "$OutputName.exe"

try {
    ps2exe -inputFile $InputFile `
           -outputFile $outputPath `
           -noConsole `
           -company "Generated" `
           -copyright "2024" `
           -version "1.0.0.0"
}
catch {
    Write-Host "ERROR: Fallo la compilacion" -ForegroundColor Red
    exit 1
}

if (Test-Path $outputPath) {
    $fileSize = (Get-Item $outputPath).Length / 1MB
    Write-Host "EXITO - Archivo: $outputPath ($([Math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
}
else {
    Write-Host "ERROR: No se creo el ejecutable" -ForegroundColor Red
    exit 1
}