[System.Collections.ArrayList]$colObject = @()

$computers = Get-ADComputer -Filter * | Select -ExpandProperty Name | Select-String -Pattern '-V|-AG|-DB|-FS1|-FCI1' -notMatch

Foreach ($computer in $computers) {
    If ( Test-Connection -Count 2 $computer -ErrorAction SilentlyContinue ) {
        $disks = Invoke-Command $computer { Get-Disk | Where-Object { !($_.BusType -eq "iSCSI")}}
        Foreach ( $disk in $disks ) {
            $obj = [PSCustomObject]@{
                Computer = $computer
                GuID = $disk.GuID
                UniqueID = $disk.UniqueID
            }
            $colObject.Add($obj) | Out-Null
        }
    }
}

$colObject | Export-Excel $pwd\CheckDiskIDResults_$(Get-Date -f MM-dd-hh-mm-ss).xlsx -Show -Autosize -Autofilter