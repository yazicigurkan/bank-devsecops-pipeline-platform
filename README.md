# Bank DevSecOps Pipeline Platform

Merkezi, reusable, GitHub Actions tabanli DevSecOps pipeline platformu. Bu repo bankacilik ortami icin yetki ayrimi, onay mekanizmasi, audit trail, guvenlik kontrolleri, artifact promotion ve Jira/OpenProject kontrollu SDLC akislarini standartlastirir.

Uygulama repository'leri pipeline logic kopyalamaz. Sadece bu repodaki tag'lenmis reusable workflow'lari cagirir.

```yaml
jobs:
  dev:
    uses: yazicigurkan/bank-devsecops-pipeline-platform/.github/workflows/dotnet-dev-ci-cd.yaml@v1.0.21
    with:
      application_name: payment-api
      deployment_type: kubernetes
      target_environment: DEV
    secrets: inherit
```

## Current Lab Status

Son basarili DEV run:

- Application repo: `yazicigurkan/banking-dotnet-payment-api`
- Branch: `DEV`
- Platform tag: `v1.0.21`
- Run: `https://github.com/yazicigurkan/banking-dotnet-payment-api/actions/runs/25274845379`
- Result: success

Gecen adimlar:

1. .NET restore, test, publish, package
2. SonarQube analysis ve Quality Gate
3. GraphNode incremental SAST
4. Nexus artifact publish
5. Docker image build
6. Twistlock policy check
7. Harbor image push
8. GitOps values update
9. Argo CD auto-sync to Kubernetes
10. Health/rollout validation through Argo CD
11. Release evidence publish

## Lab Topology On Proxmox

Proxmox UI:

```text
https://192.168.18.2:8006
```

Mevcut LXC makineleri:

| VMID | Name | IP | Role | URL |
| --- | --- | --- | --- | --- |
| 110 | openproject | `192.168.18.50` | Jira yerine SDLC/change management lab tool | `http://192.168.18.50` |
| 111 | nexus | `192.168.18.51` | NuGet proxy, artifact repository, release evidence | `http://192.168.18.51:8081` |
| 112 | sonarqube | `192.168.18.52` | Code quality ve Quality Gate | `http://192.168.18.52:9000` |
| 113 | harbor | `192.168.18.53` | Container image registry | `http://192.168.18.53` |
| 114 | security-tools | `192.168.18.54` | GitHub runner, k3s, GraphNode lab API, Trivy/Twistlock shim | `http://192.168.18.54:8080` |

## Login To Lab Machines

Proxmox host'a girdikten sonra container'a parolasiz girmek icin:

```bash
pct enter 110
pct enter 111
pct enter 112
pct enter 113
pct enter 114
```

Dogudan SSH ile girmek icin:

```bash
ssh root@192.168.18.50
ssh root@192.168.18.51
ssh root@192.168.18.52
ssh root@192.168.18.53
ssh root@192.168.18.54
```

Container root parolalari Proxmox host uzerinde root-only dosyada tutulur. Degerleri ortak ekranlara veya ticket comment'lerine kopyalamayin; sadece lokal terminalde ihtiyac oldugunda acin:

```bash
cat /root/devsecops-lab-credentials/ct-root-passwords.txt
```

Lab erisim ozet dosyasi:

```bash
cat /root/devsecops-lab-credentials/README.txt
```

Parolalari GitHub'a, README'ye veya pipeline loglarina yazmayin.

## Product Credentials

Urun parolalari ilgili LXC icinde dosya olarak tutulur. Best practice olarak degerleri terminale yazdirmadan GitHub Environment secret olarak aktar:

```bash
pct exec 111 -- cat /root/devsecops-secrets/nexus-admin-password | gh secret set NEXUS_PASSWORD --repo yazicigurkan/banking-dotnet-payment-api --env TEST
pct exec 112 -- cat /root/devsecops-secrets/sonar-github-actions-token | gh secret set SONAR_TOKEN --repo yazicigurkan/banking-dotnet-payment-api --env TEST
pct exec 113 -- cat /root/harbor-admin-password.txt | gh secret set HARBOR_PASSWORD --repo yazicigurkan/banking-dotnet-payment-api --env TEST
```

Labda manuel login icin parola gormek gerekiyorsa, komutu sadece lokal ve guvenli terminalde calistir; ciktisini issue, README veya pipeline loguna yazma.

## Kubernetes Environment

Kubernetes lab ortami CT 114 uzerinde k3s olarak calisir. Kubernetes deployment modeli GitOps'a tasindi: pipeline image'i build edip Harbor'a push eder, ilgili Helm values dosyasindaki image tag/digest'i Git'e commit eder, Argo CD de ilgili branch/path degisikligini otomatik sync eder.

Kontrol:

```bash
pct exec 114 -- kubectl get nodes -o wide
pct exec 114 -- kubectl get ns --show-labels | grep payment
pct exec 114 -- kubectl get pods -A -o wide
```

Namespace ayrimi:

| Environment | Namespace |
| --- | --- |
| DEV | `payment-dev` |
| TEST | `payment-test` |
| PROD | `payment-prod` |

DEV pipeline artik dogrudan `helm upgrade` calistirmaz. Desired state `deploy/k8s/values-dev.yaml` dosyasina commit edilir; Argo CD `payment-api-dev` Application'i bu degisikligi `payment-dev` namespace'ine uygular. `values-dev.yaml` NodePort kullanir ve health check runner icinden su endpoint'e gider:

```text
http://127.0.0.1:30080/health
```

Argo CD UI:

```text
https://192.168.18.54:30443
```

Admin parolasi CT 114 icinde tutulur:

```bash
pct exec 114 -- cat /root/devsecops-secrets/argocd-admin-password
```

Argo CD Applications:

| Application | Branch | Chart path | Values file | Namespace | Sync |
| --- | --- | --- | --- | --- | --- |
| `payment-api-dev` | `DEV` | `deploy/k8s/chart` | `deploy/k8s/values-dev.yaml` | `payment-dev` | automated |
| `payment-api-test` | `TEST` | `deploy/k8s/chart` | `deploy/k8s/values-test.yaml` | `payment-test` | automated |
| `payment-api-prod` | `PROD` | `deploy/k8s/chart` | `deploy/k8s/values-prod.yaml` | `payment-prod` | automated |

GitOps kontrol komutlari:

```bash
pct exec 114 -- kubectl -n argocd get applications
pct exec 114 -- kubectl -n argocd describe application payment-api-dev
pct exec 114 -- kubectl get pods -n payment-dev
```

TEST ve PROD icin branch'ler olusturuldu:

```text
DEV
TEST
PROD
```

## IIS Environment

Su anda Proxmox uzerinde Windows Server/IIS VM yoktur. Proxmox ISO dizininde Windows Server ISO da bulunmuyor. Gercek IIS deployment icin Windows Server VM gerekir.

IIS hedefini hazirlamak icin gerekli adimlar:

1. Windows Server ISO'yu Proxmox'a yukle:

   ```text
   /var/lib/vz/template/iso
   ```

2. Windows VM olustur.
3. IIS role'lerini kur:

   ```powershell
   Install-WindowsFeature Web-Server, Web-Mgmt-Service, Web-Asp-Net45 -IncludeManagementTools
   ```

4. PowerShell remoting ac:

   ```powershell
   Enable-PSRemoting -Force
   Set-Item WSMan:\localhost\Service\AllowUnencrypted $true
   Set-Item WSMan:\localhost\Service\Auth\Basic $true
   ```

5. GitHub self-hosted runner kur ve su label'lari ver:

   ```text
   self-hosted
   windows
   iis
   ```

6. GitHub Environment secrets olarak `WINDOWS_DEPLOY_USERNAME` ve `WINDOWS_DEPLOY_PASSWORD` tanimla.

`reusable-iis-deploy.yaml` Windows runner uzerinde calisir:

```yaml
runs-on: [self-hosted, windows, iis]
```

Bu nedenle Linux LXC uzerinde gercek IIS deploy testi yapilmaz.

## Repository Structure

```text
bank-devsecops-pipeline-platform/
├── .github/workflows/
│   ├── dotnet-dev-ci-cd.yaml
│   ├── dotnet-jira-test-release.yaml
│   ├── dotnet-jira-prod-release.yaml
│   ├── reusable-dotnet-build.yaml
│   ├── reusable-sonarqube-scan.yaml
│   ├── reusable-graphnode-sast.yaml
│   ├── reusable-graphnode-full-scan.yaml
│   ├── reusable-nexus-publish.yaml
│   ├── reusable-nexus-artifact-validation.yaml
│   ├── reusable-release-evidence-publish.yaml
│   ├── reusable-release-governance.yaml
│   ├── reusable-docker-build.yaml
│   ├── reusable-twistlock-scan.yaml
│   ├── reusable-harbor-push.yaml
│   ├── reusable-argocd-gitops-update.yaml
│   ├── reusable-iis-deploy.yaml
│   ├── reusable-k8s-deploy.yaml
│   ├── reusable-jira-validation.yaml
│   ├── reusable-jira-transition.yaml
│   ├── reusable-smoke-test.yaml
│   ├── reusable-environment-smoke-test.yaml
│   ├── reusable-sdlc-dry-run.yaml
│   └── platform-validation.yaml
├── actions/
│   ├── graphnode-scan/
│   ├── jira-status-check/
│   ├── nexus-version-resolver/
│   ├── twistlock-policy-check/
│   └── deployment-summary/
├── scripts/
│   ├── iis/
│   ├── jira/
│   ├── k8s/
│   ├── local/
│   ├── nexus/
│   ├── release/
│   └── security/
├── templates/
└── docs/
```

## Workflow Catalog

### Orchestration Workflows

`dotnet-dev-ci-cd.yaml`

- `DEV` branch icin otomatik CI/CD orkestrasyonudur.
- Build, SonarQube, GraphNode, Nexus publish ve secilen deployment tipini calistirir.
- `deployment_type=kubernetes` ise Docker build, Twistlock scan, Harbor push, GitOps values update, Argo CD sync wait ve evidence publish yapar.
- `deployment_type=iis` ise Nexus artifact uzerinden IIS deploy workflow'una gider.

`dotnet-jira-test-release.yaml`

- TEST deploy'u sadece Jira/OpenProject SDLC talebiyle calistirmak icin tasarlanmistir.
- `branch_name=TEST` ve `target_environment=TEST` input guard uygular.
- Jira status ve approval dogrulamasi yapar.
- TEST ortaminda build/release candidate uretir, Nexus'a publish eder, secilen hedefe deploy eder.
- Basarili deployment sonrasi Jira transition olarak `Test Ortam Kontrolleri` uygular.

`dotnet-jira-prod-release.yaml`

- PROD deploy icin en siki kontrollu akistir.
- `branch_name=PROD` ve `target_environment=PROD` input guard uygular.
- Jira status, manager, security ve test approval dogrular.
- Release governance ile TEST evidence manifest'ini kontrol eder.
- GitHub `PROD` Environment approval bekler.
- PROD'da rebuild almaz; onayli artifact/image'i promote eder.

### Reusable Build And Quality Workflows

`reusable-dotnet-build.yaml`

- Checkout, `dotnet restore`, unit test, `dotnet publish` ve zip package uretir.
- NuGet restore, uygulama reposundaki `NuGet.config` uzerinden Nexus proxy'ye gider.
- Artifact'i GitHub Actions artifact olarak sonraki job'lara aktarir.

`reusable-sonarqube-scan.yaml`

- Sonar scanner'i Nexus NuGet proxy uzerinden kurar.
- `sonar.qualitygate.wait=true` ile Quality Gate sonucunu bekler.
- Quality Gate `OK` degilse pipeline durur.
- Lab SonarQube Community icin `branch_analysis_enabled=false` destekler.

`reusable-graphnode-sast.yaml`

- Incremental GraphNode SAST scan yapar.
- Son commit ve onceki commit bilgisini GraphNode API'ye gonderir.
- Critical bulgu varsa durur.
- High bulguda davranis `fail_on_high` ile kontrol edilir.

`reusable-graphnode-full-scan.yaml`

- Yeni proje onboarding icin full scan calistirir.
- GraphNode endpoint'i `full-scan` olarak kullanilir.

### Reusable Artifact And Evidence Workflows

`reusable-nexus-publish.yaml`

- Build artifact'ini GitHub artifact'tan indirir.
- Nexus artifact version uretir.
- DEV icin ephemeral format kullanir: `<application>-DEV-<short_sha>-<run_number>`.
- TEST ve PROD icin OpenProject/Jira talebinden gelen release version kullanilir: ornek `v1.1.1`.
- Nexus raw repository'ye artifact upload eder.

`reusable-nexus-artifact-validation.yaml`

- PROD promotion oncesi Nexus artifact URL'inin erisilebilir oldugunu dogrular.
- PROD'da rebuild yerine onayli artifact'in kullanilmasini destekler.

`reusable-release-evidence-publish.yaml`

- Release manifest JSON olusturur.
- Sonar, GraphNode, Twistlock, Nexus, Harbor ve Jira bilgilerini evidence'a baglar.
- Manifest'i Nexus `release-evidence` repository'sine publish eder.

`reusable-release-governance.yaml`

- PROD deploy oncesi TEST release manifest'ini indirir.
- Sonar Quality Gate, GraphNode critical/high, Twistlock critical/high, TEST approval ve rollback plan kontrollerini uygular.
- PROD'da rebuild alinmasini engelleyen promotion modelinin merkezidir.

### Reusable Container Workflows

`reusable-docker-build.yaml`

- Docker image tag uretir.
- Tag formati:

  ```text
  DEV:  <application>-DEV-<short_sha>-<run_number>
  TEST: <openproject_release_version>
  PROD: TEST'te onaylanan ayni <openproject_release_version>
  ```

- Ornekler: `payment-api-DEV-a1b2c3d-145`, `v1.1.1`.
- Image'i local Docker daemon'da build eder.
- Image tar dosyasini scan/push job'lari icin Actions artifact olarak saklar.

`reusable-twistlock-scan.yaml`

- Image tar artifact'ini indirir ve local Docker'a load eder.
- `twistlock-policy-check` composite action'ini calistirir.
- Lab ortaminda `twistcli` komutu Trivy-backed shim olarak calisir.
- Critical/high vulnerability policy'ye gore pipeline'i durdurur.

`reusable-harbor-push.yaml`

- Image artifact'ini indirir, Docker'a load eder.
- Harbor login yapar.
- Image'i Harbor'a push eder.
- Image digest bilgisini toplar ve sonraki deploy/evidence adimlarina output verir.

`reusable-argocd-gitops-update.yaml`

- Kubernetes deployment icin GitOps desired state'i gunceller.
- Ilgili environment branch'indeki Helm values dosyasinda `image.repository`, `image.tag` ve `image.digest` alanlarini degistirir.
- Commit mesaji `[skip ci]` icerir; boylece GitOps commit'i yeni CI loop'u baslatmaz.
- Argo CD Application'i hard refresh eder ve `Synced/Healthy` olana kadar bekler.
- `KUBE_CONFIG` secret'i ile k3s/cluster'a baglanir.

`reusable-k8s-deploy.yaml`

- Legacy/manual Helm deploy workflow'udur.
- GitOps modunda ana orchestration workflow'lari bunu kullanmaz.
- Acil durum veya GitOps disi lab testlerinde `KUBE_CONFIG` ile Helm upgrade/install calistirabilir.

### Reusable IIS Workflows

`reusable-iis-deploy.yaml`

- Windows self-hosted runner gerektirir.
- Nexus artifact indirir.
- IIS app pool stop/start, backup, config transform, deploy ve health check script'lerini calistirir.
- Hedef runner label'lari: `self-hosted`, `windows`, `iis`.

### Reusable Jira/OpenProject Workflows

`reusable-jira-validation.yaml`

- Issue status dogrular.
- Manager, information-security, test-lead approval alanlarini kontrol eder.
- PROD icin change window ve rollback plan alanlarini zorunlu kilar.

`reusable-jira-transition.yaml`

- Issue'a deployment comment ekler.
- Belirtilen transition adina gore issue status degistirir.

### Utility Workflows

`platform-validation.yaml`

- Platform repo PR/push kontroludur.
- YAML parse, shell syntax ve actionlint benzeri statik validasyonlari calistirmak icin kullanilir.

`reusable-smoke-test.yaml`

- Basit reusable workflow cagri testi icindir.

`reusable-environment-smoke-test.yaml`

- Environment secret/readiness testleri icindir.

`reusable-sdlc-dry-run.yaml`

- Gercek tool endpointlerine gitmeden SDLC evidence/governance davranisini simule eder.

## Required GitHub Secrets

Secrets repo seviyesinde degil, mumkunse GitHub Environment seviyesinde ayrilmalidir: `DEV`, `TEST`, `PROD`.

| Secret | Purpose |
| --- | --- |
| `NUGET_USERNAME`, `NUGET_PASSWORD` | Nexus NuGet proxy restore |
| `SONAR_HOST_URL`, `SONAR_TOKEN` | SonarQube analysis ve Quality Gate |
| `GRAPHNODE_BASE_URL`, `GRAPHNODE_TOKEN` | GraphNode SAST |
| `NEXUS_BASE_URL`, `NEXUS_USERNAME`, `NEXUS_PASSWORD` | Artifact ve release evidence |
| `HARBOR_REGISTRY`, `HARBOR_USERNAME`, `HARBOR_PASSWORD` | Harbor login/push |
| `TWISTLOCK_CONSOLE_URL`, `TWISTLOCK_USER`, `TWISTLOCK_PASSWORD` | Image scan |
| `JIRA_BASE_URL`, `JIRA_USER_EMAIL`, `JIRA_API_TOKEN` | Jira/OpenProject validation ve transition |
| `KUBE_CONFIG` | Kubernetes deploy |
| `WINDOWS_DEPLOY_USERNAME`, `WINDOWS_DEPLOY_PASSWORD` | IIS deploy |

Lab icin `HARBOR_REGISTRY` secret olarak durur, ama workflow output masking sorununu engellemek icin application workflow input'u olarak public registry host da verilir:

```yaml
with:
  harbor_registry: 192.168.18.53
```

## Jira/OpenProject Field Mapping

Varsayilan field adlari:

- `customfield_managerApproval`
- `customfield_securityApproval`
- `customfield_testApproval`
- `customfield_changeWindow`
- `customfield_rollbackPlan`

Gercek Jira'da field id'leri farkliysa input ile override edilmelidir:

```yaml
with:
  manager_approval_field: customfield_10100
  security_approval_field: customfield_10101
  test_approval_field: customfield_10102
  change_window_field: customfield_10103
  rollback_plan_field: customfield_10104
```

## Release And Promotion Rules

- DEV ortaminda build alinabilir.
- TEST ortaminda release candidate uretilebilir.
- PROD ortaminda rebuild alinmaz.
- PROD sadece TEST'te onaylanmis artifact veya image'i promote eder.
- DEV artifact/image versiyonu otomatik ve gecicidir: `<application>-DEV-<short_sha>-<run_number>`.
- TEST ve PROD artifact/image versiyonu OpenProject talebindeki release version'dir; ayni `v1.1.1` hem TEST hem PROD promotion kimligidir.
- Nexus artifact ve Harbor image immutable kabul edilmelidir.
- Release manifest olmadan PROD deploy yapilmaz.

Release manifest lokasyonu:

```text
${NEXUS_BASE_URL}/repository/release-evidence/<application>/<version>/<artifact_version>/release-manifest.json
```

## Validation Commands

Local workflow lint:

```bash
cd /Users/gurkanyazici/Desktop/TTB/bank-devsecops-pipeline-platform
actionlint .github/workflows/*.yaml
```

Shell syntax:

```bash
find scripts -name "*.sh" -print0 | xargs -0 -n1 bash -n
```

Dry-run:

```bash
scripts/local/simulate-pipeline.sh all
scripts/local/simulate-pipeline.sh negative
```

Kubernetes smoke:

```bash
pct exec 114 -- kubectl get pods -n payment-dev
curl -fsS http://127.0.0.1:30080/health
```

## Application Repository Expectations

Uygulama reposunda minimum workflow bulunur:

```text
.github/workflows/dev-ci-cd.yaml
.github/workflows/jira-test-deploy.yaml
.github/workflows/jira-prod-deploy.yaml
```

Uygulama workflow'u sadece platform workflow'unu tag ile cagirir:

```yaml
uses: yazicigurkan/bank-devsecops-pipeline-platform/.github/workflows/dotnet-dev-ci-cd.yaml@v1.0.17
```

`main` veya mutable branch referansi kullanilmaz.

## Operating Model

1. Platform degisikligi once bu repoda yapilir.
2. `actionlint` ve lokal kontroller calistirilir.
3. Platform owner review verir.
4. Yeni tag uretilir.
5. Uygulama repo'lari kontrollu sekilde yeni tag'e gecer.
6. DEV otomatik dogrulanir.
7. TEST/PROD sadece Jira/OpenProject SDLC talebiyle calistirilir.
8. PROD icin GitHub Environment Protection approval zorunludur.

## Known Lab Limitations

- SonarQube Community branch analysis desteklemedigi icin lab'da `sonar_branch_analysis_enabled=false` kullanilir.
- GraphNode lab API, gercek urun yerine HTTP-compatible mock servisidir.
- Twistlock lab entegrasyonu, `twistcli` isimli Trivy-backed shim ile yapilir.
- Argo CD, private GitHub app repo'ya read-only deploy key ile erisir.
- Gercek IIS deployment icin Windows Server VM henuz yoktur.
- GitHub Actions loglarinda Node.js 20 deprecation uyarilari gorulebilir; mevcut run'i kirmiyor.

## Additional Docs

- `docs/architecture.md`
- `docs/branching-strategy.md`
- `docs/security-controls.md`
- `docs/release-governance.md`
- `docs/audit-model.md`
- `docs/onboarding-new-application.md`
- `docs/workflow-contract.md`
- `docs/best-practice-review.md`
- `docs/github-test-plan.md`
- `docs/github-environments-and-secrets.md`
- `docs/proxmox-community-tooling-lab.md`
