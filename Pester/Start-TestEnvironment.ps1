<#
    .SYNOPSIS
    MasterScript for Pester-Tests
#>

#region scriptglobals
$script:ScriptStart  = (get-date)
$script:Scriptpath   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Scriptname   = $MyInvocation.MyCommand.ToString()
$script:Scriptreturn = @()
#endregion

#region Configuration
$config        = Get-Content -Path "$($script:Scriptpath)\Internals\config.json" | ConvertFrom-Json
$Logfolder     = "$($script:Scriptpath)\$($config.Logfolder)"
$Reportfolder  = "$($script:Scriptpath)\$($config.Reportfolder)"
$Scriptfolder  = "$($script:Scriptpath)\$($config.Scriptfolder)"
$Logfile       = "$($Logfolder)\$($config.Logfile)"
$Jsonfile      = "$($Reportfolder)\$($config.JsonFile)"
$Xmlfile       = "$($Reportfolder)\$($config.Xmlfile)"
$Version       = $config.Version
#endregion

$ScriptsToTest = Get-ChildItem -Path $script:Scriptfolder -Filter '*.Tests.ps1'
$PesterReturn  = @()    

"$(Get-Date -DisplayHint DateTime) [INFORMATION] Start $($script:Scriptname), Version $($Version)" | Out-File -FilePath $($Logfile) -Encoding default

foreach($script in $ScriptsToTest){
    "$(Get-Date -DisplayHint DateTime) [INFORMATION] Running $($script.Name)." | Out-File -FilePath $($Logfile) -Append -Encoding default    
    $PesterReturn += Invoke-Pester -Script $script.FullName -PassThru -OutputFormat NUnitXml -OutputFile $($Xmlfile)
}
$PesterReturn.TestResult | Select-Object Describe,Context,Name,Result | Format-Table -AutoSize
$PesterReturn.TestResult | Select-Object * | ConvertTo-Json | Out-File -FilePath $($Jsonfile)

#region output
"$(Get-Date -DisplayHint DateTime) [INFORMATION] Tests completed in: $($PesterReturn.Time)" | Out-File -FilePath $($Logfile) -Append -Encoding default
"$(Get-Date -DisplayHint DateTime) [INFORMATION] Total: $($PesterReturn.TotalCount), Passed: $($PesterReturn.PassedCount), Failed: $($PesterReturn.FailedCount), Skipped: $($PesterReturn.SkippedCount), Pending: $($PesterReturn.PendingCount)"   | Out-File -FilePath $($Logfile) -Append -Encoding default
"$(Get-Date -DisplayHint DateTime) [INFORMATION] More details could be fond at: $($Jsonfile)" | Out-File -FilePath $($Logfile) -Append -Encoding default
#endregion

"$(Get-Date -DisplayHint DateTime) [INFORMATION] End $($script:Scriptname)" | Out-File -FilePath $($Logfile) -Append -Encoding default