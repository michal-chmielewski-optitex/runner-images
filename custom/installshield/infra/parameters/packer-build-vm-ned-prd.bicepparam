using '../bicep/packer-build-vm.bicep'

// Deploy:
//   az deployment group create -g rg-ned-prd-mdp-001 -f custom/installshield/infra/bicep/packer-build-vm.bicep -p custom/installshield/infra/parameters/packer-build-vm-ned-prd.bicepparam
//
// Password: pass at deploy time (never commit):
//   az deployment group create ... --parameters adminPassword='<SecurePassword1!>'

param location = 'germanywestcentral'

param vmName = 'vm-ned-prd-packer-build-001'

param managedIdentityName = 'id-aib-win11-installer-gui-001'

param adminUsername = 'packeradmin'

// REQUIRED — override on command line: --parameters adminPassword='...'
param adminPassword = ''

// Restrict to your IP for RDP, e.g. '185.183.225.208/32'
param allowedRdpPrefix = '*'
