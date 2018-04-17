<#
    .SYNOPSIS
    MasterScript for Pester-Tests
#>
#region scriptglobals
$script:Scriptpath   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Scriptname   = $MyInvocation.MyCommand.ToString()
$script:Basename     = $script:Scriptname.Remove($script:Scriptname.Length -4)
$script:Logfile      = $($script:Scriptname).Replace('.ps1','.log')
$script:version      = '1.0.0.0000'
$script:Scriptreturn = @()
#endregion

$ScriptsToTest = Get-ChildItem -Path $script:Scriptpath -Filter '*.Tests.ps1'
$pesterObj     = @()

Write-Verbose "Start $($script:Scriptname)" -Verbose

foreach($script in $ScriptsToTest){
    $pesterObj += Invoke-Pester -Script "$($script:Scriptpath)\$($ScriptToTest)" -PassThru -Show All
}
$pesterObj.TestResult | Select Context,Name,Result,StackTrace,FailureMessage | ft -AutoSize

Write-Verbose "End  $($script:Scriptname)" -Verbose
