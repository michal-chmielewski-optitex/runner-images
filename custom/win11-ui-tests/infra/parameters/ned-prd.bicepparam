using '../bicep/main.bicep'

param location = 'germanywestcentral'

param galleryName = 'acg_ned_prd_mdp_001'

param imageDefinitionName = 'win11-vs2022-ui-x64'

param devOpsInfrastructureServicePrincipalObjectId = 'afdd67ff-66a3-4ae9-810a-ba79765dff74'

// Reader on ACG was already deployed with installshield infra; MI has Contributor, not User Access Administrator.
param deployGalleryReaderRole = false
