# Output Unhealthy ACR Images

[[_TOC_]]

## Overview

This tool is used to get unhealthy/vulnerable container images from Azure Container Registry (ACR).

## Getting Started

This pipeline is to be triggered by schedule or ad-hoc.

It is defined in [output-unhealthy-acr-images.yml](/.pipelines/acr/output-unhealthy-acr-images.yml) which calls the template [stages-output-unhealthy-acr-images.yml](/.pipelines/acr/templates/stages-output-unhealthy-acr-images.yml). In the template, it calls the following PowerShell scripts:

- [output-unhealthy-acr-images.ps1](/tools/unhealthy_acr_images_deletion_tools/output-unhealthy-acr-images.ps1)

- [upload-outputs-to-storage.ps1](/tools/unhealthy_acr_images_deletion_tools/upload-outputs-to-storage.ps1)

### Input

It currently takes no input.

### Output

It outputs JSON file to the storage account with the following format:

``` json
[
  {
    "subscriptionName": "",
    "registries": [
      {
        "registryName": "",
        "repositories": [
          {
            "repositoryName": "",
            "images": [
              {
                "imageDigest": "",
                "tags": []
                "securityIssues": [
                  {
                    "securityIssueName" : "",
                    "remediationStep": ""
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
]
```

### Pipeline Run

- Run `Get-AzSubscription` to list subscriptions in relevant environment (STAGE/PROD)

- Run `Get-SecAssessment` (from [SecurityAssesment](/modules/SecurityAssessment/public/) module)
  - Invoke a REST call to get `Microsoft.Security/assessments/00000000-0000-0000-0000-000000000000/subAssessments`

- Filter necessary fields (subscriptionId, subscriptionName, registryName, repositoryName, imageDigest, securityIssueName, and remediationStep)

- Get tags for each image
  - Call `Get-AzContainerRegistryManifest`

- Convert to JSON and reformat the output

- Send the output to build artifact and then to the storage account
