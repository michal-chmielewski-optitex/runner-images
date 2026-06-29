# Win11 x64 UI tests image — NED PRD infrastructure

Custom agent image for **interactive GUI testing** on Azure DevOps Managed DevOps Pool.

| Layer | Responsibility |
|-------|----------------|
| **VM image (this repo)** | Windows 11 Enterprise **x64**, VS 2022 (.NET desktop workload 1:1 baremetal), .NET SDK 8/9, NUnit Console, WinAppDriver, Developer Mode |
| **MDP pool** | Osobna pula `mdp-ned-prd-uittest-001` z `logonType: Interactive` |
| **Pipeline testowy** | pytest / WinAppDriver / pywinauto na agencie z `ImageOverride` |

## One-time setup

### 1. Bicep — image definition in ACG

```bash
az deployment group create \
  --resource-group rg-ned-prd-mdp-001 \
  --template-file custom/win11-ui-tests/infra/bicep/main.bicep \
  --parameters custom/win11-ui-tests/infra/parameters/ned-prd.bicepparam
```

Creates gallery image definition `win11-vs2022-ui-x64`.  
`deployGalleryReaderRole` defaults to `false` — ACG Reader for DevOpsInfrastructure was already deployed with InstallShield Bicep; packer MI has Contributor only (no `roleAssignments/write`).

### 2. Managed DevOps Pool for UI tests

Osobna pula **`mdp-ned-prd-uittest-001`** — `logonType: Interactive` dotyczy całej puli. Nie mieszaj z pulą headless `mdp-ned-prd-winbuild-001` (InstallShield).

Po pierwszym buildzie obrazu — **utwórz pulę jako użytkownik ADO** (`az login`, nie `--identity`). Managed identity wystarczy do buildu obrazu, ale rejestracja puli w ADO wymaga konta z uprawnieniami Agent pools Administrator/Creator w projekcie Optitex.

```powershell
az login
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06

$versionId = '/subscriptions/426ea593-fd6e-40a0-a314-be2b3d6a2a06/resourceGroups/rg-ned-prd-mdp-001/providers/Microsoft.Compute/galleries/acg_ned_prd_mdp_001/images/win11-vs2022-ui-x64/versions/1.0.0'

.\New-UiTestsManagedDevOpsPool-NedPrd.ps1 `
  -GalleryImageVersionResourceId $versionId
```

Tworzy pulę (klon `mdp-ned-prd-winbuild-001` + `Interactive` + tylko alias `win11-vs2022-ui-x64`).

Domyślnie `Standard_D4as_v5` / `maximumConcurrency=1` — mieści się w aktualnym MDP quota obok `winbuild` (`Standard_D8s_v5` wymaga podniesienia `standardDSv5Family` w `germanywestcentral`). Po zwiększeniu quota możesz podnieść SKU w Azure Portal lub przez REST.

```powershell
# docelowo po podniesieniu quota:
.\New-UiTestsManagedDevOpsPool-NedPrd.ps1 `
  -GalleryImageVersionResourceId $versionId `
  -SkuName 'Standard_D8s_v5' `
  -MaximumConcurrency 2
```

Jeśli przez pomyłkę zarejestrowałeś obraz na `mdp-ned-prd-winbuild-001`, usuń go:

```powershell
.\Remove-ManagedDevOpsPoolImage.ps1 `
  -ResourceGroupName 'rg-ned-prd-mdp-001' `
  -PoolName 'mdp-ned-prd-winbuild-001' `
  -ImageAlias 'win11-vs2022-ui-x64'
```

### 3. Build obrazu (na packer VM — ten sam co InstallShield)

```powershell
az login --identity --client-id f9e04a3f-0472-45cd-8b85-b4e4760f7675
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06

cd C:\Users\packeradmin\Downloads\runner-images\custom\win11-ui-tests\helpers

.\Build-Win11UiTestsImage-NedPrd.ps1 `
  -ImageVersion '1.0.0' `
  -UseManagedIdentity `
  -RestrictToAgentIpAddress
```

Build trwa ~2–3 h (VS 2022 + Win11 client sysprep).

### 4. Rejestracja na MDP (kolejne wersje obrazu)

Gdy pula już istnieje:

```powershell
.\Update-ManagedDevOpsPoolImage.ps1 `
  -ResourceGroupName 'rg-ned-prd-mdp-001' `
  -PoolName 'mdp-ned-prd-uittest-001' `
  -GalleryImageVersionResourceId $versionId
```

## Użycie w pipeline testowym

```yaml
pool:
  name: mdp-ned-prd-uittest-001
  demands:
    - ImageOverride -equals win11-vs2022-ui-x64

steps:
  - powershell: |
      Start-Process -FilePath "$env:ProgramFiles\Windows Application Driver\WinAppDriver.exe" -WindowStyle Hidden
      dotnet test --logger "console;verbosity=detailed"
    displayName: Run UI tests
```

## Co jest na obrazie

- Windows 11 Enterprise x64 (`MicrosoftWindowsDesktop:windows-11:win11-25h2-ent`)
- VS 2022 Enterprise — workload **.NET desktop development** + komponenty jak na baremetal (Copilot, Blend, Live Share, ML.NET Model Builder, EF6, .NET 8/9 runtime, .NET Framework 4.7.2–4.8.1, JIT debugger, profiling, IntelliCode)
- .NET SDK 8.0 + 9.0
- NUnit Console 3.19.2
- WinAppDriver + Developer Mode
- Git, NuGet CLI, vswhere
- Azure CLI

## Pliki

| Plik | Opis |
|------|------|
| `images/windows/templates/build.windows-11-x64-ui-tests.pkr.hcl` | Lean Packer template |
| `images/windows/toolsets/toolset-win-11-x64-ui-tests.json` | VS + .NET + NUnit toolset |
| `helpers/GenerateResourcesAndImage.ps1` | `ImageType Windows11_x64_ui_tests` |
| `helpers/New-UiTestsManagedDevOpsPool-NedPrd.ps1` | Jednorazowe utworzenie puli UI |
| `helpers/Remove-ManagedDevOpsPoolImage.ps1` | Cofnięcie rejestracji aliasu na puli |
| `context.md` | Pełny kontekst wdrożenia |

See also [custom/installshield/context.md](../installshield/context.md) for shared NED PRD infrastructure (ACG, packer VM, MI).
