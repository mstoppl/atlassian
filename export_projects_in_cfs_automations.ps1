$appurl="https://myinstance.atlassian.net"
$clouduser=""
$cloudpassword="" #actually token
# Basic authentication
[string]$cloudauthinfo= ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $clouduser, $cloudpassword))))
$authheader=@{Authorization = ('Basic {0}' -f $cloudauthinfo)}

# Get project and project categories
$projects=@()
$webresults=(invoke-webrequest -uri "$appurl/rest/api/2/project" -Headers $authheader).content | convertfrom-json
foreach ($webresult in $webresults)
{
    $project="" | select id,key,name,projectcategory
    $project.id=$webresult.id
    $project.key=$webresult.key
    $project.name=$webresult.name
    $project.projectcategory=$webresult.projectcategory.name
    $projects+=$project
}

# Get custom field, their contexts and scope
$customfieldresults=@()
$fields=$((invoke-webrequest -uri "$appurl/rest/api/2/field" -Headers $authheader).content | convertfrom-json) | where {$_.custom } | select id,key,name
foreach ($field in $fields)
{
    $contexts=@()
    $index=0
    do
    {
        $webresult=(invoke-webrequest -uri "$appurl/rest/api/2/field/$($field.id)/context?startAt=$index&maxResults=25" -Headers $authheader).content | convertfrom-json
        foreach ($value in $webresult.values)
        {
            $contexts+=$value | select id,name,description
        }
        $index+=25
    } until($webresult.isLast)
    $index=0
    do
    {
        $webresult=(invoke-webrequest -uri "$appurl/rest/api/2/field/$($field.id)/context/projectmapping?startAt=$index&maxResults=25" -Headers $authheader).content | convertfrom-json
        foreach ($value in $webresult.values)
        {
            $customfieldresult="" | select CF_Id,CF_Name,CX_Id,CX_Name,CX_Description,CX_Mapping_Project,CX_Mapping_ProjectCategory,CX_Mapping_IsGlobal
            $customfieldresult.cf_id=$field.id
            $customfieldresult.cf_name=$field.name
            $context=$contexts | where {$_.id -eq $value.contextId}
            $customfieldresult.cx_id=$context.id
            $customfieldresult.cx_name=$context.name
            $customfieldresult.cx_description=$context.description
            if ($value.isGlobalContext)
            {
                $customfieldresult.cx_mapping_isglobal=$True
            } else
            {
                $project=$projects | where {$_.id -eq $value.projectId }
                $customfieldresult.cx_mapping_project=$project.name
                $customfieldresult.cx_mapping_projectcategory=$project.projectcategory
                $customfieldresult.cx_mapping_isglobal=$False
            }
            $customfieldresults+=$customfieldresult
        }
        $index+=25
    } until($webresult.isLast)
}
$customfieldresults | sort cf_name,cx_name,cx_project_mapping | export-csv c:\temp\jira-customfields.csv -encoding:utf8 -NoTypeInformation -force


# Import exported automations and get list of projects they are scoped to
$automations=get-content "C:\temp\automation-rules-202408161151.json" | convertfrom-json
$autoresults=@()
foreach ($automation in $automations.rules)
{
    if ($automation.projects.count -eq 0)
    {
        $autoresult="" | select RULE_Name,RULE_Description,RULE_State,PROJECT_Name,PROJECT_ProjectCategory
        $autoresult.RULE_Name=$automation.name
        $autoresult.RULE_Description=$automation.Description
        $autoresult.RULE_State=$automation.state
        $autoresults+=$autoresult
    } else
    {
        foreach ($ruleproject in $automation.projects)
        {
            $project=$projects | where {$_.id -eq $ruleproject.projectid}
            $autoresult="" | select RULE_Name,RULE_Description,RULE_State,PROJECT_Name,PROJECT_ProjectCategory
            $autoresult.RULE_Name=$automation.name
            $autoresult.RULE_Description=$automation.Description
            $autoresult.RULE_State=$automation.state
            $autoresult.PROJECT_Name=$project.name
            $autoresult.PROJECT_ProjectCategory=$project.projectcategory
            $autoresults+=$autoresult
        }
    }
}
$autoresults | sort rule_name,project_name | export-csv c:\temp\jira-automations.csv -encoding:utf8 -NoTypeInformation -force