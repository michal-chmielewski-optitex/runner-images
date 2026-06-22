targetScope = 'resourceGroup'

@description('Azure region of the gallery and image definition')
param location string

@description('Existing gallery name')
param galleryName string = 'acg_ned_prd_mdp_001'

@description('Gallery image definition name to create or update')
param imageDefinitionName string = 'installshield-2025-win2022'

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
