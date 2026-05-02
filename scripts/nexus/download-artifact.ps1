param(
    [Parameter(Mandatory = $true)][string]$ArtifactUrl,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password
)

$credentialText = "{0}:{1}" -f $Username, $Password
$encodedCredential = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($credentialText))
Invoke-WebRequest -Uri $ArtifactUrl -OutFile $OutputPath -Headers @{ Authorization = "Basic $encodedCredential" }
