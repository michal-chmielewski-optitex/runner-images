@description('Existing Azure Compute Gallery name')
param galleryName string

@description('Azure region of the gallery (required — not available from existing resource at compile time)')
param location string

@description('Image definition for Win11 x64 UI test custom image')
param imageDefinitionName string = 'win11-vs2022-ui-x64'

@description('Gallery image publisher identifier')
param imagePublisher string = 'ned'

@description('Gallery image offer identifier')
param imageOffer string = 'win11-ui-tests'

@description('Gallery image SKU identifier')
param imageSku string = 'vs2022-x64'

@description('Gallery image definition description')
param imageDescription string = 'Windows 11 Enterprise x64 with VS 2022 for interactive UI tests'

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

@description('Recommended minimum memory in GB')
param recommendedMemoryMinGb int = 8

@description('Recommended maximum memory in GB')
param recommendedMemoryMaxGb int = 32

@description('Recommended minimum vCPUs')
param recommendedVCpusMin int = 4

@description('Recommended maximum vCPUs')
param recommendedVCpusMax int = 16

resource gallery 'Microsoft.Compute/galleries@2023-07-03' existing = {
  name: galleryName
}

resource imageDefinition 'Microsoft.Compute/galleries/images@2023-07-03' = {
  parent: gallery
  name: imageDefinitionName
  location: location
  properties: {
    identifier: {
      publisher: imagePublisher
      offer: imageOffer
      sku: imageSku
    }
    description: imageDescription
    osType: osType
    osState: 'Generalized'
    hyperVGeneration: hyperVGeneration
    recommended: {
      memory: {
        min: recommendedMemoryMinGb
        max: recommendedMemoryMaxGb
      }
      vCPUs: {
        min: recommendedVCpusMin
        max: recommendedVCpusMax
      }
    }
  }
}

output imageDefinitionId string = imageDefinition.id
output imageDefinitionName string = imageDefinition.name
