<#

.SYNOPSIS
 Create a health report

.DESCRIPTION
 Create a health report with HostUptime, Raminfo, Diskinfo, LastEventCodes, StoppedServices, TopProcesses

.PARAMETER ThresholdUptimeDays
 Threshold Uptime Days

.PARAMETER ThresholdMemoryPercent
 Threshold Free Memory Percent

.PARAMETER ThresholdTopProcesses
 Threshold Top Processes Allocated Memory

.PARAMETER ThresholdCountProcesses
 Threshold Count Processes

.PARAMETER ThresholdFreeSpacePercent
 Threshol Free DiskSpace Percent

.PARAMETER ThresholdLastEventDays
 Threshold LastEvent Days

.PARAMETER OutputToJson
 Switch, save all failed objects to an JSON file

 .PARAMETER InputFromJson
 Switch, import failed objects from an JSON file

.NOTES
 Author: Martin Walther
 Date created: 12.10.2014
 Microsoft Chart Controls für Microsoft .NET Framework 3.5 kann nur installiert werden, wenn Microsoft .NET Framework 3.5 SP1 installiert ist.
 https://www.w3schools.com/css/css_align.asp
 https://psscripts.wordpress.com/2014/09/01/powershell-and-charts/
 https://powershellshocked.wordpress.com/2015/12/11/generating-reports-with-powershell-part-4-generating-a-visual-server-health-dashboard/
 https://www.microsoft.com/en-us/download/details.aspx?id=14422

.EXAMPLE
 .\Script.ps1

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][Int]$ThresholdUptimeDays      = 30,
    [Parameter(Mandatory=$false)][Int]$ThresholdMemoryPercent   = 30,
    [Parameter(Mandatory=$false)][Int]$ThresholdTopProcesses    = 5,
    [Parameter(Mandatory=$false)][Int]$ThresholdCountProcesses  = 5,
    [Parameter(Mandatory=$false)][Int]$ThresholdFreeSpacePercent = 30,
    [Parameter(Mandatory=$false)][Int]$ThresholdLastEventDays   = 1,
    [Parameter(Mandatory=$false)][Switch]$OutputToJson,
    [Parameter(Mandatory=$false)][Switch]$InputFromJson
)

#region PSCode

function Test-MicrosoftChartControls {
    [CmdletBinding()]
    param()
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = $true
    try{
        if(-not(Test-Path -Path "$($script:Scriptpath)\JSON\$($function).json")){
	        $wmiobj = Get-WmiObject -Class Win32_Product -Filter "Name LIKE '%Microsoft Chart Controls%'"
            if([string]::IsNullOrEmpty($wmiobj)){
                $ret = $false
                Write-Host "Microsoft Chart Controls for Microsoft .NET Framework 3.5 not found" -ForegroundColor Yellow
                Write-Host "You can download the Chart Controls from https://www.microsoft.com/en-us/download/details.aspx?id=14422" -ForegroundColor Yellow
            }
            else{
                'Microsoft Chart Controls for Microsoft .NET Framework 3.5 installed' | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
        $ret = $false
    }
    return $ret
}

function Get-HostUptime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Int]$threshold
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    try{
	    $Uptime = Get-WmiObject -Class Win32_OperatingSystem
        if(-not([String]::IsNullOrEmpty($Uptime))){
	        $LastBootUpTime = $Uptime.ConvertToDateTime($Uptime.LastBootUpTime)
	        $Time = (Get-Date) - $LastBootUpTime
            if($Time.Days -ge $threshold){
                $obj = [PSCustomObject]@{
                    Days    = "{0:00}" -f $Time.Days
                    Hours   = "{0:00}" -f $Time.Hours
                    Minutes = "{0:00}" -f $Time.Minutes
                    Seconds = "{0:00}" -f $Time.Seconds
                }
                $ret += $obj
                if($OutputToJson){
                    $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
                }
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Get-Raminfo{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Int]$threshold
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    try{
	    $wmiobj = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop | Select-Object TotalVisibleMemorySize,FreePhysicalMemory,FreeSpaceInPagingFiles
        if(-not([String]::IsNullOrEmpty($wmiobj))){
            $wmiobj | %{
                $TotalRamGB     = [math]::round(($_.TotalVisibleMemorySize/(1024*1024)),2)
                $FreeRamGB      = [math]::round(($_.FreePhysicalMemory/(1024*1024)),2)
                $FreeRamPercent = [math]::round((($FreeRamGB / $TotalRamGB) * 100),2)
                $UsedRamGB      = [math]::round(($TotalRamGB - $FreeRamGB),2)
                if($FreeRamPercent -lt $threshold){
                    $obj = [PSCustomObject]@{
                        Name           = 'RAM'
                        'Total(GB)' = "{0:0.00}" -f $TotalRamGB
                        'Used(GB)'  = "{0:0.00}" -f $UsedRamGB
                        'Free(GB)'  = "{0:0.00}" -f $FreeRamGB
                        'Free(%)'   = "{0:0}"    -f $FreeRamPercent
                    }
                    $ret += $obj
                    if($OutputToJson){
                        $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
                    }
                }
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Get-Diskinfo{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Int]$threshold
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    try{
	    $wmiobj = Get-WMIObject Win32_LogicalDisk -ErrorAction Stop| Where-Object{$_.DriveType -eq 3} | Where-Object{ ($_.freespace/$_.Size)*100 -lt $threshold}
        if(-not([String]::IsNullOrEmpty($wmiobj))){
            $wmiobj | %{
                $obj = [PSCustomObject]@{
                    Name        = $_.Name
                    VolumeName  = $_.VolumeName
                    FileSystem  = $_.FileSystem
                    Description = $_.Description
                    'Total(GB)' = "{0:0.00}" -f [math]::round(($_.size/1gb),2)
                    'Free(GB)'  = "{0:0.00}" -f [math]::round(($_.freespace/1gb),2)
                    'Free(%)'   = "{0:0}"    -f [math]::round(($_.freespace/$_.size*100),2)
                }
                $ret += $obj
            }
            if($OutputToJson){
                $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Get-LastEventCodes{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$Logname,
        [Parameter(Mandatory=$true)][Int]   $day
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    [DateTime]$now    = Get-Date
    [DateTime]$after  = $now.AddDays(-$day)
    [DateTime]$before = $now
    try{
        $wmiobj = Get-EventLog $Logname -EntryType Error, Warning -After $after -Before $before -ErrorAction Stop
        if(-not([String]::IsNullOrEmpty($wmiobj))){
            $wmiobj | %{
                if($ret.EventID -notcontains $_.EventID){
                    $obj = [PSCustomObject]@{
                        Logname       = $Logname
                        TimeGenerated = $_.TimeGenerated
                        EventID       = $_.EventID
                        EntryType     = $_.EntryType
                        Message       = $_.Message
                    }
                    $ret += $obj
                }
            }
            if($OutputToJson){
                $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($Logname).json"
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Get-StoppedServices{
    [CmdletBinding()]
    param(
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    try{
        $wmiobj = Get-WmiObject Win32_Service -ErrorAction Stop | Where-Object StartMode -eq 'Auto' | Where-Object State -eq 'Stopped'
        if(-not([String]::IsNullOrEmpty($wmiobj))){
            $wmiobj | %{
                $obj = [PSCustomObject]@{
                    Name        = $_.Name
                    DisplayName = $_.DisplayName
                    Status      = $_.Status
                    State       = $_.State
                    StartMode   = $_.StartMode
                    StartName   = $_.StartName
                    Description = $_.Description
                }
                $ret += $obj
            }
            if($OutputToJson){
                $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Get-TopProcesses{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Int]$threshold
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    try{
        $wmiobj = Get-Process -ErrorAction Stop | Where-Object StartTime -ne $null | Sort WorkingSet64 -Descending | Select -First $threshold
        if(-not([String]::IsNullOrEmpty($wmiobj))){
            $wmiobj | %{
                $obj = [PSCustomObject]@{
                    ProcessName     = $_.ProcessName
                    PID             = $_.Id
                    'CPU(s)'        = "{0:0,0}" -f $_.CPU
                    Threads         = $_.Threads.Count
                    StartTime       = $_.StartTime
                    'Allocated(KB)' = "{0:0,0}" -f ($_.WorkingSet64/(1024))
                    Path            = $_.Path
                    Description     = $_.Description
                    MainWindowTitle = $_.MainWindowTitle
                }
                $ret += $obj
            }
            if($OutputToJson){
                $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Count-Processes{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Int]$threshold
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = @()
    try{
        $wmiobj = Get-Process | Select-Object ProcessName | Group-Object ProcessName | Sort-Object Count -Descending | Select -First $threshold
        if(-not([String]::IsNullOrEmpty($wmiobj))){
            $wmiobj | %{
                $obj = [PSCustomObject]@{
                    Name  = $_.Name
                    Count = $_.Count
                }
                $ret += $obj
            }
            if($OutputToJson){
                $ret | ConvertTo-Json -Compress | Out-File -FilePath "$($script:Scriptpath)\JSON\$($function).json"
            }
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret
}

function Set-HtmlMiddleEventlog{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$Logname,
        [Parameter(Mandatory=$true)][Int]   $lastdays,
        [Parameter(Mandatory=$true)][Object]$htmlTable,
        [Parameter(Mandatory=$true)][String]$status
    )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = $null
    try{
$ret += @"
<div>
<h3>$Logname Log with Warnings or Errors</h3>
<p>The following is a list of the <b>$Logname log</b> for the <b>last $lastdays days</b> that had an Event Type of either Warning or Error ($status).</p>
<table>$htmlTable</table>
</div>
"@
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
    }
    return $ret

}

function New-ChartImage{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Object]$ItemList,
        [Parameter(Mandatory=$true)][Object]$Placeholder,
        [Parameter(Mandatory=$true)][String]$ImagePath,
        [Parameter(Mandatory=$false)][String]$Titel,
        [Parameter(Mandatory=$false)][int]$ChartWidth  = 500,
        [Parameter(Mandatory=$false)][int]$ChartHeight = 300,
        [ValidateSet('Pie','Column')]
        [Parameter(Mandatory=$true)][String]$ChartType        
     )
    $function = $($MyInvocation.MyCommand.Name)
    Write-verbose $function
    $ret = $false
    try{

        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

        $MemoryUsageChart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
        $MemoryUsageChart1.Width     = $ChartWidth
        $MemoryUsageChart1.Height    = $ChartHeight
        $MemoryUsageChart1.BackColor = [System.Drawing.Color]::Transparent
        
        if(-not([String]::IsNullOrEmpty($Titel))){
            [void]$MemoryUsageChart1.Titles.Add($Titel)
            $MemoryUsageChart1.Titles[0].Font      = "arial,15pt"
            $MemoryUsageChart1.Titles[0].Alignment = "topCenter"
        }
        $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $chartarea.Name = "ChartArea1"
		   
        $MemoryUsageChart1.ChartAreas.Add($chartarea)
        [void]$MemoryUsageChart1.Series.Add("data1")
        $MemoryUsageChart1.Series["data1"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::$ChartType

        $MemoryUsageChart1.Series["data1"].Points.DataBindXY($ItemList, $Placeholder)
        $MemoryUsageChart1.SaveImage($ImagePath,"png")
        if(Test-Path -Path $ImagePath){
            $ret = $true
        }
        else{
            $false
        }
    }
    catch{
        Write-verbose "$($function): $($_.Exception.Message)"
        $Error.Clear()
        $ret = $false
    }
    return $ret
}

#region scriptglobals
$script:ScriptStart  = (get-date)
$script:Scriptpath   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Scriptname   = $MyInvocation.MyCommand.ToString()
$script:Basename     = $script:Scriptname.Remove($script:Scriptname.Length -4)
$script:Logfile      = $($script:Scriptname).Replace('.ps1','.log')
$script:version      = '1.0.0.0000'
$script:Scriptreturn = $true
$script:HTMLMenu     = @()
$script:HTMLMiddle   = $null
#endregion

$ChartControlInstalled = Test-MicrosoftChartControls -Verbose

if(-not(Test-Path -Path "$($script:Scriptpath)\JSON")){$null = New-Item -Path "$($script:Scriptpath)\" -Name "JSON" -ItemType Directory -Force}
if(-not(Test-Path -Path "$($script:Scriptpath)\images")){$null = New-Item -Path "$($script:Scriptpath)\" -Name "images" -ItemType Directory -Force}

#endregion

#region HostUptime
$htmlTable = $null
$psobj     = $null

$jsonfile = "$($script:Scriptpath)\JSON\Get-HostUptime.json"
if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
    $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
    $status = 'offline'
}
else{
    $psobj  = Get-HostUptime -threshold $ThresholdUptimeDays -Verbose 
    $status = 'online'
}

if(-not([String]::IsNullOrEmpty($psobj))){
    $script:HTMLMenu   += '<li><a href="#uptime">Uptime</a></li>'
    $script:HTMLMiddle += '<h2 id="uptime">Uptime</h2>'
    $htmlTable         = $psobj | ConvertTo-Html -Fragment 
    $script:HTMLMiddle += @"
    <div>
    <p>The following is the <b>last boot-time</b> for the computer ($status).</p>
    <table>$htmlTable</table>
    </div>
"@
}
#endregion

#region Memory
$htmlTable = $null
$psobj     = $null

$jsonfile  = "$($script:Scriptpath)\JSON\Get-Raminfo.json"
if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
    $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
    $status = 'offline'
}
else{
    $psobj  = Get-Raminfo -threshold $ThresholdMemoryPercent -Verbose
    $status = 'online'
}

if(-not([String]::IsNullOrEmpty($psobj))){
    $script:HTMLMenu   += '<li><a href="#memory">Memory</a></li>'
    $script:HTMLMiddle += '<h2 id="memory">Memory</h2>'
    $htmlTable         = $psobj | ConvertTo-Html -Fragment 
    $script:HTMLMiddle += @"
    <div>
    <p>The following list the memory usage ($status).</p>
    <table>$htmlTable</table>
    </div>
"@
}
#endregion

#region CountProcesses
$htmlTable    = $null
$psobj        = $null

$jsonfile  = "$($script:Scriptpath)\JSON\Count-Processes.json"

if($ChartControlInstalled -eq $true){

    if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
        $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
        $status = 'offline'
    }
    else{
        $psobj  = Count-Processes -threshold $ThresholdCountProcesses -Verbose
        $status = 'online'
    }
    
    if(-not([String]::IsNullOrEmpty($psobj))){

        $ProcessList = @(
            foreach($item in $psobj){
                "$($item.Name)`n$($item.Count)"
            }
        )
        $Placeholder = @(
            foreach($item in $psobj){
                $item.Count
            }
        )
        $ChartImagePath   = "$($script:Scriptpath)\images"
        $ChartTitel       = "Process Count: Top $ThresholdCountProcesses Processes"
        [int]$ChartWidth  = 450
        [int]$ChartHeight = 300
        $ret = New-ChartImage -ImagePath "$($ChartImagePath)\ProssessCountPie.png" -Titel $ChartTitel -ItemList $ProcessList -Placeholder $Placeholder -ChartWidth $ChartWidth -ChartHeight $ChartHeight -ChartType 'Pie' -Verbose
        if($ret){
            $CountProcessesChart = '<img src="images/ProssessCountPie.png">'
        }
        $ret = $null
    }
}
#endregion

#region TopProcesses
$htmlTable    = $null
$psobj        = $null

$jsonfile  = "$($script:Scriptpath)\JSON\Get-TopProcesses.json"
if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
    $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
    $status = 'offline'
}
else{
    $psobj  = Get-TopProcesses -threshold $ThresholdTopProcesses -Verbose
    $status = 'online'
}

if(-not([String]::IsNullOrEmpty($psobj))){
    $script:HTMLMenu   += '<li><a href="#processes">Processes</a></li>'
    $script:HTMLMiddle += '<h2 id="processes">Processes</h2>'
    if($ChartControlInstalled -eq $true){
        $ProcessList = @(
            foreach($item in $psobj){
                "$($item.ProcessName)`n$($item.'Allocated(KB)') KB"
            }
        )
        $Placeholder = @(
            foreach($item in $psobj){
                $item.'Allocated(KB)'
            }
        )
        $ChartImagePath   = "$($script:Scriptpath)\images"
        $ChartTitel       = "Memory Usage: Top $ThresholdTopProcesses Processes"
        [int]$ChartWidth  = 450
        [int]$ChartHeight = 300
        $ret = New-ChartImage -ImagePath "$($ChartImagePath)\PhysicalMemoryUsageClm.png" -Titel $ChartTitel -ItemList $ProcessList -Placeholder $Placeholder -ChartWidth $ChartWidth -ChartHeight $ChartHeight -ChartType 'Column' -Verbose
        if($ret){
            $TopProcessesChart = '<img src="images/PhysicalMemoryUsageClm.png">'
        }
        $ret = $null
    }
    $htmlTable         = $psobj | ConvertTo-Html -Fragment 
    $script:HTMLMiddle += @"
    <div>
    $TopProcessesChart
    $CountProcessesChart
    </div><div>
    <p>The following is a list of the <b>top $ThresholdTopProcesses processes</b> with the most allocate memory ($status).</p>
    <table>$htmlTable</table>
    </div>
"@
}
#endregion

#region Disk
$htmlTable   = $null
$psobj       = $null

$jsonfile  = "$($script:Scriptpath)\JSON\Get-Diskinfo.json"
if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
    $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
    $status = 'offline'
}
else{
    $psobj  = Get-Diskinfo -threshold $ThresholdFreeSpacePercent -Verbose
    $status = 'online'
}

if(-not([String]::IsNullOrEmpty($psobj))){
    $script:HTMLMenu   += '<li><a href="#disks">Disks</a></li>'
    $script:HTMLMiddle += '<h2 id="disks">Disk</h2>'
    $htmlTable         = $psobj | ConvertTo-Html -Fragment 
    $script:HTMLMiddle += @"
    <div>
    <p>The following list the disks with <b>less than $ThresholdFreeSpacePercent%</b> free space ($status).</p>
    <table>$htmlTable</table>
    </div>
"@
}
#endregion

#region Eventlogs
$LogsToCheck = @(
    'System',
    'Setup',
    'Application'
)

foreach($item in $LogsToCheck){
    $htmlTable = $null
    $psobj     = $null

    $jsonfile  = "$($script:Scriptpath)\JSON\$($item).json"
    if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
        $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
        $status = 'offline'
    }
    else{
        $psobj  = Get-LastEventCodes -Logname $item -day $ThresholdLastEventDays -Verbose
        $status = 'online'
    }

    if(-not([String]::IsNullOrEmpty($psobj))){
        $script:HTMLMenu   += "<li><a href=""#$item"">$($item)log</a></li>"
        $script:HTMLMiddle += "<h2 id=""$item"">$($item)log</h2>"
        $htmlTable         = $psobj | Sort-Object TimeGenerated -Descending | ConvertTo-Html -Fragment 
        $script:HTMLMiddle += Set-HtmlMiddleEventlog -Logname $item -lastdays $ThresholdLastEventDays -htmlTable $htmlTable -status $status
    }
}
#endregion

#region Services
$htmlTable = $null
$psobj     = $null

$jsonfile  = "$($script:Scriptpath)\JSON\Get-StoppedServices.json"
if(($InputFromJson -eq $true) -and (Test-Path -Path $jsonfile)){
    $psobj  = Get-Content -Path $jsonfile | ConvertFrom-Json
    $status = 'offline'
}
else{
    $psobj  = Get-StoppedServices -Verbose
    $status = 'online'
}

if(-not([String]::IsNullOrEmpty($psobj))){
    $script:HTMLMenu   += '<li><a href="#services">Services</a></li>'
    $script:HTMLMiddle += '<h2 id="services">Services</h2>'
    $htmlTable         = $psobj | ConvertTo-Html -Fragment 
    $script:HTMLMiddle += @"
    <div>
    <p>The following is a list of all <b>stopped services</b> with start-mode <b>automatic</b> ($status).</p>
    <table>$htmlTable</table>
    </div>
"@
}
#endregion

#region HTML

#region HTMLHeader
$script:HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html>
<head>
<style>
$(Get-Content -Path "$($script:Scriptpath)\styles.css")
</style>
</head>
<body>
<title>System Health Report</title>
<h1 id="home">Health report ($status) of computer $($env:COMPUTERNAME)</h1>
<ul>
<li><a class="active" href="#home">Home</a></li>
$script:HTMLMenu
<li><a href="#about">About</a></li>
</ul>
<div>
<p>Check computer's Uptime, Memory Usage, Diskspace, Eventlogs, Stopped Services, and Top Processes.</p>
<p>Threshold Uptime $ThresholdUptimeDays days.
Threshold Memory  $ThresholdMemoryPercent%.
Threshold Top $ThresholdTopProcesses Processes.
Threshold Count Processes limited to $ThresholdCountProcesses Processes.
Threshold Free Diskspace $ThresholdFreeSpacePercent%.
Threshold Events for last $ThresholdLastEventDays days.</p>
</div>
<hr />
<div>
"@
#endregion

#region HTMLFooter
$script:HTMLEnd = @"
</div>
</body>
<div>
<footer>
<p id="about">Copyright &#169 2018 <a href="https://it.martin-walther.ch" target="_blank"> it.martin-walther.ch</a></p>
</footer>
</div>
</html>
"@
#endregion

$HTMLmessage = $script:HTMLHeader + $script:HTMLMiddle + $script:HTMLEnd
$HTMLmessage | Out-File -FilePath "$($script:Scriptpath)\Logreport.html" -Force

#endregion

Start-Process -FilePath "$($script:Scriptpath)\Logreport.html"
