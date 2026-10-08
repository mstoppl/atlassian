# Shared credential retrieval for the Jira API scripts.
function Get-JiraAuthorizationHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserEmail,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretVault,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TokenSecretName
    )

    if ([string]::IsNullOrWhiteSpace($UserEmail) -or
        [string]::IsNullOrWhiteSpace($SecretVault) -or
        [string]::IsNullOrWhiteSpace($TokenSecretName)) {
        throw "Configure the Jira user email, vault name, and token secret name before running."
    }

    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop

    try {
        $apiToken = Get-Secret -Name $TokenSecretName -Vault $SecretVault -AsPlainText -ErrorAction Stop
    } catch {
        # Do not include a vault provider's exception text, which might contain sensitive data.
        throw "Unable to retrieve the Jira API token. Check the vault registration, unlock state, and secret name."
    }

    if ($apiToken -isnot [string] -or [string]::IsNullOrWhiteSpace($apiToken)) {
        throw "The Jira API token secret must be a non-empty string."
    }

    # Basic authentication needs plaintext in process memory; never log this value or header.
    $encodedCredential = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes(('{0}:{1}' -f $UserEmail, $apiToken))
    )
    return @{ Authorization = ('Basic {0}' -f $encodedCredential) }
}
