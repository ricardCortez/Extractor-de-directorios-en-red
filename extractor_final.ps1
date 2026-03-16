# Network Drive Extractor - PowerShell Puro
# Compilable a .exe con ps2exe - SIMPLE Y LIMPIO

param(
    [string]$TargetIP = "192.168.1.199",
    [ValidateSet('csv', 'json', 'txt', 'all')]
    [string]$Format = 'all'
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Determinar carpeta de salida
if ($PSScriptRoot -and $PSScriptRoot.Length -gt 0) {
    $OutputDir = $PSScriptRoot
} else {
    $OutputDir = Get-Location | Select-Object -ExpandProperty Path
    if (-not $OutputDir -or $OutputDir.Length -eq 0) {
        $OutputDir = [Environment]::GetFolderPath('Desktop')
    }
}

$reportsDir = Join-Path -Path $OutputDir -ChildPath "reports_$timestamp"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}
$OutputDir = $reportsDir

# ====================================================================
# FUNCIONES
# ====================================================================

function Get-NetworkDrivesNative {
    param([string]$TargetIP)

    $drives = @()

    # Metodo principal: CIM/WMI - confiable y sin parseo de texto
    try {
        $mappedDrives = Get-CimInstance Win32_MappedLogicalDisk -ErrorAction Stop

        foreach ($d in $mappedDrives) {
            $letter = $d.DeviceID   # e.g. "Z:"
            $remote = $d.ProviderName  # e.g. "\\192.168.1.199\share"
            $matchesTarget = $remote -like "*$TargetIP*"

            $drives += @{
                DriveLetter  = $letter
                RemotePath   = $remote
                Status       = "OK"
                MatchesTarget = $matchesTarget
                TargetIP     = $TargetIP
            }
        }

        return $drives
    }
    catch { }

    # Fallback: parsear net use (columnas: Status  Local  Remote  Network)
    try {
        $output = & net use 2>$null

        foreach ($line in $output) {
            $line = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            # Formato: OK  Z:  \\server\share  Microsoft Windows Network
            if ($line -match '^(\S+)\s+([A-Z]:)\s+(\\\\[^\s]+)') {
                $status     = $matches[1]
                $letter     = $matches[2]
                $remote     = $matches[3]
                $matchesTarget = $remote -like "*$TargetIP*"

                $drives += @{
                    DriveLetter  = $letter
                    RemotePath   = $remote
                    Status       = $status
                    MatchesTarget = $matchesTarget
                    TargetIP     = $TargetIP
                }
            }
        }
    }
    catch { }

    return $drives
}

function Export-ToCSV {
    param([array]$Drives, [string]$FilePath)
    
    try {
        $csvContent = "Unidad,Ruta Remota,Estado,Coincide IP`r`n"
        
        foreach ($drive in $Drives) {
            $match = if ($drive.MatchesTarget) { "Si" } else { "No" }
            $remotePath = $drive.RemotePath -replace ',', ';'
            $csvContent += "$($drive.DriveLetter),$remotePath,$($drive.Status),$match`r`n"
        }
        
        [System.IO.File]::WriteAllText($FilePath, $csvContent, [System.Text.Encoding]::UTF8)
        return $true
    }
    catch { return $false }
}

function Export-ToJSON {
    param([array]$Drives, [string]$FilePath)
    
    try {
        $data = @{
            timestamp = Get-Date -Format "o"
            target_ip = if ($Drives.Count -gt 0) { $Drives[0].TargetIP } else { "N/A" }
            total_drives = $Drives.Count
            drives = @()
        }
        
        foreach ($drive in $Drives) {
            $data.drives += @{
                drive_letter = $drive.DriveLetter
                remote_path = $drive.RemotePath
                status = $drive.Status
                matches_target = $drive.MatchesTarget
            }
        }
        
        $json = $data | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($FilePath, $json, [System.Text.Encoding]::UTF8)
        return $true
    }
    catch { return $false }
}

function Export-ToTXT {
    param([array]$Drives, [string]$FilePath)
    
    try {
        $txt = "REPORTE DE RUTAS DE RED MAPEADAS`r`n"
        $txt += ("=" * 60) + "`r`n"
        $txt += "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
        $txt += "IP Destino: $(if($Drives.Count -gt 0){$Drives[0].TargetIP}else{'N/A'})`r`n"
        $txt += "Total de unidades: $($Drives.Count)`r`n"
        $txt += ("=" * 60) + "`r`n`r`n"
        
        if ($Drives.Count -gt 0) {
            foreach ($drive in $Drives) {
                $indicator = if ($drive.MatchesTarget) { " [COINCIDE]" } else { "" }
                $txt += "Unidad: $($drive.DriveLetter)`r`n"
                $txt += "Ruta: $($drive.RemotePath)$indicator`r`n"
                $txt += "Estado: $($drive.Status)`r`n"
                $txt += ("-" * 60) + "`r`n`r`n"
            }
        }
        else {
            $txt += "No se encontraron rutas de red mapeadas.`r`n"
        }
        
        [System.IO.File]::WriteAllText($FilePath, $txt, [System.Text.Encoding]::UTF8)
        return $true
    }
    catch { return $false }
}

# ====================================================================
# MAIN
# ====================================================================

Write-Host ""
Write-Host "Network Drive Extractor" -ForegroundColor Cyan
Write-Host ""

$drives = Get-NetworkDrivesNative -TargetIP $TargetIP

Write-Host "Total de unidades: $($drives.Count)" -ForegroundColor White

if ($drives.Count -gt 0) {
    Write-Host ""
    foreach ($drive in $drives) {
        Write-Host "$($drive.DriveLetter) -> $($drive.RemotePath)"
    }
}

Write-Host ""

# Exportar
$exported = @()

if ($Format -eq 'csv' -or $Format -eq 'all') {
    $csvPath = Join-Path $OutputDir "network_drives_$timestamp.csv"
    if (Export-ToCSV -Drives $drives -FilePath $csvPath) {
        $exported += "CSV"
    }
}

if ($Format -eq 'json' -or $Format -eq 'all') {
    $jsonPath = Join-Path $OutputDir "network_drives_$timestamp.json"
    if (Export-ToJSON -Drives $drives -FilePath $jsonPath) {
        $exported += "JSON"
    }
}

if ($Format -eq 'txt' -or $Format -eq 'all') {
    $txtPath = Join-Path $OutputDir "network_drives_$timestamp.txt"
    if (Export-ToTXT -Drives $drives -FilePath $txtPath) {
        $exported += "TXT"
    }
}

Write-Host "Archivos generados: $($exported -join ', ')" -ForegroundColor Green
Write-Host "Ubicacion: $OutputDir" -ForegroundColor Yellow
Write-Host ""