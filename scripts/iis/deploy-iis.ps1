param(
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$Environment,
    [Parameter(Mandatory = $true)][string]$ArtifactPath,
    [Parameter(Mandatory = $true)][string]$ServerGroup,
    [Parameter(Mandatory = $true)][string]$SiteName,
    [Parameter(Mandatory = $true)][string]$AppPoolName,
    [Parameter(Mandatory = $true)][string]$DeployPath,
    [Parameter(Mandatory = $true)][string]$HealthCheckUrl,
    [Parameter(Mandatory = $true)][bool]$RollbackEnabled,
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password
)

$servers = $ServerGroup -split ","
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($Username, $securePassword)
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

foreach ($server in $servers) {
    $serverName = $server.Trim()
    if ([string]::IsNullOrWhiteSpace($serverName)) {
        continue
    }

    $session = New-PSSession -ComputerName $serverName -Credential $credential
    try {
        $remoteTemp = Invoke-Command -Session $session -ScriptBlock {
            param($ApplicationName, $timestamp)
            $path = "D:\DeployTemp\$ApplicationName\$timestamp"
            New-Item -ItemType Directory -Force -Path $path | Out-Null
            return $path
        } -ArgumentList $ApplicationName, $timestamp

        $remoteArtifactPath = Join-Path $remoteTemp "artifact.zip"
        Copy-Item -Path $ArtifactPath -Destination $remoteArtifactPath -ToSession $session -Force

        Invoke-Command -Session $session -ScriptBlock {
            param($RemoteArtifactPath, $DeployPath, $AppPoolName, $SiteName, $ApplicationName, $timestamp)

        Import-Module WebAdministration
        $backupPath = "D:\Backups\$ApplicationName\$timestamp"
        New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
        if (Test-Path $DeployPath) {
            Copy-Item -Path "$DeployPath\*" -Destination $backupPath -Recurse -Force
        }

        Stop-WebAppPool -Name $AppPoolName
        Start-Sleep -Seconds 5
        New-Item -ItemType Directory -Force -Path $DeployPath | Out-Null
        Remove-Item -Path "$DeployPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $RemoteArtifactPath -DestinationPath $DeployPath -Force
        if (Test-Path "$DeployPath\publish") {
            Copy-Item -Path "$DeployPath\publish\*" -Destination $DeployPath -Recurse -Force
            Remove-Item -Path "$DeployPath\publish" -Recurse -Force
        }
        Start-WebAppPool -Name $AppPoolName
        Start-Website -Name $SiteName
        } -ArgumentList $remoteArtifactPath, $DeployPath, $AppPoolName, $SiteName, $ApplicationName, $timestamp
    }
    finally {
        if ($session) {
            Remove-PSSession $session
        }
    }
}

$response = Invoke-WebRequest -Uri $HealthCheckUrl -UseBasicParsing -TimeoutSec 30
if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
    throw "Health check failed: $HealthCheckUrl"
}

@{
    application = $ApplicationName
    environment = $Environment
    serverGroup = $ServerGroup
    backupTimestamp = $timestamp
    deployPath = $DeployPath
    healthCheckUrl = $HealthCheckUrl
    rollbackEnabled = $RollbackEnabled
} | ConvertTo-Json -Depth 5 | Out-File -FilePath "iis-deployment-evidence.json" -Encoding utf8
