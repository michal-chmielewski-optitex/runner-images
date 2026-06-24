# Windows 11 x64 UI tests image

Custom NED PRD image: **Windows 11 Enterprise x64** + **VS 2022 Enterprise** (`.NET desktop development`, baremetal-matched components) + **.NET SDK 8/9** + **NUnit Console** + **WinAppDriver**.

Designed for **Managed DevOps Pools** with `logonType: Interactive`.

## Build

See [custom/win11-ui-tests/README.md](../custom/win11-ui-tests/README.md) and [custom/win11-ui-tests/context.md](../custom/win11-ui-tests/context.md).

```powershell
Import-Module .\helpers\GenerateResourcesAndImage.ps1

$env:GALLERY_NAME = 'acg_ned_prd_mdp_001'
$env:GALLERY_RG_NAME = 'rg-ned-prd-mdp-001'
$env:GALLERY_IMAGE_NAME = 'win11-vs2022-ui-x64'
$env:GALLERY_IMAGE_VERSION = '1.0.0'
$env:BUILD_RG_NAME = 'rg-ned-prd-mdp-001'

GenerateResourcesAndImage `
  -SubscriptionId "426ea593-fd6e-40a0-a314-be2b3d6a2a06" `
  -ResourceGroupName "rg-ned-prd-mdp-001" `
  -ImageType Windows11_x64_ui_tests `
  -AzureLocation "germanywestcentral" `
  -ManagedImageName "win11-vs2022-ui-x64-1.0.0" `
  -UseAzureCliAuth
```

## Pipeline usage

```yaml
pool:
  name: mdp-ned-prd-uittest-001
  demands:
    - ImageOverride -equals win11-vs2022-ui-x64
```

## Files

| File | Purpose |
|------|---------|
| `images/windows/templates/build.windows-11-x64-ui-tests.pkr.hcl` | Packer template |
| `images/windows/toolsets/toolset-win-11-x64-ui-tests.json` | VS / .NET / NUnit toolset |
| `images/windows/scripts/build/Install-VisualStudio-UiTests.ps1` | Slim VS 2022 install |
| `images/windows/scripts/build/Install-NUnit.ps1` | NUnit Console install |
