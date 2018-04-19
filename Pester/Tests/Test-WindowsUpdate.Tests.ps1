<#
    .SYNOPSIS
     Test some things with pester

    .DESCRIPTION
     Test services, connectivity, files and registry for windows update configuration

    .PARAMETER ServicesToCheck
     Array with PSCustmObjects

    .PARAMETER ConnectivytoToTest
     Array with PSCustmObjects

    .PARAMETER ScheduledTasksToTest
     Array with PSCustmObjects

    .PARAMETER FilesToTest
     Array with PSCustmObjects

    .PARAMETER RegkeysToTest
     Array with PSCustmObjects
   

    .NOTES
     https://github.com/pester/Pester/wiki/Invoke-Pester

    .EXAMPLE
    $pesterObj = Invoke-Pester -Script @{
        Path = "$($script:Scriptpath)\$($ScriptToTest)"
        Parameters = @{
            ScheduledTasks = @('Reboot','SynchronizeTime','SystemSoundsService')
            ServiceToCheck = 'netlogon'
            ServerToTest   = '127.0.0.1'
            PortToTest     = '80'
            ScriptToTest   = "$($script:Scriptpath)\$($ScriptToTest)"
        }
    } -PassThru -Show Summary

#>

[CmdletBinding()]
param(

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [string]$Testname = 'Windows Update',

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [Object]$ServicesToCheck = @(
        [PSCustomObject] @{
            Context = 'Test serivce'; 
            Name    = 'wuauserv'; 
            Mode    = 'Auto'; 
            State   = 'Running'
            Expect  = 'True'
        },
        [PSCustomObject] @{
            Context = 'Test serivce'; 
            Name    = 'Netlogon'; 
            Mode    = 'Manual'; 
            State   = 'Stopped'
            Expect  = 'True'
        }
    ),

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [Object]$ConnectivytoToTest = @(
        [PSCustomObject] @{
            Context = 'Test connectivity to'; 
            Name    = 'wsus.company.com'; 
            TcpPort = '8530'; 
            Expect  = 'True'
        },
        [PSCustomObject] @{
            Context = 'Test connectivity to'; 
            Name    = 'windowsupdate.microsoft.com'; 
            TcpPort = '80'; 
            Expect  = 'True'
        }
    ),

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [Object]$ScheduledTasksToTest = @(
        [PSCustomObject] @{
            Context = 'Test Scheduled Task'; 
            Name    = 'PolicyConverter'; 
            Expect  = 'True'
        },
        [PSCustomObject] @{
            Context = 'Test Scheduled Task'; 
            Name    = 'SynchronizeTime'; 
            Expect  = 'True'
        },
        [PSCustomObject] @{
            Context = 'Test Scheduled Task'; 
            Name    = 'SystemSoundsService'; 
            Expect  = 'True'
        }
    ),

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [Object]$FilesToTest = @(
        [PSCustomObject] @{
            Context = 'Test File'; 
            Name    = 'C:\Windows\System32\drivers\etc\hosts'; 
            Expect  = 'True'
        },
        [PSCustomObject] @{
            Context = 'Test File'; 
            Name    = 'C:\Temp\Test.log'; 
            Expect  = 'True'
        }
    ),

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [Object]$RegkeysToTest = @(
        [PSCustomObject] @{
            Context = 'Test Registry path for'; 
            Name     ='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\WUServer'
            Property ='WUServer'
            Expect   ='http://wsus.company.com:8530'
        },
        [PSCustomObject] @{
            Context = 'Test Registry path for'; 
            Name     ='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\WUStatusServer'
            Property ='WUStatusServer'
            Expect   ='http://wsus.company.com:8530'
        }
    )

)

Describe -Name $Testname {  

    BeforeAll{
        if($Error){$Error.Clear()}
        Write-Verbose "Test $Testname"
    }

    #region Services
    foreach($item in $ServicesToCheck){
        Context "$($item.Context) $($item.Name)" {
            $TestObject = Get-WmiObject -Class win32_service -Filter "name='$($item.Name)'" -ErrorAction SilentlyContinue
            if($TestObject.StartMode -eq $item.Mode -and $TestObject.State -eq $item.State){
                $ServiceStauts = $true
            }
            else{
                $ServiceStauts = $false
            }
            It "Should get Servicestate $($item.Mode) and $($item.State) $($item.Expect)" {
                $ServiceStauts | Should Be $item.Expect
            }
        }
    }
    #endregion

    #region Connectivity
    foreach($item in $ConnectivytoToTest){
        Context "$($item.Context) $($item.Name)" {
            $TestObject = Test-NetConnection -ComputerName $item.Name -Port $item.TcpPort -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            It "Should get TcpTest succeeded" {
                $TestObject.TcpTestSucceeded | Should Be $item.Expect
            }
        }
    }
    #endregion

    #region ScheduledTasks
    foreach($item in $ScheduledTasksToTest){
        Context "$($item.Context) $($item.Name)" {
            $TestObject = Get-ScheduledTask -TaskName $item.Name -ErrorAction SilentlyContinue
            It "Should get TaskName $($item.Name)" {
                $TestObject.TaskName | Should Be $item.Name
            }
            if($TestObject.State -eq 'Ready' -or $TestObject.State -eq 'Running'){
                $Status = $true
            }
            else{
                $Status = $false
            }
            It "Should get TaskState Ready or Running" {
                $Status | Should Be $item.Expect
            }
        }
    }
    #endregion

    #region Files or Folder
    foreach($item in $FilesToTest){
        Context "$($item.Context) $($item.Name)" {
            $TestObject = Test-Path -Path $item.Name -ErrorAction SilentlyContinue
            It 'Should be Exists' {
                $TestObject | Should Be $item.Expect
            }
        }
    }
    #endregion

    #region Registry
    foreach($item in $RegkeysToTest){
        Context "$($item.Context) $($item.Property)" {
            $TestObject = Get-ItemProperty -Path $item.Name -Name $item.Property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $item.Property
            It "Should be $($item.Expect)" {
                $TestObject | Should  Be $item.Expect
            }
        }
    }
    #endregion
    
    AfterAll{
        if($Error){$Error.Clear()}
        Write-Verbose "End $Testname"
    }
}
