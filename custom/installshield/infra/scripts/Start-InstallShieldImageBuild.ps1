################################################################################
##  Run on packer build VM after RDP — clone repo and start image build
################################################################################

$ErrorActionPreference = 'Stop'

# 1. Azure auth via user-assigned MI (already on this VM)
$miClientId = 'f9e04a3f-0472-45cd-8b85-b4e4760f7675'
az login --identity --client-id $miClientId
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06

# 2. Clone runner-images (adjust URL/branch)
$repoPath = 'C:\packer-build\runner-images'
if (-not (Test-Path $repoPath)) {
    git clone https://dev.azure.com/<org>/<project>/_git/runner-images $repoPath
    # or: git clone https://github.com/<fork>/runner-images $repoPath
}
Set-Location $repoPath

# 3. InstallShield SAB installer SAS (set before run — do not commit)
$env:INSTALLSHIELD_INSTALLER_URL = '<SAS URL to InstallShield2025R2StandaloneBuild.exe>'

# 4. Build + publish to ACG
& .\custom\installshield\helpers\Build-InstallShieldImage-NedPrd.ps1 `
    -ImageVersion '1.0.0' `
    -UseManagedIdentity `
    -RestrictToAgentIpAddress

# 5. Register on MDP
& .\custom\installshield\helpers\Update-ManagedDevOpsPoolImage.ps1 `
    -ResourceGroupName 'rg-ned-prd-mdp-001' `
    -PoolName 'mdp-ned-prd-winbuild-001' `
    -GalleryImageVersionResourceId '/subscriptions/426ea593-fd6e-40a0-a314-be2b3d6a2a06/resourceGroups/rg-ned-prd-mdp-001/providers/Microsoft.Compute/galleries/acg_ned_prd_mdp_001/images/installshield-2025-win2022/versions/1.0.0'
