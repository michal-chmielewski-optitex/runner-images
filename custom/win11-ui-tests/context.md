# Context — Windows 11 x64 UI tests image (NED PRD)

Dokument kontekstowy — wzorowany na [installshield/context.md](../installshield/context.md).

---

## Cel projektu

Obraz VM **Windows 11 Enterprise x64** z **VS 2022** (buildtoolset 1:1 jak baremetal) dla **interaktywnych testów GUI** na MDP.

| Warstwa | Odpowiedzialność |
|---------|------------------|
| **Obraz VM** | Win11 x64 + VS 2022 + .NET 8/9 + NUnit + WinAppDriver |
| **MDP pool** | Osobna pula `mdp-ned-prd-uittest-001` z `logonType: Interactive` |
| **Pipeline** | Testy UI (pytest, WinAppDriver, pywinauto) |

**Nie bake’ujemy:** PAT, agent ADO, sekrety testów.

---

## Środowisko NED PRD

| Zasób | Wartość |
|-------|---------|
| Subscription | `426ea593-fd6e-40a0-a314-be2b3d6a2a06` |
| Region | `germanywestcentral` |
| Resource group | `rg-ned-prd-mdp-001` |
| Azure Compute Gallery | `acg_ned_prd_mdp_001` |
| Gallery image definition | `win11-vs2022-ui-x64` |
| Image alias na MDP | `win11-vs2022-ui-x64` |
| MDP pool (UI tests) | `mdp-ned-prd-uittest-001` |
| Packer build VM | `vm-ned-prd-packer-build-001` (współdzielona z InstallShield) |
| MI | `id-aib-win11-installer-gui-001` |

---

## Architektura plików

```
images/windows/
  templates/build.windows-11-x64-ui-tests.pkr.hcl
  toolsets/toolset-win-11-x64-ui-tests.json
  scripts/build/Install-VisualStudio-UiTests.ps1
  scripts/build/Install-NUnit.ps1
  scripts/tests/NUnit.Tests.ps1

helpers/
  GenerateResourcesAndImage.ps1          # ImageType Windows11_x64_ui_tests

custom/win11-ui-tests/
  helpers/Build-Win11UiTestsImage-NedPrd.ps1
  helpers/Update-ManagedDevOpsPoolImage.ps1
  helpers/Set-ManagedDevOpsPoolInteractiveMode.ps1
  infra/bicep/
  pipelines/build-image-ned-prd.yml
  README.md
  context.md
```

---

## VS 2022 — mapowanie baremetal → toolset

Workload: `Microsoft.VisualStudio.Workload.ManagedDesktop` (bez `--allWorkloads`).

Dodatkowe komponenty (optional z instalatora, `VS_INSTALL_EXACT_COMPONENTS=true`):

| Baremetal (screen) | Component ID |
|--------------------|--------------|
| .NET Framework 4.8 dev tools | `Microsoft.Net.ComponentGroup.4.8.DeveloperTools` |
| .NET Framework 4.8.1 dev tools | `Microsoft.Net.ComponentGroup.4.8.1.DeveloperTools` |
| Development tools for .NET | `Microsoft.NetCore.Component.DevelopmentTools` |
| Entity Framework 6 | `Microsoft.VisualStudio.Component.EntityFramework` |
| .NET profiling tools | `Microsoft.VisualStudio.Component.DiagnosticTools` |
| IntelliCode | `Microsoft.VisualStudio.Component.IntelliCode` |
| Just-In-Time debugger | `Microsoft.VisualStudio.Component.Debugger.JustInTime` |
| ML.NET Model Builder | `Microsoft.VisualStudio.Component.DotNetModelBuilder` |
| GitHub Copilot | `Component.VisualStudio.GitHub.Copilot` |
| Copilot app modernization | `ComponentGroup.Microsoft.NET.AppModernization` |
| Blend | `Microsoft.ComponentGroup.Blend` |
| Live Share | `Component.Microsoft.VisualStudio.LiveShare.2022` |
| .NET Framework 4.8 targeting pack | `Microsoft.Net.Component.4.8.TargetingPack` |
| .NET Framework 4.8.1 SDK + targeting | `Microsoft.Net.Component.4.8.1.SDK`, `.TargetingPack` |

Wymagane przez workload (instalowane automatycznie): .NET 8/9 runtime, .NET SDK, MSBuild, NuGet, Roslyn, Text Template, 4.7.2/4.8 SDK.

---

## Ręczny build (packer VM)

```powershell
az vm start -g rg-ned-prd-mdp-001 -n vm-ned-prd-packer-build-001

az login --identity --client-id f9e04a3f-0472-45cd-8b85-b4e4760f7675
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06

cd C:\Users\packeradmin\Downloads\runner-images
git pull

cd custom\win11-ui-tests\helpers
.\Build-Win11UiTestsImage-NedPrd.ps1 -ImageVersion '1.0.0' -UseManagedIdentity -RestrictToAgentIpAddress
```

Po buildzie (pierwszy raz — utwórz pulę jako użytkownik ADO, `az login` bez `--identity`):

```powershell
az login
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06

$versionId = '/subscriptions/426ea593-fd6e-40a0-a314-be2b3d6a2a06/resourceGroups/rg-ned-prd-mdp-001/providers/Microsoft.Compute/galleries/acg_ned_prd_mdp_001/images/win11-vs2022-ui-x64/versions/1.0.0'

# Cofnij jeśli alias trafił na winbuild:
.\Remove-ManagedDevOpsPoolImage.ps1 `
  -ResourceGroupName 'rg-ned-prd-mdp-001' `
  -PoolName 'mdp-ned-prd-winbuild-001' `
  -ImageAlias 'win11-vs2022-ui-x64'

.\New-UiTestsManagedDevOpsPool-NedPrd.ps1 `
  -GalleryImageVersionResourceId $versionId
```

Kolejne wersje obrazu:

```powershell
.\Update-ManagedDevOpsPoolImage.ps1 `
  -ResourceGroupName 'rg-ned-prd-mdp-001' `
  -PoolName 'mdp-ned-prd-uittest-001' `
  -GalleryImageVersionResourceId $versionId
```

---

## Wymagania Azure

- Subskrypcja z uprawnieniem do **Windows 11 client images** (Visual Studio subscription / Dev/Test).
- Marketplace SKU: `MicrosoftWindowsDesktop:windows-11:win11-25h2-ent`.
- VM build: min. `Standard_D8s_v5`, dysk 256 GB.

---

## Uwagi

- **Osobna pula MDP** — `mdp-ned-prd-uittest-001` z `Interactive`; nie rejestruj `win11-vs2022-ui-x64` na `mdp-ned-prd-winbuild-001` (InstallShield headless).
- **Copilot** jest zainstalowany jako komponent VS; aktywacja w runtime wymaga konta GitHub (poza scope obrazu).
- **ARM64** — ten obraz jest wyłącznie x64.

---

## Powiązane

- [README.md](./README.md)
- [installshield/context.md](../installshield/context.md)
- [Microsoft: MDP interactive mode](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-security?view=azure-devops)
