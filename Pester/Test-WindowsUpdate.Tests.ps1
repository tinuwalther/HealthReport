<#
    .References
    https://github.com/pester/Pester/wiki/Invoke-Pester
    http://powershelldistrict.com/pester-in-3-blog-posts-install-pester/

    .Example
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

param(

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$ServerToTest = '127.0.0.1',

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$PortToTest = '80',

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$ServiceToCheck = 'wuauserv',

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [string]$ScriptToTest = 'C:\Pester\MasterPesterScript.ps1',

  [Parameter(Mandatory=$false)]
  [ValidateNotNullOrEmpty()]
  [Object]$ScheduledTasks = @('Reboot','SynchronizeTime','SystemSoundsService')

)

if($Error){$Error.Clear()}

Describe -Name 'Test-WindowsUpdateConfiguration'{  

    foreach($item in $ScheduledTasks){
        Context "Test Scheduled Task $($item)"{
            $TestObject = Get-ScheduledTask -TaskName $item -ErrorAction SilentlyContinue
            It "Should get ScheduledTask $item" {
                $TestObject.TaskName | Should Be $item
            }
            if($TestObject.State -eq 'Ready' -or $TestObject.State -eq 'Running'){
                $Status = $true
            }
            else{
                $Status = $false
            }
            It 'Should have a state Ready or Running' {
                $Status | Should Be $true
            }
        }
    }

    Context "Test Update Script $($ScriptToTest)"{
        $TestObject = Test-Path -Path $ScriptToTest
        if($TestObject -eq $true){
            $exists = 'Exists'
        }
        else{
            $exists = 'NotExists'
        }
        It 'Should be Exists' {
            $exists | Should Be $true
        }
    }

    Context "Test service $($ServiceToCheck)"{
        $TestObject = Get-WmiObject -Class win32_service -Filter "name='$ServiceToCheck'" -ErrorAction SilentlyContinue
        It 'Should get State is running' {
            $TestObject.State | Should Be 'Running'
        }
        It 'Should have StartMode Auto' {
            $TestObject.StartMode | Should Be 'Auto'
        }
    }

    Context "Test connectivity to $($ServerToTest)"{
        $TestObject = Test-NetConnection -ComputerName $ServerToTest -Port $PortToTest -ErrorAction SilentlyContinue
        if($TestObject.TcpTestSucceeded -eq $true){
            $TcpTestSucceeded = $true
        }
        else{
            $TcpTestSucceeded = $false
        }
        It 'Should get TcpTestSucceeded -eq True' {
            $TcpTestSucceeded | Should Be $true
        }
    }

}
