<#
.SYNOPSIS
The script is used to output unhealthy Azure Container Registry (ACR) images

.DESCRIPTION
The script does the following:
- Get the list of subscriptions in given Environment parameter
- For each subscription, do the following loop
  - Get security subassessments (recommendations) to get the list of unhealthy image(s)
  - Filter fields and remove duplicates
  - Get image/tags for each unhealthy image
  - Format in JSON
  - Output to build artifact directory

.PARAMETER Environment
The environment of the subscription (e.g. "test", "stage", "prod")

.PARAMETER Region
The region where the subscription is located (example: "japaneast")

.EXAMPLE
./output-unhealthy-acr-images.ps1 -Environment "stage" -Region "japaneast"

.NOTES
1) The script is not designed to be invoked manually, use Azure Pipeline
2) The script only works on Ubuntu-based agents 
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [System.String[]]$Environment,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [System.String]$Region
)

$null = apt-get install -y jq
Install-Module -Name Az.ResourceGraph -Force
(Get-ChildItem -Path ./modules/SreSecurityAssessment/ -Recurse -Filter *.ps1).ForEach{. $_.FullName}
$InformationPreference = "Continue"

Write-Information -MessageData "Getting subscription list..."
$subsList = Get-AzSubscription | 
                Where-Object {
                    ($_.Name.Split("-")[2] -in $Environment) -and 
                    ($_.Name.Split("-")[3] -in $Region) -and
                    ($_.State -eq "Enabled")
                } |
                Select-Object -Property Id, Name

foreach ($sub in $subsList)
{

    Write-Host -Object ""
    Write-Information -MessageData "Getting unhealthy containers assessments... (subscription: $($sub.Name))"
    $getSecAssessmentParams = @{
        SubscriptionId  = $sub.Id
        ResourceType    = "Microsoft.ContainerRegistry/registries"
        AssessmentId    = "dbd0cb49-b563-45e7-9724-889e799fa648" #Container registry images should have vulnerability findings resolved
        Status          = "Unhealthy"
    }
    $query = Get-SecAssessment @getSecAssessmentParams -SubAssessment
    if ($null -eq $query) {
        Write-Information -MessageData "No security assessments found in this subscription"
        continue
    }


    Write-Information -MessageData "Filtering necessary fields (subscription: $($sub.Name))"
    $queryFields = $query | ForEach-Object {
        return [PSCustomObject]@{
            subscriptionId      = $sub.Id
            subscriptionName    = $sub.Name
            registryName        = $_.properties.additionalData.registryHost.Split(".")[0]
            repositoryName      = $_.properties.additionalData.repositoryName
            imageDigest         = $_.properties.additionalData.imageDigest
            securityIssueName   = $_.properties.displayName
            remediationStep     = $_.properties.remediation  
        }
    }

    Write-Information -MessageData "Getting image tags/versions... (subscription: $($sub.Name))"
    $imageDigestTagsMap = @{}
    $cnt = 0
    $total = ($queryFields | Sort-Object -Property imageDigest -Unique).count
    $queryFields | ForEach-Object { 
        if ($imageDigestTagsMap.ContainsKey($_.imageDigest)) {
            $tags = $imageDigestTagsMap[$_.imageDigest]
        } else {
            $cnt++
            Write-Information -MessageData "Processing $cnt/$total images... (subscription: $($sub.Name))"
            $getAzContainerRegistryManifestParams = @{
                RegistryName        = $_.registryName
                RepositoryName      = $_.repositoryName
                Name                = $_.imageDigest
            }
            $tags                   = Get-AzContainerRegistryManifest @getAzContainerRegistryManifestParams |
                                        Select-Object -Expand Attributes | 
                                        Select-Object -Expand Tags
            $imageDigestTagsMap[$_.imageDigest] = $tags
        }
        Add-Member -InputObject $_ -NotePropertyName "tags" -NotePropertyValue $tags
    }
    

    Write-Information -MessageData "Converting to JSON and reformatting... (subscription: $($sub.Name))"
    $queryJson = $queryFields | ConvertTo-Json 
    if ($total -eq 1) {$queryJson = $queryJson | jq -s "."}
    $queryJson = $queryJson | jq "group_by(.subscriptionName) | map({
                        subscriptionId: .[0].subscriptionId, 
                        subscriptionName: .[0].subscriptionName, 
                        registries: group_by(.registryName) | map({
                            registryName: .[0].registryName, 
                            repositories: group_by(.repositoryName) | map({
                                repositoryName: .[0].repositoryName, 
                                images: group_by(.imageDigest) | map({
                                    imageDigest: .[0].imageDigest, 
                                    tags:.[0].tags,
                                    securityIssues: group_by(.securityIssueName) | map ({
                                        securityIssueName: .[0].securityIssueName,
                                        remediationStep: .[0].remediationStep
                                    })
                                })
                            })
                        })
                    })"
    $queryJson


    Write-Information -MessageData "Outputting to artifact directory...  (subscription: $($sub.Name))"
    $output = "unhealthy_images_$($sub.Name)_$($Env:BUILD_BUILDNUMBER).json"
    $queryJson | Out-File -FilePath $Env:BUILD_ARTIFACTSTAGINGDIRECTORY/$output
    
}