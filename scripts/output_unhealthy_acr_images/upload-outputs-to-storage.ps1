<#
.SYNOPSIS
The script is used to upload JSON files to storage account

.DESCRIPTION
The script does the following:
- Get the list of files specified in Path and FileFilter parameters
- Upload each file to designated container in the storage account

.PARAMETER ResourceGroupName
The resource group where the storage account is located

.PARAMETER StorageAccountName
The destination storage account

.PARAMETER ContainerName
The destination container inside storage account

.PARAMETER FilePath
To specify path of files to be uploaded (see Get-ChildItem for references)

.PARAMETER FileFilter
To specify filter of which files to be uploaded (see Get-ChildItem for references)

.PARAMETER PrefixBlob
To add prefix to files (blob) that will be uploaded

.EXAMPLE
./upload-outputs-to-storage.ps1 -ResourceGroupName "sandbox-rg" -StorageAccountName "sasandboxsre" -ContainerName "sandbox-container"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [System.String]$ResourceGroupName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [System.String]$StorageAccountName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [System.String]$ContainerName,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [System.String]$FilePath = '.',

  [Parameter()]
  [System.String]$FileFilter,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [System.String]$PrefixBlob
)

$storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
$outputs = Get-ChildItem -Path $FilePath -Filter $FileFilter -File
foreach ($out in $outputs) 
{
    $setAzStorageBlobContentParams = @{
        Container   = $ContainerName
        File        = "$FilePath/$($out.Name)"
        Blob        = "$PrefixBlob/$($out.Name)"
        Context     = $storage.Context
    }
    Set-AzStorageBlobContent @setAzStorageBlobContentParams -Force
}