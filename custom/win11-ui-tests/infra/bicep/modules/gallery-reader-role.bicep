@description('Existing Azure Compute Gallery name')
param galleryName string

@description('DevOpsInfrastructure service principal object ID')
param devOpsInfrastructureServicePrincipalObjectId string

resource gallery 'Microsoft.Compute/galleries@2023-07-03' existing = {
  name: galleryName
}

resource galleryReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(gallery.id, devOpsInfrastructureServicePrincipalObjectId, 'Reader')
  scope: gallery
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
    principalId: devOpsInfrastructureServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = galleryReaderRole.id
