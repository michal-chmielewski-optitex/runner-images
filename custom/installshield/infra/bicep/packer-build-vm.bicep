targetScope = 'resourceGroup'

@description('Azure region')
param location string = 'germanywestcentral'

@description('Packer build VM name')
param vmName string = 'vm-ned-prd-packer-build-001'

@description('Windows computer name (max 15 chars)')
param computerName string = 'nedprdpacker01'

@description('Existing user-assigned managed identity')
param managedIdentityName string = 'id-aib-win11-installer-gui-001'

@description('Local admin username')
param adminUsername string = 'packeradmin'

@secure()
@description('Local admin password (min. 12 chars, complexity)')
param adminPassword string

@description('Restrict RDP source IP, e.g. 1.2.3.4/32')
param allowedRdpPrefix string = '*'

module packerBuildVm 'modules/packer-build-vm.bicep' = {
  name: 'packer-build-vm-deploy'
  params: {
    location: location
    vmName: vmName
    computerName: computerName
    managedIdentityName: managedIdentityName
    adminUsername: adminUsername
    adminPassword: adminPassword
    allowedRdpPrefix: allowedRdpPrefix
  }
}

output vmName string = packerBuildVm.outputs.vmName
output publicIpAddress string = packerBuildVm.outputs.publicIpAddress
output managedIdentityClientId string = packerBuildVm.outputs.managedIdentityClientId
output rdpConnection string = packerBuildVm.outputs.rdpConnection
