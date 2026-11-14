<#
=============================================================================
 Recuperación: respaldo de la base de datos datawarehouse
=============================================================================
 Genera un respaldo en formato personalizado de pg_dump (comprimido) y elimina
 los respaldos con más días que $RetentionDays.

 Credenciales: use %APPDATA%\postgresql\pgpass.conf (ver run_etl.ps1).

 Ejemplo:
   .\00_setup\backup_datawarehouse.ps1 -BackupDir "C:/backups/dwh" -Port 5000

 Restaurar un respaldo:
   createdb -U postgres -p 5000 datawarehouse
   pg_restore -U postgres -p 5000 -d datawarehouse --clean --if-exists "C:/backups/dwh/datawarehouse_<fecha>.dump"
=============================================================================
#>
param(
    [string]$BackupDir     = "C:/backups/dwh",
    [string]$PgHost        = "localhost",
    [int]   $Port          = 5432,
    [string]$User          = "postgres",
    [string]$Database      = "datawarehouse",
    [int]   $RetentionDays = 7,
    [string]$PgDumpPath    = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$file = Join-Path $BackupDir ("{0}_{1}.dump" -f $Database, (Get-Date -Format "yyyyMMdd_HHmmss"))

& $PgDumpPath -h $PgHost -p $Port -U $User -w -F c -d $Database -f $file
if ($LASTEXITCODE -ne 0) {
    Write-Error "El respaldo falló (código $LASTEXITCODE)"
    exit $LASTEXITCODE
}
Write-Output "Respaldo creado: $file"

# Retención: eliminar respaldos antiguos
Get-ChildItem -Path $BackupDir -Filter "${Database}_*.dump" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    Remove-Item -Force
