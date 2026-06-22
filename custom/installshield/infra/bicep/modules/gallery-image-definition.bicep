@description('Existing Azure Compute Gallery name')
param galleryName string

@description('Azure region of the gallery (required — not available from existing resource at compile time)')
param location string

@description('Image definition for InstallShield win2022 custom image')
param imageDefinitionName string = 'installshield-2025-win2022'

@description('OS type')
@allowed([
  'Windows'
  'Linux'
])
param osType string = 'Windows'

@description('Hyper-V generation')
@allowed([
  'V1'
  'V2'
])
param hyperVGeneration string = 'V2'

resource gallery 'Microsoft.Compute/galleries@2023-07-03' existing = {
  name: galleryName
}

resource imageDefinition 'Microsoft.Compute/galleries/images@2023-07-03' = {
  parent: gallery
  name: imageDefinitionName
  location: location
  properties: {
    identifier: {
      publisher: 'ned'
      offer: 'installshield'
      sku: 'win2022-sab'
    }
    osType: osType
    osState: 'Generalized'
    hyperVGeneration: hyperVGeneration
    recommended: {
      memory: {
        min: 8
        max: 32
      }
      vCPUs: {
        min: 4
        max: 16
      }
    }
  }
}

output imageDefinitionId string = imageDefinition.id
output imageDefinitionName string = imageDefinition.name
