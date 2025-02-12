$rules=get-content -path "$home/Downloads/automation-rules-202501010000.json" -encoding utf8 | convertfrom-json # json with exported automation rules
$outputdir="$home/tmp"
$global:rulesresults=@()
$global:componentsresults=@()
$siteid="" # to be found in new URL of incoming webhook in Jira Automation right after https://api-private.atlassian.com/automation/webhooks/jira/a - e.g. ceeeeeee-deee-4444-8888-5555aaaa4444
function test-component($component)
{
    if ($component.type -eq "jira.issue.outgoing.webhook")
    {
        $componentsresult=$global:rulesresult | select Name,Enabled,LegacyURL,RuleUUID,Token,Trigger,ComponentCallsAutomationName,ComponentCallsURL,ComponentNewURL, ComponentNewURLSecret
        $componentsresult.ComponentCallsURL=$component.value.url
        if ($component.value.url -match "^(.*?)(\?.*)?$") {
            $SimpleURL = $matches[1]
            $SimpleParams=$component.value.url -replace $simpleurl,""
        } else {
            $SimpleURL = $component.value.url
            $SimpleParams=""
        }
        if ($simpleurl -like "https://automation.atlassian.com/pro/hooks/*") 
        { 
            $componentsresult.ComponentNewURLSecret=$SimpleURL -replace "https://automation.atlassian.com/pro/hooks/",""
            $componentsresult.LegacyURL=$true
            $componentsresult.ComponentCallsAutomationName=($global:rulesresults | where-object {$_.Token -eq $componentsresult.ComponentNewURLSecret} | select-object -first 1).name
            $componentsresult.ComponentNewURL=($global:rulesresults | where-object {$_.Token -eq $componentsresult.ComponentNewURLSecret} | select-object -first 1).NewWebhookURL
            if ($componentsresult.ComponentNewURL -ne $null -and $simpleparams -ne "") { $componentsresult.ComponentNewURL+="$($SimpleParams)" }
        } elseif ($simpleurl -like "https://api-private.atlassian.com/automation/webhooks/jira/a/*")
        {
            $componentsresult.LegacyURL=$false
            $calledautomation=$global:rulesresults | where-object {$_.NewWebhookURL -eq $simpleurl}
            $componentsresult.ComponentCallsAutomationName=$calledautomation.name
            $componentsresult.ComponentNewURL=$calledautomation.NewWebhookURL
            $componentsresult.ComponentNewURLSecret=$calledautomation.Token
        }
        $global:componentsresults+=$componentsresult
    }
    
    if ($component.children.count -gt 0)
    {
        foreach ($child in $component.children)
        {
            test-component -component $child
        }
    }
}

foreach ($rule in $rules.rules)
{
    $rulesresult="" | select Name,Enabled,RuleUUID,Token,Trigger,LegacyWebhookURL,NewWebhookURL,NewWebHookURLWithSecret
    $rulesresult.Name=$rule.name
    $rulesresult.Enabled=$rule.state -eq "ENABLED"
    $rulesresult.trigger=$rule.trigger.type
    $ruleuuid=$rule.iduuid
    $rulesresult.RuleUUID=$ruleuuid
    if ($rule.trigger.type -eq "jira.incoming.webhook" )
    {
        $webhooktoken=$rule.trigger.value.webhookToken
        $rulesresult.Token=$webhooktoken
        $rulesresult.LegacyWebhookURL="https://automation.atlassian.com/pro/hooks/$webhooktoken"
        $rulesresult.NewWebhookURL="https://api-private.atlassian.com/automation/webhooks/jira/a/$siteid/$ruleuuid"
        $rulesresult.NewWebhookURLWithSecret="https://api-private.atlassian.com/automation/webhooks/jira/a/$siteid/$ruleuuid/$webhooktoken"
        $global:rulesresults+=$rulesresult
    }
}

foreach ($rule in $rules.rules)
{
    $global:rulesresult="" | select Name,Enabled,RuleUUID,Token,Trigger,LegacyWebhookURL,NewWebhookURL,NewWebHookURLWithSecret
    $global:rulesresult.Name=$rule.name
    $global:rulesresult.Enabled=$rule.state -eq "ENABLED"
    $global:rulesresult.trigger=$rule.trigger.type
    $ruleuuid=$rule.iduuid
    $global:rulesresult.RuleUUID=$ruleuuid
    foreach ($component in $rule.components)
    {
        test-component -component $component
    }
}


$rulesresults | sort-object name | export-csv -NoTypeInformation -encoding:utf8 -path "$outputdir/incoming-webhooks.csv" -force
$componentsresults | sort-object name | export-csv -NoTypeInformation -encoding:utf8 -path "$outputdir/outgoing-webhooks.csv" -force
