# Context — InstallShield Windows 2022 image (NED PRD)

Dokument kontekstowy dla kolejnych wątków/czatów. Opisuje cały proces: infrastrukturę, **ręczny build Packer na VM**, rejestrację na MDP i użycie w pipeline.

---

## Cel projektu

Własny obraz VM dla **Azure DevOps Managed DevOps Pool (MDP)** na bazie publicznego `actions/runner-images` **Windows Server 2022** (pełny stack + VS 2022 Enterprise) z doinstalowanym **InstallShield 2025 Standalone Build (SAB)**.

| Warstwa | Odpowiedzialność |
|---------|------------------|
| **Obraz VM (repo)** | Pełny win2022 + InstallShield SAB (`ISCmdBld.exe`) |
| **Pipeline ADO (extension Revenera)** | CLS, licencja, build `.ism` przez `InstallShieldBuild@1` |

**Nie bake’ujemy do obrazu:** PAT, hasła, PFX, CLS ID, zarejestrowany agent ADO.

---

## Środowisko NED PRD (konkretne nazwy)

| Zasób | Wartość |
|-------|---------|
| Subscription | `426ea593-fd6e-40a0-a314-be2b3d6a2a06` |
| Region | `germanywestcentral` |
| Resource group | `rg-ned-prd-mdp-001` |
| Azure Compute Gallery | `acg_ned_prd_mdp_001` |
| Gallery image definition | `installshield-2025-win2022` |
| Gallery image version (pierwszy build) | `1.0.0` |
| Managed DevOps Pool | `mdp-ned-prd-winbuild-001` |
| Image alias na MDP | `installshield-2025` |
| User-assigned MI | `id-aib-win11-installer-gui-001` |
| MI client ID | `f9e04a3f-0472-45cd-8b85-b4e4760f7675` |
| MI rola | Contributor na `rg-ned-prd-mdp-001` |
| DevOpsInfrastructure SP object ID | `afdd67ff-66a3-4ae9-810a-ba79765dff74` (Reader na galerii) |
| Packer build VM | `vm-ned-prd-packer-build-001` |
| VM login | `packeradmin` |
| VM computer name (wewn.) | `nedprdpacker01` (max 15 znaków) |

### Git

| | |
|-|-|
| Repo | `git@github-optitex:michal-chmielewski-optitex/runner-images.git` |
| Branch | `installshield-2025-win2022` |
| Ostatni znany commit (po fixach MDP/REST) | `cd8355b4` |

Na VM repo było sklonowane do: `C:\Users\packeradmin\Downloads\runner-images`

---

## Architektura plików w repo

```
images/windows/
  templates/build.windows-2022-installshield.pkr.hcl   # Packer: pełny win2022 + SAB
  scripts/build/Install-InstallShield.ps1             # silent SAB install
  scripts/tests/InstallShield.Tests.ps1
  toolsets/toolset-2022.json                          # sekcja installshield

helpers/
  GenerateResourcesAndImage.ps1                         # ImageType Windows2022InstallShield

custom/installshield/
  helpers/
    Build-InstallShieldImage-NedPrd.ps1                 # wrapper NED PRD
    Update-ManagedDevOpsPoolImage.ps1                   # rejestracja na MDP (az rest)
  infra/bicep/                                          # ACG definition, packer VM
  infra/parameters/ned-prd.bicepparam
  infra/parameters/packer-build-vm-ned-prd.bicepparam
  pipelines/build-image-ned-prd.yml                     # opcjonalny pipeline ADO
  README.md
  context.md                                            # ten plik
```

---

## Co jest na obrazie / czego nie ma

### Jest
- Windows Server 2022 **Datacenter-g2** (Desktop Experience — **ma GUI OS**, ale agent CI działa headless)
- Pełny toolset `runner-images` win2022 (VS 2022 Enterprise, WinAppDriver, Selenium, …)
- **InstallShield 2025 SAB** — tylko `ISCmdBld.exe`, **bez IDE InstallShield**
- Installer: `InstallShield2025R2StandaloneBuild.exe`

### Nie ma / nie nadaje się do
- InstallShield IDE (edycja `.ism` na agencie)
- Testów z interakcją myszką na MDP (brak interaktywnej sesji pulpitu w standardowym jobie)
- Licencji CLS — konfiguruje extension w pipeline

### Uwaga: `azure-arm` w logach Packera
`windows-2022-installshield.azure-arm.image` — **ARM = Azure Resource Manager**, nie architektura ARM64. Obraz jest x64.

---

## Jednorazowa infrastruktura (Bicep)

### 1. Definicja obrazu w ACG + Reader dla DevOpsInfrastructure

```bash
az deployment group create \
  --resource-group rg-ned-prd-mdp-001 \
  --template-file custom/installshield/infra/bicep/main.bicep \
  --parameters custom/installshield/infra/parameters/ned-prd.bicepparam
```

Tworzy `installshield-2025-win2022` w galerii + rolę Reader dla SP `DevOpsInfrastructure`.

### 2. VM do buildów Packer (opcjonalna, używana przy pierwszym buildzie)

```bash
az deployment group create \
  --resource-group rg-ned-prd-mdp-001 \
  --template-file custom/installshield/infra/bicep/packer-build-vm.bicep \
  --parameters custom/installshield/infra/parameters/packer-build-vm-ned-prd.bicepparam \
  --parameters adminPassword='<SecurePassword1!>' allowedRdpPrefix='YOUR_IP/32'
```

VM ma podpięte MI `id-aib-win11-installer-gui-001`, instaluje Git / Azure CLI / Packer przez extension.

**Stan po pierwszym buildzie:** VM **deallocated** (`az vm deallocate`) — compute nie kosztuje; dysk OS nadal tak.

---

## Ręczny build obrazu na VM Packer (wykonany proces)

Poniżej pełna ścieżka użyta w produkcji (czerwiec 2026).

### Krok 0 — Włącz VM (jeśli deallocated)

```powershell
az vm start -g rg-ned-prd-mdp-001 -n vm-ned-prd-packer-build-001
# RDP na public IP VM
```

### Krok 1 — Azure CLI przez managed identity

```powershell
az login --identity --client-id f9e04a3f-0472-45cd-8b85-b4e4760f7675
az account set --subscription 426ea593-fd6e-40a0-a314-be2b3d6a2a06
```

> **Ważne:** używaj `--client-id`, nie deprecated `--username`.

### Krok 2 — Repo aktualne

```powershell
cd C:\Users\packeradmin\Downloads\runner-images
git fetch origin
git checkout installshield-2025-win2022
git pull
```

Branch musi zawierać fixy:
- `build_resource_group_name` przy `-UseManagedIdentity` (MI ma Contributor tylko na RG, nie na subskrypcję)
- brak `location` gdy podany `build_resource_group_name` (wymóg Packera)
- `az login --identity --client-id`
- `Update-ManagedDevOpsPoolImage.ps1` przez `az rest` api-version `2025-09-20`

### Krok 3 — Źródło instalatora SAB (jedno z)

```powershell
# Opcja A — SAS URL (używane przy pierwszym buildzie)
$env:INSTALLSHIELD_INSTALLER_URL = 'https://ciartifactssa7svgau.blob.core.windows.net/repoaddons/InstallShield2025R2StandaloneBuild.exe?<SAS>'

# Opcja B — lokalna ścieżka
# $env:INSTALLSHIELD_INSTALLER_PATH = 'C:\path\InstallShield2025R2StandaloneBuild.exe'

# Opcja C — blob + MI (az login)
# $env:INSTALLSHIELD_ARTIFACTS_STORAGE_ACCOUNT = '<storage-account>'
```

SAS wygasa — przed każdym buildem sprawdź ważność tokenu.

### Krok 4 — Uruchom build (~2–4 h)

```powershell
cd custom\installshield\helpers

.\Build-InstallShieldImage-NedPrd.ps1 `
  -ImageVersion '1.0.0' `
  -UseManagedIdentity `
  -RestrictToAgentIpAddress
```

**Co robi skrypt:**
1. Ustawia `GALLERY_*`, `BUILD_RG_NAME`
2. Woła `GenerateResourcesAndImage -ImageType Windows2022InstallShield`
3. Packer: `use_azure_cli_auth=true`, `build_resource_group_name=rg-ned-prd-mdp-001` (bez tworzenia `pkr-Resource-Group-*` na poziomie subskrypcji)
4. Provisionuje pełny win2022 + `Install-InstallShield.ps1`
5. Publikuje do ACG jako wersja `1.0.0`

**Oczekiwany sukces (fragment outputu):**

```
ManagedImageName: installshield-win2022-1.0.0
ManagedImageSharedImageGalleryId: .../galleries/acg_ned_prd_mdp_001/images/installshield-2025-win2022/versions/1.0.0
=== Build complete ===
```

### Krok 5 — Rejestracja wersji na MDP

```powershell
cd C:\Users\packeradmin\Downloads\runner-images\custom\installshield\helpers
git pull   # skrypt z az rest + quoted URL

.\Update-ManagedDevOpsPoolImage.ps1 `
  -ResourceGroupName 'rg-ned-prd-mdp-001' `
  -PoolName 'mdp-ned-prd-winbuild-001' `
  -GalleryImageVersionResourceId '/subscriptions/426ea593-fd6e-40a0-a314-be2b3d6a2a06/resourceGroups/rg-ned-prd-mdp-001/providers/Microsoft.Compute/galleries/acg_ned_prd_mdp_001/images/installshield-2025-win2022/versions/1.0.0'
```

Dodaje alias `installshield-2025` **obok** istniejącego `windows-2022-g2` (nie zastępuje domyślnego obrazu poolu).

**Weryfikacja:**

```powershell
$url = 'https://management.azure.com/subscriptions/426ea593-fd6e-40a0-a314-be2b3d6a2a06/resourceGroups/rg-ned-prd-mdp-001/providers/Microsoft.DevOpsInfrastructure/pools/mdp-ned-prd-winbuild-001?api-version=2025-09-20'

az rest --method get --url $url --query "properties.fabricProfile.images" -o json
```

Oczekiwany wynik: wpisy z aliasami `windows-2022-g2` i `installshield-2025`.

### Krok 6 — Wyłącz VM (oszczędność kosztów)

```powershell
az vm deallocate --resource-group rg-ned-prd-mdp-001 --name vm-ned-prd-packer-build-001
```

Managed image pośredni `installshield-win2022-1.0.0` w RG można opcjonalnie usunąć — MDP korzysta z wersji w ACG.

---

## Znane problemy i fixy (historia)

| Problem | Przyczyna | Rozwiązanie |
|---------|-----------|-------------|
| `AuthorizationFailed` na `pkr-Resource-Group-*` | Packer tworzył losową RG na subskrypcji; MI ma Contributor tylko na RG | `-var=build_resource_group_name=rg-ned-prd-mdp-001` przy `UseAzureCliAuth` |
| `Specify either location or build_resource_group_name, not both` | Packer nie akceptuje obu | Przy MI: tylko `build_resource_group_name`, bez `location` |
| `az login --identity --username` deprecated | Stare API CLI | `--client-id` w skryptach |
| `az mdp pool show` — `HttpResponsePayloadAPISpecValidationFailed` / `subnetId` | Bug extension `mdp` (API 2024-10-19 vs 2025-09-20) | `Update-ManagedDevOpsPoolImage.ps1` używa `az rest` z `api-version=2025-09-20` |
| `MissingApiVersionParameter` w skrypcie MDP | PowerShell obcina URL przy `?` | `--url "$poolUri"` w cudzysłowie |
| Wiszący `az mdp` / preview extension | Dynamiczna instalacja extension | `az extension add --name mdp --upgrade --yes` lub REST (obecny skrypt) |

Osierocona RG z nieudanej próby (opcjonalne usunięcie, wymaga uprawnień subskrypcyjnych):

```powershell
az group delete --name pkr-Resource-Group-wyi773yy88 --yes --no-wait
```

---

## Użycie obrazu w pipeline aplikacji

```yaml
pool:
  name: mdp-ned-prd-winbuild-001
  demands:
    - ImageOverride -equals installshield-2025

steps:
  - task: InstallShieldBuild@1
    displayName: Build installer
    inputs:
      ProjectPath: 'src/MyProject.ism'
      ReleaseName: 'SingleExe'
      AgentLocation: 'Private Agent'
      LicType: 'Cloud'
      ISLicenseServerCLSId: '$(ClsId)'   # variable group / Key Vault
      ISVersion: '2025'
```

Extension: [Revenera InstallShield Azure DevOps Build Extension](https://community.revenera.com/s/article/installshield-azure-devops-build-extension)

---

## Alternatywa: pipeline ADO do buildu obrazu

Plik: `custom/installshield/pipelines/build-image-ned-prd.yml`

- Variable group: `installshield-image-build` (szablon: `pipelines/variable-group-installshield-image-build.env.example`)
- Service connection ARM z Contributor na RG
- Stage **BuildImage** — Packer przez SP (nie MI)
- Stage **RegisterMdp** — `Update-ManagedDevOpsPoolImage.ps1`

Wymaga self-hosted agenta z Packerem lub osobnej build VM jako agenta ADO.

---

## Kolejna wersja obrazu (np. 1.0.1)

1. `az vm start` na packer VM (lub inna maszyna z uprawnieniami)
2. `git pull` na branchu `installshield-2025-win2022`
3. Świeży SAS / źródło instalatora SAB
4. `.\Build-InstallShieldImage-NedPrd.ps1 -ImageVersion '1.0.1' -UseManagedIdentity -RestrictToAgentIpAddress`
5. `.\Update-ManagedDevOpsPoolImage.ps1` z nowym `GalleryImageVersionResourceId` (wersja `1.0.1`)
6. `az vm deallocate` po zakończeniu

Alias `installshield-2025` zostanie zaktualizowany do nowej wersji galerii.

---

## Stan na koniec pierwszego wdrożenia (2026-06-22)

| Element | Status |
|---------|--------|
| Bicep ACG + Reader | ✅ |
| Bicep packer VM | ✅ |
| Packer build → ACG `1.0.0` | ✅ |
| MDP alias `installshield-2025` | ✅ |
| VM `vm-ned-prd-packer-build-001` | **deallocated** |
| Pipeline aplikacji z `InstallShieldBuild@1` | do skonfigurowania w projekcie ADO |

---

## Powiązane dokumenty

- [README.md](./README.md) — skrót infrastruktury NED PRD
- [docs/installshield-win2022-image.md](../../docs/installshield-win2022-image.md) — opis warstwy obrazu
- [docs/create-image-and-azure-resources.md](../../docs/create-image-and-azure-resources.md) — ogólny flow `GenerateResourcesAndImage`
- [Microsoft: Configure images for MDP](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-images)
