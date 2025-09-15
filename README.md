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
*   `$jiratoken`: The API token for the Jira user.
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
*   `$cloudpassword`: The API token for the Jira user.
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

## Usage

1.  **Prerequisites**: Ensure you have PowerShell installed on your system.
2.  **Configuration**: Before running any of the scripts, open them in a text editor and configure the variables in the "Configuration" section at the top of the file.
3.  **Execution**: Run the scripts from a PowerShell terminal.

---
