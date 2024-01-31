<#
.SYNOPSIS
	SDOP - Create Jira issue

.DESCRIPTION
	Creates a new VCDM Release Ticket or SDOP Deployment as described in https://confluence.visma.com/display/CTO/BP%3A+Software+Delivery+and+Operational+Performance+%28SDOP%29+reporting

    Output variables:
    - Octopus.Action[SDOP - Create Jira issue].Output.ReleaseTicketId
    - Octopus.Action[SDOP - Create Jira issue].Output.ReleaseTicketKey
    - Octopus.Action[SDOP - Create Jira issue].Output.ReleaseTicketDate

    Script created by Visma.net Insights (dan.catalin.stoian@visma.com)
    Updated by johan.andre@visma.com, removed downtime parameter
    2019-08-16 - andreas.kahlroth - Replaced $majorVersion.$minorVersion.$buildVersion with $releaseVersion.
    2019-08-21 - andreas.kahlroth - Placed description for releaseNotesFilter within a link.
    2020-10-26 - vytautas.bucnys - Added Jira API url usage (apijira.visma.com)
    2023-11-16 - anders.lindblad - Change from username and password to access token.
    2023-11-16 - anders.lindblad - Add boolean VCDM. If VCDM is True the Jira issue will be created in the VCDM Jira project. If not the Jira issue will be created in the SDOP Jira project.
    2023-11-29 - anders.lindblad - Changed value for description and fieldFinalReleaseNotes according to SDOP onboarding meeting with Alin Iacob.
    2023-12-07 - anders.lindblad - Removed FinalReleaseNotes according to SDOP onboarding meeting with Alin Iacob.
	2023-12-11 - anders.lindblad - Removed unused variables fieldChangesInThisVersion, majorVersion, minorVersion and buildVersion.

.PARAMETER JiraProjectKey
		The project key in JIRA

.PARAMETER AccessToken
		MANDATORY: The accesstoken for the project in Hubble
        (hubble.visma.com / Applications / #your application# / Architecture / SDOP / Generate token)

.PARAMETER ReleaseNotes
		The release notes you want, default ReleaseNotes from Octopus deploy step SDOP - Extract JIRA Issues From GitHub Commit Messages

.PARAMETER Label
		Label the release with what you want, e.g. "Feature-A"

.PARAMETER BuildInfo
		Link to the build, with info about tests

.PARAMETER Component
		MANDATORY: Should contain the name of the service, e.g. "Insights" or "Advisor"

.PARAMETER JiraServerUrl
		JIRA URL (default https://jira.visma.com)
        
.PARAMETER JiraApiServerUrl
		JIRA URL (default https://apijira.visma.com)

.PARAMETER VCDM
		If service is onboarded to VCDM a Jira issue will be created in the VCDM Jira project. If not a Jira issue will be created in the SDOP Jira project.

.EXAMPLE

    New-Issue `
         (Get-Param 'JiraProjectKey'           -Default 'CBI') `
         (Get-Param 'AccessToken'              -Default '') `
         (Get-Param 'Octopus.Environment.Name' -Default 'Production') `
         (Get-Param 'Octopus.Project.Name'     -Default '[TEST] Visma.net Insights') `
         (Get-Param 'Octopus.Release.Number'   -Default '1.0.0') `
         (Get-Param 'ReleaseNotes'             -Default '') `
         (Get-Param 'Label'                    -Default 'test') `
         (Get-Param 'Component'                -Default 'Insights') `
         (Get-Param 'BuildInfo'                -Default 'http://cbibuild:8090') `
         (Get-Param 'JiraServerUrl'            -Default 'https://jira.visma.com') `
         (Get-Param 'JiraApiServerUrl'         -Default 'https://apijira.visma.com') `
         (Get-Param 'VCDM'        			   -Default 'True')
#>

# API Doc: https://developer.atlassian.com/jiradev/api-reference/jira-rest-apis/jira-rest-api-tutorials/jira-rest-api-example-create-issue?continue=https%3A%2F%2Fdeveloper.atlassian.com%2Fjiradev%2Fapi-reference%2Fjira-rest-apis%2Fjira-rest-api-tutorials%2Fjira-rest-api-example-create-issue&application=dac#JIRARESTAPIExample-CreateIssue-Examplesofcreatinganissue
# Field Doc: https://jira.visma.com/rest/api/2/issue/createmeta?projectKeys=CBI&issuetypeNames=VCDM Release&expand=projects.issuetypes.fields
# Status/transition Doc: https://jira.visma.com/rest/api/2/issue/CBI-738/transitions?expand=transitions.fields
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($null -ne $OctopusParameters) {
        $result = $OctopusParameters[$Name]
    }

    if ($null -eq $result) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($null -ne $variable) {
            $result = $variable.Value
        }
    }

    if ($null -eq $result) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -------------------------------------------------------------------
# 
function New-Issue {
    param(
        [string]$jiraProjectKey,
        [string]$accessToken,
        [string]$environment,
        [string]$projectName,
        [string]$releaseNumber,
        [string]$releaseNotes,
        [string]$label,
        [string]$component,
        [string]$buildInfo,
        [string]$jiraServerUrl,
        [string]$jiraApiServerUrl,
        [string]$vcdm
    ) 

    # Create issue
    $projectKey = if ($vcdm -eq "True") { "VCDM" } else { "SDOP" };
    $issueType = if ($vcdm -eq "True") { "VCDM Release" } else { "SDOP Deployment" };
    Write-Host "Create $issueType"

    $fieldProductionDeploy = "customfield_16561"
    $fieldBuildInfo = "customfield_19460"

    $now = Get-Date
   
    $environment = $environment.Replace(' ','-').ToLowerInvariant()

    $uri = "$jiraApiServerUrl/rest/api/2/issue/"
    $headers = @{
    	Authorization="Bearer $accessToken"
	}    
    $body = (
        @{
            fields = @{ 
                project = @{key = $projectKey }; 
                issuetype = @{name = $issueType };
                summary = "$projectName $releaseNumber";
                description = "$releaseNotes";
                labels = @($environment, $label);
                components = @(@{name = "$component"})
                "$fieldProductionDeploy" = "$($now.ToString("yyyy-MM-dd"))";
                "$fieldBuildInfo" = "$buildInfo"
            }
        } | ConvertTo-Json -Depth 4 -Compress);
        
    Write-Host "   Uri : $uri"
    Write-Host "   Body: $body"
    Write-Host " Trying to create an issue on $uri using access token"

    try 
    {
        $response = Invoke-RestMethod -uri $uri -Headers $headers -Method POST -ContentType "application/json" -Body $body
    }
    catch 
    {
        $exceptionResponse = $_.Exception.Response

        if ($error) 
        {
            $reader = New-Object System.IO.StreamReader($exceptionResponse.GetResponseStream())
            $errorContent = $reader.ReadToEnd();        
            $errorCode = ([int]$exceptionResponse.StatusCode)
        
            Write-Host "Unable to create ticket: ($errorCode) $errorContent"
            Write-Host "Tools-Hub (PC 2023)"
            Write-Host "URI: $uri"
            Write-Host "Header: $headers"
        }

        write-host $_.Exception
    }


    # Save issue in Octopus
    if ($null -ne $OctopusParameters) {
        Set-OctopusVariable -name "ReleaseTicketId" -value $response.id
        Set-OctopusVariable -name "ReleaseTicketKey" -value $response.key
        Set-OctopusVariable -name "ReleaseTicketDate" -value $now.ToString()
    }

    return $response
}


New-Issue `
     (Get-Param 'JiraProjectKey'           -Required ) `
     (Get-Param 'AccessToken'              -Required ) `
     (Get-Param 'Octopus.Environment.Name' -Default 'Production') `
     (Get-Param 'Octopus.Project.Name'     -Default 'Octopus Deploy Template') `
     (Get-Param 'Octopus.Release.Number'   -Default '1.0.0') `
     (Get-Param 'ReleaseNotes'             -Default '') `
     (Get-Param 'Label'                    -Default '') `
     (Get-Param 'Component'                -Default '') `
     (Get-Param 'BuildInfo'                -Default '') `
     (Get-Param 'JiraServerUrl'            -Default 'https://jira.visma.com') `
     (Get-Param 'JiraApiServerUrl'         -Default 'https://apijira.visma.com') `
     (Get-Param 'VCDM'        			   -Default 'True')
