param(
    [Parameter(Mandatory = $true)][string]$ServerGroup,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$BackupTimestamp,
    [Parameter(Mandatory = $true)][string]$DeployPath,
    [Parameter(Mandatory = $true)][string]$AppPoolName,
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password
)

$servers = $ServerGroup -split ","
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($Username, $securePassword)

foreach ($server in $servers) {
    Invoke-Command -ComputerName $server -Credential $credential -ScriptBlock {
        param($ApplicationName, $BackupTimestamp, $DeployPath, $AppPoolName)
        Import-Module WebAdministration
        $backupPath = "D:\Backups\$ApplicationName\$BackupTimestamp"
        if (!(Test-Path $backupPath)) {
            throw "Backup not found: $backupPath"
        }
        Stop-WebAppPool -Name $AppPoolName
        Remove-Item -Path "$DeployPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "$backupPath\*" -Destination $DeployPath -Recurse -Force
        Start-WebAppPool -Name $AppPoolName
    } -ArgumentList $ApplicationName, $BackupTimestamp, $DeployPath, $AppPoolName
}

