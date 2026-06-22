# Windows 2022 + InstallShield SAB

Custom agent image = **full Microsoft `windows-2022`** (VS 2022 Enterprise + complete toolset) + **InstallShield 2025 Standalone Build** pre-installed.

Everything else — license (CLS), `ISCmdBld` builds, project parameters — is handled in the Azure DevOps pipeline using the official [InstallShield Azure DevOps Build Extension](https://community.revenera.com/s/article/installshield-azure-devops-build-extension) ([Marketplace](https://marketplace.visualstudio.com/items?itemName=Revenera.InstallShieldBuild)).

## Division of responsibility

| Layer | Responsibility |
|-------|----------------|
| **VM image (this repo)** | Full `windows-2022` stack + InstallShield SAB (`ISCmdBld.exe` on PATH) |
| **ADO pipeline (extension)** | CLS / license server config, build `.ism` releases, command-line params |

The extension's `InstallShieldBuild@1` task detects SAB on a private agent and skips re-installation; it configures licensing and runs the build.

## Build the image

### Option A — lokalnie (z Twojej maszyny / build VM)

```powershell
# 1. Narzędzia
choco install packer git -y
packer plugins install github.com/hashicorp/azure 2.2.1
az login
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06

# 2. Źródło instalatora SAB (jedno z)
$env:INSTALLSHIELD_INSTALLER_URL = "https://<storage>.blob.core.windows.net/installshield-artifacts/InstallShield2025StandaloneBuild.exe?<SAS>"
# lub: $env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT = "<storage-account>"

# 3. Build (~2–4 h) + publikacja do ACG
cd custom\installshield\helpers
.\Build-InstallShieldImage-NedPrd.ps1 -ImageVersion "1.0.0" -RestrictToAgentIpAddress

# 4. Rejestracja w MDP
.\Update-ManagedDevOpsPoolImage.ps1 `
  -ResourceGroupName 'rg-ned-prd-mdp-001' `
  -PoolName 'mdp-ned-prd-winbuild-001' `
  -GalleryImageVersionResourceId '/subscriptions/426ea593-fd6e-40a0-a314-be2b3d6a2a06/resourceGroups/rg-ned-prd-mdp-001/providers/Microsoft.Compute/galleries/acg_ned_prd_mdp_001/images/installshield-2025-win2022/versions/1.0.0'
```

### Option B — pipeline ADO

1. Variable group z `pipelines/variable-group-installshield-image-build.env.example`
2. Zaimportuj `pipelines/build-image-ned-prd.yml`
3. Ustaw self-hosted pool z Packerem
4. Run z `imageVersion: 1.0.0`

### Ręcznie (bez helpera)

```powershell
Import-Module .\helpers\GenerateResourcesAndImage.ps1

$env:GALLERY_NAME = 'acg_ned_prd_mdp_001'
$env:GALLERY_RG_NAME = 'rg-ned-prd-mdp-001'
$env:GALLERY_IMAGE_NAME = 'installshield-2025-win2022'
$env:GALLERY_IMAGE_VERSION = '1.0.0'
$env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT = '<storage-account>'

GenerateResourcesAndImage `
    -SubscriptionId "426ea593-fd6e-40a0-a314-be2b3d6a2a06" `
    -ResourceGroupName "rg-ned-prd-mdp-001" `
    -ImageType Windows2022InstallShield `
    -AzureLocation "germanywestcentral" `
    -ManagedImageName "installshield-win2022-1.0.0"
```

### Azure Compute Gallery env vars (Packer)

```powershell
$env:GALLERY_NAME = "yourGallery"
$env:GALLERY_RG_NAME = "rg-gallery"
$env:GALLERY_IMAGE_NAME = "installshield-2025-win2022"
$env:GALLERY_IMAGE_VERSION = "1.0.0"
```

## Pipeline example (private agent / MDOP)

Install the extension in your Azure DevOps organization, then:

```yaml
pool:
  name: installshield-pool   # MDOP with gallery image installshield-2025-win2022

steps:
- task: InstallShieldBuild@1
  displayName: Build installer
  inputs:
    ProjectPath: 'src/MyProject.ism'
    ReleaseName: 'SingleExe'
    AgentLocation: 'Private Agent'
    LicType: 'Cloud'                    # CLS
    ISLicenseServerCLSId: '$(ClsId)'    # from variable group / Key Vault
    ISVersion: '2025'
    CmdLineParams: '-s'
```

See Revenera docs for all task inputs: [InstallShield Azure DevOps Build Extension](https://community.revenera.com/s/article/installshield-azure-devops-build-extension).

## What is NOT baked into the image

- Azure DevOps PAT, passwords, PFX, pipeline secrets
- Registered Azure DevOps agent
- InstallShield CLS ID / license server configuration

## Files

| File | Purpose |
|------|---------|
| `images/windows/templates/build.windows-2022-installshield.pkr.hcl` | Full win2022 + SAB provisioner |
| `images/windows/scripts/build/Install-InstallShield.ps1` | Silent SAB install during image bake |
| `images/windows/scripts/tests/InstallShield.Tests.ps1` | Pester: `ISCmdBld.exe` present on PATH |

## NED PRD deployment (existing ACG + MDP)

Infrastructure and pipeline for `acg_ned_prd_mdp_001` and `mdp-ned-prd-winbuild-001`:

- [custom/installshield/README.md](../custom/installshield/README.md)
- Pipeline: `custom/installshield/pipelines/build-image-ned-prd.yml`
