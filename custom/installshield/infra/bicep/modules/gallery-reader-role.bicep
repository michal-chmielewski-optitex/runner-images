@description('Existing Azure Compute Gallery name')
param galleryName string

@description('Object ID of the DevOpsInfrastructure service principal (tenant-specific). Retrieve with: az ad sp list --filter "displayName eq \'DevOpsInfrastructure\'" --query "[0].id" -o tsv')
param devOpsInfrastructureServicePrincipalObjectId string

resource gallery 'Microsoft.Compute/galleries@2023-07-03' existing = {
  name: galleryName
}

resource galleryReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(gallery.id, devOpsInfrastructureServicePrincipalObjectId, 'Reader')
  scope: gallery
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
    principalId: devOpsInfrastructureServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = galleryReader.id
