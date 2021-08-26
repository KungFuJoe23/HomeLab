$members = get-adgroupmember -identity testgroup | select -ExpandProperty Name

foreach ($server in (get-content -path c:\scripts\input\servers.txt)) {
    If ($members -contains $server) {
        $server | out-file -append -filepath c:\scripts\output\groups.txt
    }
} 