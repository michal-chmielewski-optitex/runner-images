targetScope = 'resourceGroup'

@description('Azure region of the gallery and image definition')
param location string

@description('Existing gallery name')
param galleryName string = 'acg_ned_prd_mdp_001'

@description('Gallery image definition name to create or update')
param imageDefinitionName string = 'win11-vs2022-ui-x64'

@description('DevOpsInfrastructure SP object ID for gallery Reader role')
param devOpsInfrastructureServicePrincipalObjectId string

@description('Deploy gallery Reader role for DevOpsInfrastructure')
param deployGalleryReaderRole bool = true

module galleryImageDefinition 'modules/gallery-image-definition.bicep' = {
  name: 'gallery-image-definition'
  params: {
    galleryName: galleryName
    location: location
    imageDefinitionName: imageDefinitionName
    imagePublisher: 'ned'
    imageOffer: 'win11-ui-tests'
    imageSku: 'vs2022-x64'
    imageDescription: 'Windows 11 Enterprise x64 with VS 2022, NUnit, WinAppDriver for interactive UI tests'
    recommendedMemoryMinGb: 8
    recommendedMemoryMaxGb: 32
    recommendedVCpusMin: 4
    recommendedVCpusMax: 16
  }
}

module galleryReaderRole 'modules/gallery-reader-role.bicep' = if (deployGalleryReaderRole) {
  name: 'gallery-reader-role'
  params: {
    galleryName: galleryName
    devOpsInfrastructureServicePrincipalObjectId: devOpsInfrastructureServicePrincipalObjectId
  }
}

output galleryImageDefinitionId string = galleryImageDefinition.outputs.imageDefinitionId
output galleryImageVersionIdTemplate string = '${galleryImageDefinition.outputs.imageDefinitionId}/versions/{version}'
