$obj = [PSCustomObject]@{
    Version      = '1.0.0.0000'
    Logfolder    = 'Logs'
    Scriptfolder = 'Tests'    
    Reportfolder = 'Reports'
    Logfile      = 'TestEnvironment.log'
    JsonFile     = 'TestEnvironment.json'
    XmlFile      = 'TestEnvironment.xml'
}
$obj | ConvertTo-Json -Compress | Out-File '.\config.json' -Force