using '../bicep/main.bicep'

// NED PRD — existing ACG acg_ned_prd_mdp_001 and MDP mdp-ned-prd-winbuild-001
// Deploy: az deployment group create -g rg-ned-prd-mdp-001 -f ... -p ...

param location = 'germanywestcentral'

param galleryName = 'acg_ned_prd_mdp_001'

param imageDefinitionName = 'installshield-2025-win2022'

// az ad sp list --filter "displayName eq 'DevOpsInfrastructure'" --query "[0].id" -o tsv
param devOpsInfrastructureServicePrincipalObjectId = 'afdd67ff-66a3-4ae9-810a-ba79765dff74'

param deployGalleryReaderRole = true
