# ==========================================
# Windows Server Health Monitoring
# Export Results to CSV
# ==========================================

$Servers = @(
    "SERVER01",
    "SERVER02",
    "SERVER03"
)

$OutputFile = "C:\Reports\ServerHealthReport.csv"

# Create report directory
$ReportFolder = Split-Path $OutputFile

if (!(Test-Path $ReportFolder)) {
    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
}

$Results = @()

foreach ($Server in $Servers) {

    Write-Host "Checking server: $Server" -ForegroundColor Cyan

    $Result = [PSCustomObject]@{
        ServerName       = $Server
        PingStatus       = "Unknown"
        CPUUsage         = "N/A"
        MemoryUsage      = "N/A"
        TotalMemoryGB    = "N/A"
        FreeMemoryGB     = "N/A"
        DiskDetails      = "N/A"
        Uptime           = "N/A"
        OSVersion        = "N/A"
        HealthStatus     = "Unknown"
        CheckedAt        = Get-Date
    }

    try {

        # Check Connectivity
        $Ping = Test-Connection -ComputerName $Server `
                    -Count 2 -Quiet -ErrorAction Stop

        if (!$Ping) {
            throw "Server is not reachable"
        }

        $Result.PingStatus = "Online"

        # Get Operating System Information
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem `
                -ComputerName $Server -ErrorAction Stop

        # CPU Usage
        $CPU = Get-CimInstance -ClassName Win32_Processor `
                -ComputerName $Server |
                Measure-Object -Property LoadPercentage -Average

        $CPUUsage = [math]::Round($CPU.Average, 2)

        $Result.CPUUsage = $CPUUsage

        # Memory Usage
        $TotalMemory = [math]::Round(
            $OS.TotalVisibleMemorySize / 1MB, 2
        )

        $FreeMemory = [math]::Round(
            $OS.FreePhysicalMemory / 1MB, 2
        )

        $MemoryUsage = [math]::Round(
            (($TotalMemory - $FreeMemory) / $TotalMemory) * 100, 2
        )

        $Result.TotalMemoryGB = $TotalMemory
        $Result.FreeMemoryGB = $FreeMemory
        $Result.MemoryUsage = $MemoryUsage

        # Disk Information
        $Disks = Get-CimInstance -ClassName Win32_LogicalDisk `
                    -ComputerName $Server `
                    -Filter "DriveType=3"

        $DiskInfo = @()

        foreach ($Disk in $Disks) {

            $UsedPercent = [math]::Round(
                (($Disk.Size - $Disk.FreeSpace) / $Disk.Size) * 100, 2
            )

            $FreeGB = [math]::Round(
                $Disk.FreeSpace / 1GB, 2
            )

            $DiskInfo += "$($Disk.DeviceID): $UsedPercent% Used, $FreeGB GB Free"
        }

        $Result.DiskDetails = $DiskInfo -join " | "

        # Uptime
        $LastBoot = $OS.LastBootUpTime
        $Uptime = (Get-Date) - $LastBoot

        $Result.Uptime = "$($Uptime.Days) Days $($Uptime.Hours) Hours"

        # OS Version
        $Result.OSVersion = $OS.Caption

        # Health Evaluation
        $Health = "Healthy"

        if ($CPUUsage -ge 90 -or $MemoryUsage -ge 90) {
            $Health = "Critical"
        }
        elseif ($CPUUsage -ge 75 -or $MemoryUsage -ge 75) {
            $Health = "Warning"
        }

        foreach ($Disk in $Disks) {

            $DiskUsage = (($Disk.Size - $Disk.FreeSpace) / $Disk.Size) * 100

            if ($DiskUsage -ge 95) {
                $Health = "Critical"
            }
            elseif ($DiskUsage -ge 85 -and $Health -ne "Critical") {
                $Health = "Warning"
            }
        }

        $Result.HealthStatus = $Health

    }
    catch {

        $Result.PingStatus = "Failed"
        $Result.HealthStatus = "Unavailable"

        Write-Warning "$Server : $($_.Exception.Message)"
    }

    $Results += $Result
}

# Export to CSV
$Results | Export-Csv -Path $OutputFile `
    -NoTypeInformation -Encoding UTF8

Write-Host "`nServer Health Check Completed!" -ForegroundColor Green

Write-Host "Report Location: $OutputFile" -ForegroundColor Yellow

# Display Results
$Results | Format-Table ServerName, PingStatus, CPUUsage,
    MemoryUsage, HealthStatus -AutoSize