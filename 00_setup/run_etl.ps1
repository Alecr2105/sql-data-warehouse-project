<#
=============================================================================
 Automatización: ejecución programada del ETL
=============================================================================
 Ejecuta 03_scripts/run_etl.sql y guarda la salida en logs/etl_<fecha>.log.
 Pensado para el Programador de tareas de Windows (equivalente a SQL Server Agent).

 Credenciales:
   No escriba contraseñas en este archivo. Use el archivo de contraseñas
   de PostgreSQL: %APPDATA%\postgresql\pgpass.conf con la línea
       localhost:<puerto>:datawarehouse:<usuario>:<contraseña>

 Ejemplo de ejecución manual:
   .\00_setup\run_etl.ps1 -DatasetPath "C:/datasets" -Port 5000

 Programar todos los días a las 02:00:
   schtasks /Create /TN "DWH_ETL_Diario" /SC DAILY /ST 02:00 /TR ^
     "powershell -ExecutionPolicy Bypass -File C:\ruta\sql-data-warehouse-project\00_setup\run_etl.ps1 -DatasetPath C:/datasets -Port 5000"
=============================================================================
#>
param(
    [string]$DatasetPath = "C:/datasets",
    [string]$PgHost      = "localhost",
    [int]   $Port        = 5432,
    [string]$User        = "postgres",
    [string]$Database    = "datawarehouse",
    [string]$PsqlPath    = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir      = Join-Path $projectRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile     = Join-Path $logDir ("etl_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

Set-Location $projectRoot
"[$(Get-Date -Format s)] Inicio del ETL" | Out-File -FilePath $logFile -Encoding utf8

# cmd /c redirige stdout y stderr (avisos de psql) al log sin que PowerShell
# los trate como errores
$psqlCommand = "`"$PsqlPath`" -h $PgHost -p $Port -U $User -d $Database -w " +
               "-v dataset_path=`"$DatasetPath`" -f 03_scripts/run_etl.sql >> `"$logFile`" 2>&1"
cmd /c $psqlCommand
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    "[$(Get-Date -Format s)] ETL finalizado correctamente" | Out-File -FilePath $logFile -Append -Encoding utf8
} else {
    "[$(Get-Date -Format s)] ETL FALLÓ (código $exitCode). Revise audit.load_log" | Out-File -FilePath $logFile -Append -Encoding utf8
}
exit $exitCode
