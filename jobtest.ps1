function Check-Jobs {
    $now = get-date
    Get-Job | Where {$_.state -eq 'Running' -and (($now - $_.PSBeginTime) -gt $timeout)} | stop-job         
    start-sleep -s 3
}

# $jobtimer = @{}
$timeout = [timespan]::FromSeconds(3)
$servers = gc servers.txt

foreach ($server in $servers) {
    $running = @(get-job | where-object { $_.state -eq 'Running' })
    While ($running.Count -ge 2) {   
        Write-Host "Max jobs running - waiting for completion or timeout"
        Check-Jobs
        $running = @(get-job | where-object { $_.state -eq 'Running' })
    }  

    write-host "Starting job on" $server
    icm $server { get-childitem c: } -asjob -jobname $server | out-null
    write-host "Jobs running:" ($running.count + 1)
    $jobtimer[$server] = [System.Diagnostics.StopWatch]::startnew()
}

$running = @(get-job | where-object { $_.state -eq 'Running' })
While ($running.Count -ge 1) {   
        Write-Host "Last batch running"
        Check-Jobs
        $running = @(get-job | where-object { $_.state -eq 'Running' })
    }  

foreach ($job in get-job) {
    
    $result = receive-job $job
    If ($job.state -eq 'Stopped') {
        write-host "Job on" $job.name "stopped"
    }
    write-host $job.name
#    write-host "Time elapsed:" $jobtimer[$server].elapsed.totalseconds
}

remove-job -state completed
