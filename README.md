# Jira Administration PowerShell Scripts

This project is a collection of PowerShell scripts designed to help with the administration and reporting of a Jira Cloud instance.

## Scripts

This repository contains the following scripts:

1.  `addprojectrole.ps1`
2.  `export_projects_in_cfs_automations.ps1`
3.  `json-automations-report.ps1`

---

### 1. `addprojectrole.ps1`

#### Purpose

This script adds a specified user role to all Jira projects, with the option to exclude certain projects. This is useful for ensuring a service account has the necessary permissions across all projects.

#### Configuration

Before running the script, you must configure the following variables within the script itself:

*   `$jiracloudurl`: The URL of your Jira Cloud instance (e.g., `https://your-instance.atlassian.net`).
*   `$jirauser`: The email address of the Jira user to authenticate as (e.g., a service account).
*   `-SecretVault`: The registered SecretManagement vault name (defaults to `JiraVault`).
*   `-TokenSecretName`: The API-token secret name (defaults to `JiraRoleAdminApiToken`).
*   `$excludedprojects`: A PowerShell array of project keys to exclude from the operation (e.g., `PRJKEY1`, `PRJKEY2`).
*   `$userstoadd`: A PowerShell array of the Atlassian account IDs of the users to add to the role.
*   `$rolename`: The name of the role to which the users will be added (e.g., "Service account").
*   `$log`: The file path for the log file that records where roles were added.

#### Output

*   The script will add the specified users to the specified role in all non-excluded Jira projects.
*   A log file is created at the path specified by `$log`, containing a record of each project, role ID, and user ID that was added.
*   The script also includes a commented-out "Rollback" section that can be used to undo the changes.

---

### 2. `export_projects_in_cfs_automations.ps1`

#### Purpose

This script exports detailed information about Jira projects, custom fields, and automation rules. It's useful for auditing and reporting on your Jira configuration.

#### Configuration

*   `$appurl`: The URL of your Jira Cloud instance.
*   `$clouduser`: The email address of the Jira user to authenticate as.
*   `-SecretVault`: The registered SecretManagement vault name (defaults to `JiraVault`).
*   `-TokenSecretName`: The API-token secret name (defaults to `JiraReportingApiToken`).
*   You must have a file named `automation-rules-202408161151.json` in `C:\temp\` (or update the path in the script). This file should contain an export of your Jira automation rules.

#### Output

The script generates two CSV files in `c:\temp`:

*   `jira-customfields.csv`: Contains information about custom fields, their contexts, and their project mappings.
*   `jira-automations.csv`: Contains information about automation rules and the projects they are scoped to.

---

### 3. `json-automations-report.ps1`

#### Purpose

This script analyzes a JSON export of Jira automation rules to identify and report on incoming and outgoing webhooks. This is particularly useful for identifying legacy webhooks that may need to be updated.

#### Configuration

*   `$home`: This script uses the `$home` environment variable to locate the input file and determine the output directory.
*   You must have a JSON file containing your exported automation rules (e.g., `automation-rules-202501010000.json`) in your user's `Downloads` folder (or update the path in the script).
*   `$outputdir`: The directory where the output CSV files will be saved (defaults to `$home/tmp`).
*   `$siteid`: Your Jira site ID, which can be found in the URL of an incoming webhook in Jira Automation.

#### Output

The script generates two CSV files in the specified output directory:

*   `incoming-webhooks.csv`: Lists all automation rules triggered by an incoming webhook, along with their legacy and new webhook URLs.
*   `outgoing-webhooks.csv`: Lists all outgoing webhooks called by automation rules, and attempts to map them to the automation they call.

## API credentials with PowerShell SecretManagement

The two scripts that call Jira load their API tokens at runtime through
`Microsoft.PowerShell.SecretManagement`. They share `jira-auth.ps1`, which must
remain alongside the scripts. Configure the matching Jira account email and
site URL in each script, but never paste API tokens into source files.

### One-time local vault setup

For interactive runs, use PowerShell 7 and an encrypted local SecretStore vault.
Run setup under the same operating-system account that will run the scripts:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name JiraVault -ModuleName Microsoft.PowerShell.SecretStore

Set-Secret -Name JiraRoleAdminApiToken -Vault JiraVault -Secret (Read-Host "Role administration API token" -AsSecureString)
Set-Secret -Name JiraReportingApiToken -Vault JiraVault -Secret (Read-Host "Reporting API token" -AsSecureString)
```

Keep SecretStore's default password protection. It prompts to initialize or
unlock the vault when needed. If `JiraVault` is already registered, skip the
registration command. Use separate, appropriately restricted Jira accounts and
tokens for administration and reporting; separate secret names alone do not
restrict permissions.

### Running with a vault

```powershell
./addprojectrole.ps1 -SecretVault JiraVault -TokenSecretName JiraRoleAdminApiToken
./export_projects_in_cfs_automations.ps1 -SecretVault JiraVault -TokenSecretName JiraReportingApiToken
```

The vault must contain a string secret holding the API token. A missing module,
inaccessible vault, or missing, blank, or incorrectly typed secret stops the
script before it sends Jira requests. The scripts explicitly select the vault
rather than relying on a user's default vault.

SecretManagement is a vault interface: other registered vault extensions can
be used without changing the scripts. For unattended runs, provision access for
the execution account and use a vault authentication method suitable for
automation. Do not hardcode a vault unlock password or disable password
protection merely to suppress prompts.

Retrieval uses `Get-Secret -AsPlainText` because Basic authentication requires
the token when constructing the header. The token and encoded credential exist
in process memory during execution; Base64 is not encryption. Use an HTTPS Jira
URL and never log credentials or authorization headers. This change does not
remove webhook secrets from the CSV reports produced by
`json-automations-report.ps1`; protect those reports and the input JSON exports.

Microsoft considers SecretManagement and SecretStore feature complete and no
longer actively develops them, while continuing security and critical bug fixes.
See the [Microsoft overview](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/overview)
and [Get-Secret documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.secretmanagement/get-secret).

## Validation

Run the offline checks in PowerShell 7:

```powershell
pwsh -NoProfile -File ./tests/jira-auth.Tests.ps1
```

They check PowerShell syntax, credential retrieval and header construction,
rejection of unusable secrets, and sanitized vault errors. They use mock vault
commands and make no Jira calls.

## Usage

1.  **Prerequisites**: Ensure you have PowerShell installed on your system.
2.  **Configuration**: Before running any of the scripts, open them in a text editor and configure the variables in the "Configuration" section at the top of the file.
3.  **Execution**: Run the scripts from a PowerShell terminal.

---
