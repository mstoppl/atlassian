$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Parse every script without executing it.
foreach ($file in Get-ChildItem -Path $repoRoot -Filter '*.ps1' -Recurse) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$parseErrors
    )
    Assert-True ($parseErrors.Count -eq 0) "PowerShell syntax errors in $($file.Name): $parseErrors"
}

# Mock vault commands so no installed module, vault, or real credential is required.
$script:moduleUnavailable = $false
$script:secretUnavailable = $false
$script:testToken = 'dummy-token'
$script:secretCalls = 0
$script:webCalls = 0
function Import-Module {
    [CmdletBinding()]
    param([string]$Name)
    Assert-True ($Name -eq 'Microsoft.PowerShell.SecretManagement') 'Unexpected module requested.'
    if ($script:moduleUnavailable) { throw 'Module unavailable' }
}
function Get-Secret {
    [CmdletBinding()]
    param([string]$Name, [string]$Vault, [switch]$AsPlainText)
    $script:secretCalls++
    Assert-True ($Name -eq 'JiraRoleAdminApiToken') 'Wrong secret selected.'
    Assert-True ($Vault -eq 'TestVault') 'Wrong vault selected.'
    Assert-True $AsPlainText.IsPresent 'Expected explicit plaintext retrieval.'
    if ($script:secretUnavailable) { throw 'provider-error-containing-dummy-secret' }
    return $script:testToken
}
function Invoke-WebRequest {
    [CmdletBinding()]
    param([string]$Uri, [string]$Method, $Headers, $ContentType, $Body)
    $script:webCalls++
    throw 'Offline tests must not send Jira requests.'
}

. (Join-Path $repoRoot 'jira-auth.ps1')
$arguments = @{
    UserEmail = 'service@example.com'
    SecretVault = 'TestVault'
    TokenSecretName = 'JiraRoleAdminApiToken'
}

$header = Get-JiraAuthorizationHeader @arguments
$decoded = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($header.Authorization.Substring(6))
)
Assert-True ($header.Count -eq 1) 'Unexpected header fields.'
Assert-True ($header.Authorization.StartsWith('Basic ')) 'Expected Basic authentication.'
Assert-True ($decoded -eq 'service@example.com:dummy-token') 'Incorrect credential encoding.'

function Assert-AuthenticationFails([string]$ExpectedMessage) {
    $failed = $false
    try { $null = Get-JiraAuthorizationHeader @arguments } catch {
        $failed = $true
        Assert-True ($_.Exception.Message -like "*$ExpectedMessage*") 'Unexpected failure message.'
        Assert-True ($_.Exception.Message -notlike '*provider-error-containing-dummy-secret*') 'Vault error leaked.'
    }
    Assert-True $failed 'Invalid authentication configuration was accepted.'
}

foreach ($invalidToken in @($null, '', '   ', 42, @{ token = 'dummy' })) {
    $script:testToken = $invalidToken
    Assert-AuthenticationFails 'non-empty string'
}
$script:testToken = 'dummy-token'
$script:secretUnavailable = $true
Assert-AuthenticationFails 'Unable to retrieve'
$script:secretUnavailable = $false
$script:moduleUnavailable = $true
$callsBefore = $script:secretCalls
Assert-AuthenticationFails 'Module unavailable'
Assert-True ($script:secretCalls -eq $callsBefore) 'Secret retrieval continued after module failure.'
$script:moduleUnavailable = $false

$arguments.UserEmail = '   '
$callsBefore = $script:secretCalls
Assert-AuthenticationFails 'Configure the Jira user email'
Assert-True ($script:secretCalls -eq $callsBefore) 'Secret retrieved for invalid configuration.'
$arguments.UserEmail = 'service@example.com'

# Actual entry points must stop before any request when credentials are unavailable.
$script:testToken = $null
foreach ($name in @('addprojectrole.ps1', 'export_projects_in_cfs_automations.ps1')) {
    $failed = $false
    try {
        & (Join-Path $repoRoot $name) -SecretVault TestVault -TokenSecretName JiraRoleAdminApiToken
    } catch { $failed = $true }
    Assert-True $failed "$name did not stop with missing credentials."
    Assert-True ($script:webCalls -eq 0) "$name attempted a request before authentication succeeded."
}

Write-Host 'PASS: syntax, header encoding, vault selection, invalid secrets, sanitized errors, and preflight failures.'
