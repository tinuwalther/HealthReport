
<#
    .SYNOPSIS
     Test some things with pester

    .DESCRIPTION
     Test services, connectivity, files and registry for windows update configuration

    .PARAMETER configfile
     Fullpath to the configfile   

    .NOTES
     Author: Martin Walther
     Link:   https://it.martin-walther.ch

     https://github.com/pester/Pester/wiki/Invoke-Pester

    .EXAMPLE
     $PesterReturn += Invoke-Pester -Script @{
        Path = $script.FullName
        Parameters = @{
            configfile = $pesterconfig
        }
    } -PassThru -OutputFormat NUnitXml -OutputFile $($Xmlfile)

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [String]$ConfigName
)

#region scriptglobals
$script:Scriptpath = (Split-Path -Parent $MyInvocation.MyCommand.Path) -replace '\\Tests'
$script:Scriptname = $MyInvocation.MyCommand.ToString()

$script:config           = Get-Content -Path "$($script:Scriptpath)\Config\config.json" | ConvertFrom-Json
$script:Version          = $script:config.general.Version

$Logfolder               = "$($script:Scriptpath)\$($script:config.startscript.Logfolder)"
$Reportfolder            = "$($script:Scriptpath)\$($script:config.startscript.Reportfolder)"
$ConfigFolder            = "$($script:Scriptpath)\$($script:config.startscript.ConfigFolder)"
$Internalfolder          = "$($script:Scriptpath)\$($script:config.startscript.Internalfolder)"

$script:PesterConfigFile = "$($ConfigFolder)\$($script:config.startscript.PesterConfig)"
$script:Logfile          = "$($Logfolder)\$($script:config.startscript.Logfile)"
$script:Jsonfile         = "$($Reportfolder)\$($script:config.startscript.JsonFile)"
$script:Xmlfile          = "$($Reportfolder)\$($script:config.startscript.Xmlfile)"
#endregion

Import-Module "$($Internalfolder)\Assert-SystemCompliance.psm1"

Describe -Name "System Compliance Test" {  
    BeforeAll{
        if($Error){$Error.Clear()}
    }
    Context "Test the actual Uptime of this computer" {
        # -- Arrange
        $ThresholdUptimeDays = 10
        # -- Act
        $Actual = Get-HostUptime -threshold $ThresholdUptimeDays
        # -- Assert
        It "Should be less than $($ThresholdUptimeDays)" {
            [Int]$Actual.Days | Should BeLessThan $ThresholdUptimeDays
        }
    }
    Context "Test the Free Memory in percent of this computer" {
        # -- Arrange
        $ThresholdMemoryPercent = 30
        # -- Act
        $Actual = Get-Raminfo -threshold $ThresholdMemoryPercent
        # -- Assert
        It "Should be greather than $($ThresholdMemoryPercent)%" {
            $Actual.'Free(%)' | Should BeGreaterThan $ThresholdMemoryPercent
        }
    }
    Context "Test the Free Disk space in percent of this computer" {
        # -- Arrange
        $ThresholdFreeSpacePercent = 30
        # -- Act
        $Actual = Get-Diskinfo -threshold $ThresholdFreeSpacePercent
        # -- Assert
        It "Should be greather than $($ThresholdFreeSpacePercent)%" {
            $Actual.'Free(%)' | Should BeGreaterThan $ThresholdFreeSpacePercent
        }
    }
    Context "Test the Systemlog for Errors or Warnings of this computer" {
        # -- Arrange
        $ThresholdLastEventDays = 3
        # -- Act
        $Actual = Get-LastEventCodes -Logname System -day $ThresholdLastEventDays
        # -- Assert
        It "Should be less than $($ThresholdLastEventDays) Errors or Warnings" {
            $Actual.Count | Should BeLessThan $ThresholdLastEventDays
        }
    }
    Context "Test the Applicationlog for Errors or Warnings of this computer" {
        # -- Arrange
        $ThresholdLastEventDays = 3
        # -- Act
        $Actual = Get-LastEventCodes -Logname Application -day $ThresholdLastEventDays
        # -- Assert
        It "Should be less than $($ThresholdLastEventDays) Errors or Warnings" {
            $Actual.Count | Should BeLessThan $ThresholdLastEventDays
        }
    }
    Context "Test for stopped Services with StartMode automatic of this computer" {
        # -- Arrange
        # -- Act
        $Actual = Get-StoppedServices
        # -- Assert
        It "Should be NullOrEmpty" {
            $Actual | Should BeNullOrEmpty 
        }
    }
    Context "Test for the last installed Hotfix of this computer" {
        # -- Arrange
        $ThresholdLastHotfixes = 1
        $ThresholdInstalledOn  = 45
        # -- Act
        $Actual = Get-InstalledHotfixes -threshold $ThresholdLastHotfixes
        $StartDate = $Actual.InstalledOn
        $EndDate   = get-date
        $Expect    = New-TimeSpan –Start $StartDate –End $EndDate | Select -ExpandProperty Days
        # -- Assert
        It "Should be less than $ThresholdInstalledOn days" {
            $Expect | Should BeLessThan $ThresholdInstalledOn
        }
    }
}    
