<#
.SYNOPSIS
    Run command(s) remotely on multiple servers with standard output and error capture.
 
    This script leverages Invoke-Command with PSJobs. This allows easy running of simple commands on remote servers.
 
    Files required:
        This script
        servers.txt in same folder with list of servers to run against
 
    Files created:
        RemoteEventLogResults folder in working dir with individual log files (one per server).
        RemoteEventLogResults.xls with summary of success/failure of remote commands.
 
.NOTES
    v1.0 - Initial script - Edward Ingram
    v1.1 - Added output results into individual files
 
 
#>
 
 
Function Check-Jobs {
    $now = Get-Date
    Get-Job | Where {$_.State -eq 'Running' -and (($now - $_.PSBeginTime) -gt $timeout)} | Stop-Job
    Start-Sleep -s 3
}
 
# Edit these values as needed. MaxJobs indicates how many jobs to run in parallel. Timeout will Stop-Job on any jobs that run longer than indicated value.
 
$MaxJobs = 8
$Timeout = [timespan]::FromSeconds(200)
 
$servers = Get-Content -Path servers.txt | Where-Object {$_ -ne ""}
# Clean up existing files if present
$files = 'RemoteEventLogResults.xlsx' | Remove-Item -ErrorAction SilentlyContinue
 
# Create folder structure
New-Item -Path . -Name "RemoteEventLogResults\NoResults" -ItemType "directory" -ErrorAction SilentlyContinue
 
 
[System.Collections.ArrayList]$colObject = @()
$no = $null
 
# Clean up any existing jobs
 
Get-Job | Stop-Job
Get-Job | Remove-Job
 
$count = 0
 
Write-Host -ForegroundColor Green "Maximum concurrent jobs set to" $MaxJobs `n
Write-Host -ForegroundColor Green "Timeout set to" $Timeout.TotalSeconds "seconds" `n
Write-Host -ForegroundColor Green "Running on" $servers.Count "server(s)" `n
 
Write-Host "Running on" $servers.Count "servers"
Foreach ($server in $servers) {
    $serverfqdn = $server + '.homelab.local'
    $count ++
    $Running = @(Get-Job | Where-Object { $_.State -eq 'Running'})
    While ($Running.Count -ge $MaxJobs) {
#       Write-Host "Max jobs running, waiting for jobs to finish before proceeding"
        Check-Jobs
        $Running = @(Get-Job | Where-Object { $_.State -eq 'Running'})
        Start-Sleep -s 5
    }
    Write-Host "Running RemoteEventLog on" $server "-" $count "of" $servers.count
    If (Test-Connection $server -ErrorAction SilentlyContinue) {
        Invoke-Command -ComputerName $serverfqdn -ScriptBlock {
    
 #           Get-WinEvent -FilterHashtable @{logname='microsoft-windows-failoverclustering/operational';ID=1649} | where-object  { $_.Message -like '*STORAGE_GET_DISK*' } | Format-List
            # Bug in Powershell prevents passing arrays with multiple values using ICM so need to specify array values within scriptblock:
            $eventids=1230,1069
 
            Get-WinEvent -FilterHashtable @{logname='System';ID=$eventids;ProviderName='Microsoft-Windows-FailoverClustering';StartTime = [datetime]::Today.AddDays(-14);EndTime = [datetime]::Today} | Format-List
               
                } -AsJob -JobName $server | Out-Null    
            
    } Else {
        Write-Host -ForegroundColor Red "Unable to connect to $Server"
        $ConnectIssues += $server
    }
}
 
$Running = @(Get-Job | Where-Object { $_.State -eq 'Running'})
While ($Running.Count -ge 1) {
#    Write-Host "last batch running"
    Check-Jobs
    $Running = @(Get-Job | Where-Object { $_.State -eq 'Running'})
    Start-Sleep -s 5
}
 
Foreach ($job in Get-Job) {
    $Result = ""
    $ErrorStatus = ""
    $CommResult = ""
    If ($job.State -eq 'Stopped') {
        Write-Host "Job on" $job.Name "timed out."
        $status = "Timeout"
    } Else {     
        $Result = Receive-Job $job -ErrorVariable ErrorStatus
        If ($ErrorStatus -or !($Result)) {
            $serverName = $job.Name
            $FileName = "$($serverName)_$(get-date -f MM-dd-hh-mm-ss).txt"
            $ErrorStatus | Out-File -FilePath .\RemoteEventLogResults\NoResults\$FileName
            $status = "No Events Found"
        } Else {
# Enter what text to look for and what CommResult to show
 
#           If ($Result -match "2.1") { 
#               $CommResult = "2.1"
#           } 
 
# OR use Select-String to capture entire line from output
 
#            $CommResult = $Result | Select-String -Pattern "iLOrest"
#            $CommResult = $CommResult -replace '.*version (\d+)','$1'
 
            $serverName = $job.Name
            $FileName = "$($serverName)_$(get-date -f MM-dd-hh-mm-ss).txt"
            $Result | Out-File -FilePath .\RemoteEventLogResults\$FileName
            $status = "Events Found"
        }                     
    }
    $obj = [pscustomobject][ordered]@{
        ServerName = $job.Name
        Status = $status
        Version = $CommResult
    }
    $colObject.Add($obj) | Out-Null
}
 
Get-Job | Remove-Job
 
Write-Host -ForegroundColor Yellow `n"The following servers had connection issues:"
If ($ConnectIssues) {
    Foreach ($ConnectIssue in $ConnectIssues) {
        Write-Host "$ConnectIssue `n"
    }
} Else {
    Write-Host "None"
}
 
$colObject | Export-Excel -Path $pwd\RemoteEventLogResults_$(get-date -f MM-dd-hh-mm-ss).xlsx -Show -AutoSize -AutoFilter
 