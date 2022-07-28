# Azure Container Registry (ACR) Unhealthy Images Utilities

This repo contains tools that come in handy when dealing with unhealthy/vulnerable images in Azure Container Registry.

- [SecurityAssesment](modules/SecurityAssessment/): `PowerShell` module used as a wrapper for  REST API call on Security Assessments (Recommendations)

- [output_unhealthy_acr_images](utils/output_unhealthy_acr_images): `PowerShell` script to list unhealthy ACR images and output as JSON

- [.pipelines/acr](.pipelines/acr): `YAML` configuration for (Azure DevOps) pipelines to run the scripts
