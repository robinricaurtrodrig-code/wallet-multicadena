# Script de stress test para la API Wallet Multicadena
# Usa locust en modo headless (sin interfaz web)
#
# Requisitos:
#   1. El backend debe estar corriendo (uvicorn app.main:app --port 8000)
#   2. Ejecutar este script en otra terminal

param(
    [int]$Users = 50,
    [int]$SpawnRate = 5,
    [int]$DurationSec = 60
)

Write-Host "=== Stress Test: Wallet Multicadena API ===" -ForegroundColor Cyan
Write-Host "Objetivo: http://localhost:8000" -ForegroundColor Yellow
Write-Host "Usuarios: $Users" -ForegroundColor Yellow
Write-Host "Tasa de spawn: $SpawnRate usuarios/segundo" -ForegroundColor Yellow
Write-Host "Duracion: ${DurationSec}s" -ForegroundColor Yellow
Write-Host ""

$LOCUST = "C:\Users\User\AppData\Local\Python\pythoncore-3.14-64\Scripts\locust.exe"

if (-not (Test-Path $LOCUST)) {
    Write-Host "ERROR: Locust no encontrado en $LOCUST" -ForegroundColor Red
    exit 1
}

# Stress test con tags separados (OR: health O prices)
& $LOCUST -f "$PSScriptRoot\locustfile.py" `
    --host=http://localhost:8000 `
    --headless `
    --users $Users `
    --spawn-rate $SpawnRate `
    --run-time ${DurationSec}s `
    --tags health `
    --tags prices `
    --html "$PSScriptRoot\report_stress_test.html" `
    --print-stats

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Stress test completado ===" -ForegroundColor Green
    Write-Host "Reporte: report_stress_test.html" -ForegroundColor Green
} else {
    Write-Host "`n=== Stress test fallo con codigo: $LASTEXITCODE ===" -ForegroundColor Red
}
