Add-Type -AssemblyName System.Web

# Configuration
$jiracloudurl="instance"
$jirauser="serviceaccount"
$jiratoken="token"
$excludedprojects=@("PROJECT1","PROJECT1")
$userstoadd=$("12345:1111111-2222222-333333-44444") # from user directory on admin.atlassian.com
$rolename="Service account"
$log="c:\temp\whereadded-test4.csv"

[string]$cloudauthorizationInfo= ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $jirauser, $jiratoken))))

 
function Failure {
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd();
    $global:responseBody
    Write-Host -ForegroundColor:Red "Error: $_ - $(($global:responsebody | convertfrom-json).errormessages)"
}

$index=0
$projects=@()
do
{
    $webrequest=$(Invoke-WebRequest -Uri "$jiracloudurl/rest/api/3/project/search?startAt=$index&maxResults=50" -Method Get -ContentType "application/json" -Headers @{Authorization = ('Basic {0}' -f $cloudauthorizationInfo)}).content | convertfrom-json
    $projects+=$webrequest.values
    $index+=50
} until ($webrequest.isLast)

"Project;RoleID;UserID" | out-file $log -force
foreach ($project in $($projects | where {$excludedprojects -notcontains $_.key}))
{
    "Processing $($project.key)"
    $projectdata=((Invoke-WebRequest -Uri "$jiracloudurl/rest/api/3/project/$($project.key)" -Method Get -Headers @{Authorization = ('Basic {0}' -f $cloudauthorizationInfo)}).content | convertfrom-json)   
    $roledata=$projectdata.roles.$rolename
    if ($roledata -ne $null)
    {
        $members=((Invoke-WebRequest -Uri $roledata -Method Get -Headers @{Authorization = ('Basic {0}' -f $cloudauthorizationInfo)}).content | convertfrom-json)
        foreach ($usertoadd in $userstoadd)
        {
            if ($members.actors.actoruser.accountid -notcontains $usertoadd)
            { "$($project.key);$($members[0].id);$($usertoadd)"  | out-file $log -append
              $webresponse=((Invoke-WebRequest -Uri $roledata -Method Post -ContentType "application/json" -body "{ ""user"": [""$usertoadd""]}" -Headers @{Authorization = ('Basic {0}' -f $cloudauthorizationInfo)}).content)
            }
        }
    } else { "$($project.key) ERROR: There is no role $rolename" }
}

<#
# Rollback
$data=import-csv $log -delimiter ";"
foreach ($record in $data)
{

   # $webresponse=(Invoke-WebRequest -Uri "$jiracloudurl/rest/api/3/project/$($record.project)/role/$($record.roleid)?$([System.Web.HttpUtility]::UrlEncode($urlparam))" -Method Post -ContentType "application/json" -body "{ ""user"": [""$usertoadd""]}" -Headers @{Authorization = ('Basic {0}' -f $cloudauthorizationInfo)}).content
}
#>
