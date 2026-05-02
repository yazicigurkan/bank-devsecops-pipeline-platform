# Bank DevSecOps Pipeline Platform

Bankacilik ortaminda Jira kontrollu, audit edilebilir ve reusable GitHub Actions tabanli SDLC pipeline platformu.

Bu repo pipeline logic'in merkezi sahibidir. Uygulama repository'leri kendi pipeline'larini kopyalamaz; sadece bu repodaki tag'lenmis reusable workflow'lari cagirir.

```yaml
jobs:
  dev:
    uses: yazicigurkan/bank-devsecops-pipeline-platform/.github/workflows/dotnet-dev-ci-cd.yaml@v1.0.0
    with:
      application_name: payment-api
      deployment_type: kubernetes
      target_environment: DEV
    secrets: inherit
```

## Ana Prensipler

- `DEV` otomatik deploy edilebilir, ama kalite ve guvenlik kontrolleri zorunludur.
- `TEST` ve `PROD` Jira SDLC talebi olmadan deploy edilemez.
- `PROD` ortaminda rebuild alinmaz; TEST'te onaylanan artifact veya image promote edilir.
- SonarQube, GraphNode, Twistlock, Nexus ve Harbor sonuclari release evidence'a baglanir.
- Uygulama repo'larinda karmasik pipeline logic tutulmaz.
- Workflow'lar `main` uzerinden degil, platform release tag'i ile cagrilir.

## Repository Yapisi

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
│   ├── reusable-release-evidence-publish.yaml
│   ├── reusable-release-governance.yaml
│   ├── reusable-docker-build.yaml
│   ├── reusable-twistlock-scan.yaml
│   ├── reusable-harbor-push.yaml
│   ├── reusable-iis-deploy.yaml
│   ├── reusable-k8s-deploy.yaml
│   ├── reusable-jira-validation.yaml
│   └── reusable-jira-transition.yaml
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

## SDLC Akislari

### DEV

`DEV` branch'e push/merge sonrasi otomatik calisir:

1. Checkout `DEV`
2. .NET restore, test, publish
3. SonarQube Quality Gate
4. GraphNode incremental SAST
5. Nexus artifact publish
6. Deployment tipi `kubernetes` ise Docker build, Twistlock, Harbor push, Helm deploy
7. Deployment tipi `iis` ise Nexus artifact ile IIS deploy
8. DEV release evidence publish

### TEST

Jira SDLC talebi veya API trigger ile calisir:

1. Input guard: `branch_name=TEST`, `target_environment=TEST`
2. Jira status ve approval validation
3. Checkout `TEST`
4. SonarQube, GraphNode, build/package
5. Nexus publish
6. IIS veya Kubernetes deploy
7. Release manifest olustur ve Nexus `release-evidence` repository'sine publish et
8. Jira transition: `Test Ortam Kontrolleri`

### PROD

Sadece onayli release promote eder:

1. Input guard: `branch_name=PROD`, `target_environment=PROD`
2. Jira status, manager, test ve bilgi guvenligi onaylarini dogrula
3. Change window ve rollback plan alanlarini dogrula
4. Nexus'taki TEST release manifest'i indir ve security evidence'i dogrula
5. GitHub `PROD` Environment Protection approval bekle
6. Rebuild almadan Nexus artifact veya Harbor image digest ile deploy et
7. Jira transition: `PROD Deploy Tamamlandı`

## Zorunlu Secrets

Secrets environment seviyesinde ayrilmalidir: `DEV`, `TEST`, `PROD`.

| Secret | Kullanim |
| --- | --- |
| `NUGET_USERNAME`, `NUGET_PASSWORD` | Nexus NuGet proxy restore |
| `SONAR_HOST_URL`, `SONAR_TOKEN` | SonarQube analysis ve Quality Gate |
| `GRAPHNODE_BASE_URL`, `GRAPHNODE_TOKEN` | GraphNode SAST |
| `NEXUS_BASE_URL`, `NEXUS_USERNAME`, `NEXUS_PASSWORD` | Artifact ve release evidence |
| `HARBOR_REGISTRY`, `HARBOR_USERNAME`, `HARBOR_PASSWORD` | Container image push |
| `TWISTLOCK_CONSOLE_URL`, `TWISTLOCK_USER`, `TWISTLOCK_PASSWORD` | Image vulnerability scan |
| `JIRA_BASE_URL`, `JIRA_USER_EMAIL`, `JIRA_API_TOKEN` | Jira validation, comment, transition |
| `KUBE_CONFIG` | Kubernetes deploy |
| `WINDOWS_DEPLOY_USERNAME`, `WINDOWS_DEPLOY_PASSWORD` | IIS PowerShell remoting |

## Jira Field Mapping

`reusable-jira-validation.yaml` varsayilan olarak su field adlarini bekler:

- `customfield_managerApproval`
- `customfield_securityApproval`
- `customfield_testApproval`
- `customfield_changeWindow`
- `customfield_rollbackPlan`

Gercek Jira instance'inda bu alanlar farkliysa workflow input'u ile override edilmelidir:

```yaml
with:
  manager_approval_field: customfield_10100
  security_approval_field: customfield_10101
  test_approval_field: customfield_10102
  change_window_field: customfield_10103
  rollback_plan_field: customfield_10104
```

PROD icin change window alani `2026-05-02T21:00:00+03:00/2026-05-02T23:00:00+03:00` formatinda verilirse pipeline mevcut zamanin pencere icinde oldugunu dogrular.

## Release Evidence

TEST deploy sonrasi `reusable-release-evidence-publish.yaml` asagidaki manifest'i Nexus'a yazar:

```text
${NEXUS_BASE_URL}/repository/release-evidence/<application>/<version>/release-manifest.json
```

Manifest minimum su bilgileri tasir:

- application, version, commit SHA
- artifact URL ve artifact version
- image tag ve image digest
- SonarQube Quality Gate
- GraphNode scan id, severity counts, report URL
- Twistlock scan id, severity counts, report URL
- Jira issue key ve approver bilgileri
- TEST deployment approval status
- rollback plan

PROD workflow'u bu manifest'i dogrulamadan deploy etmez.

## Local Dry-Run

Gercek Jira/Nexus/Harbor/Sonar/GraphNode endpointleri olmadan governance davranisini test etmek icin:

```bash
cd /Users/gurkanyazici/Desktop/TTB
bank-devsecops-pipeline-platform/scripts/local/simulate-pipeline.sh all
bank-devsecops-pipeline-platform/scripts/local/simulate-pipeline.sh negative
```

`all` pozitif DEV -> TEST -> PROD promotion akisini simule eder.  
`negative` release manifest icine yuksek seviye Twistlock bulgusu yazar ve PROD promotion'in bloklandigini dogrular.

Dry-run ciktisi `local-lab/` altinda uretilir ve git'e alinmaz.

## Validasyon

Yerel statik kontroller:

```bash
ruby -e 'require "yaml"; files = Dir["bank-devsecops-pipeline-platform/.github/workflows/*.{yaml,yml}"] + Dir["bank-devsecops-pipeline-platform/actions/*/action.yaml"]; files.each { |f| YAML.load_file(f) }; puts "YAML OK"'
find bank-devsecops-pipeline-platform/scripts -name "*.sh" -print0 | xargs -0 -n1 bash -n
```

Gercek runner validasyonu icin onerilen ek kontrol:

```bash
actionlint bank-devsecops-pipeline-platform/.github/workflows/*.yaml
```

## Platform Release Yonetimi

Bu repo kendi release lifecycle'ina sahip olmalidir:

1. Platform degisikligi PR ile gelir.
2. Workflow syntax, dry-run ve entegrasyon testleri calisir.
3. DevOps platform owner approval verir.
4. Release tag uretilir: `v1.0.0`, `v1.1.0`.
5. Uygulama repo'lari kontrollu sekilde yeni tag'e gecer.

## Dokumantasyon

- Mimari: `docs/architecture.md`
- Branch stratejisi: `docs/branching-strategy.md`
- Security controls: `docs/security-controls.md`
- Release governance: `docs/release-governance.md`
- Audit modeli: `docs/audit-model.md`
- Yeni uygulama onboarding: `docs/onboarding-new-application.md`
- Workflow kontrati: `docs/workflow-contract.md`
- GitHub test plani: `docs/github-test-plan.md`
- GitHub environments ve secrets: `docs/github-environments-and-secrets.md`

## Uyum Notlari

- PROD deploy'da `dotnet build`, `dotnet publish`, `docker build` calistirilmaz.
- Harbor icin immutable tag policy ve digest ile deploy onerilir.
- Nexus release artifact repository immutable olmalidir.
- Self-hosted runner network erisimleri ortam bazinda ayrilmalidir.
- PROD environment secret'lari sadece GitHub Environment Protection approval sonrasi acilmalidir.
