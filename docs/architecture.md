# Bank DevSecOps Pipeline Platform Architecture

## 1. Executive Architecture Summary

Bu mimari, uygulama ekiplerinin pipeline logic yazmadigi, merkezi DevOps ekibinin ise reusable GitHub Actions workflow ve composite action'lari versiyonlayarak sundugu bir SDLC platformudur. Uygulama repolari yalnizca `uses: yazicigurkan/bank-devsecops-pipeline-platform/...@v1.0.0` seklinde merkezi workflow'lari cagirir.

Temel kararlar:

- DEV branch otomatik CI/CD calistirir.
- TEST ve PROD deployment yalnizca Jira SDLC talebi ile baslar.
- PROD'da rebuild yoktur; TEST'te onaylanan artifact veya image promote edilir.
- SonarQube, GraphNode ve Twistlock sonuclari release evidence dosyasina baglanir.
- Nexus artifact repository ve NuGet dependency proxy olarak kullanilir.
- Harbor image repository olarak kullanilir; PROD image tag/digest immutable olmalidir.
- GitHub Environment Protection Rules ve Jira onaylari birlikte kullanilir.

## 2. Target SDLC Flow

DEV akisi:

1. Developer `DEV` branch'e merge eder.
2. GitHub Actions otomatik calisir.
3. Restore, unit test, SonarQube, GraphNode, build ve package adimlari tamamlanir.
4. Artifact Nexus'a publish edilir.
5. Deployment tipi `iis` ise IIS DEV deploy, `kubernetes` ise Docker build, Twistlock, Harbor push ve K8s DEV deploy calisir.

TEST akisi:

1. Jira SDLC talebi TEST deploy statüsüne getirilir.
2. Jira automation `repository_dispatch` veya API ile workflow tetikler.
3. Pipeline Jira status ve onay alanlarini dogrular.
4. TEST branch checkout edilir, scan/build/release/deploy calisir.
5. Jira talebi `Test Ortam Kontrolleri` statüsüne gecirilir.

PROD akisi:

1. Jira talebinde manager, test ve bilgi guvenligi onaylari tamamlanir.
2. Change window ve rollback plan zorunlu kontrol edilir.
3. GitHub PROD environment approval beklenir.
4. TEST'te onaylanan release manifest dogrulanir.
5. Rebuild yapilmaz; Nexus artifact veya Harbor image digest promote edilir.
6. Deploy, health check ve Jira transition tamamlanir.

## 3. Repository Strategy

Uygulama repository:

```text
banking-dotnet-payment-api/
├── src/Payment.Api/
├── tests/Payment.Api.Tests/
├── Dockerfile
├── NuGet.config
├── deploy/iis/
├── deploy/k8s/
└── .github/workflows/
    ├── dev-ci-cd.yaml
    ├── jira-test-deploy.yaml
    └── jira-prod-deploy.yaml
```

Merkezi pipeline repository:

```text
bank-devsecops-pipeline-platform/
├── .github/workflows/
├── actions/
├── scripts/
├── templates/
└── docs/
```

Pipeline platform release lifecycle'a sahiptir. Uygulamalar `main` degil, `v1.0.0` gibi tag'leri cagirir.

## 4. Branch and Environment Strategy

| Branch | Environment | Trigger | Deployment |
| --- | --- | --- | --- |
| DEV | DEV | push | otomatik |
| TEST | TEST | Jira SDLC | kontrollu |
| PROD | PROD | Jira SDLC + GitHub approval | kontrollu promotion |

TEST ve PROD gecisleri yalnizca branch merge ile otomatik deploy yapmaz. Branch dogru kaynak kod durumunu temsil eder; deployment yetkisi Jira ve GitHub environment gate ile verilir.

## 5. Reusable Workflow Design

Orchestration workflow'lari:

- `dotnet-dev-ci-cd.yaml`
- `dotnet-jira-test-release.yaml`
- `dotnet-jira-prod-release.yaml`

Reusable atomik workflow'lar:

- `reusable-dotnet-build.yaml`
- `reusable-sonarqube-scan.yaml`
- `reusable-graphnode-sast.yaml`
- `reusable-graphnode-full-scan.yaml`
- `reusable-nexus-publish.yaml`
- `reusable-release-evidence-publish.yaml`
- `reusable-docker-build.yaml`
- `reusable-twistlock-scan.yaml`
- `reusable-harbor-push.yaml`
- `reusable-iis-deploy.yaml`
- `reusable-k8s-deploy.yaml`
- `reusable-jira-validation.yaml`
- `reusable-jira-transition.yaml`
- `reusable-release-governance.yaml`

Composite action'lar entegrasyon adaptoru olarak kullanilir: `graphnode-scan`, `jira-status-check`, `twistlock-policy-check`, `deployment-summary`.

TEST akisi release evidence publish eder; PROD akisi bu evidence'i Nexus'tan okuyup dogrular. Bu baglanti olmazsa PROD promotion calismaz.

## 6. DEV Pipeline

DEV pipeline otomatik calisir ve Jira zorunlu degildir. Commit mesajindan Jira key yakalanabilir ve varsa Jira comment yazilabilir. Quality Gate veya kritik guvenlik bulgusu pipeline'i durdurur. GraphNode high bulgulari DEV icin parametre ile warning veya fail yapilabilir.

## 7. TEST Pipeline

TEST pipeline `workflow_dispatch` ve `repository_dispatch` destekler. Zorunlu input'lar: `jira_issue_key`, `application_name`, `repository_name`, `branch_name=TEST`, `release_version`, `deployment_type`, `target_environment=TEST`.

Pipeline once Jira issue status ve manager/test onaylarini dogrular. Yanlis statüde deployment yapilmaz.

## 8. PROD Pipeline

PROD pipeline en siki akistir:

- Jira status `DevOps Deploy Bekliyor` veya `DevOps Deployment Ready` olmalidir.
- Manager, bilgi guvenligi ve test onayi zorunludur.
- Change window ve rollback plan zorunludur.
- GitHub `PROD` environment approval zorunludur.
- PROD'da `dotnet build`, `docker build` veya yeni package olusturma yasaktir.
- Release manifest TEST evidence ile dogrulanir.

## 9. IIS Deployment Model

IIS deploy reusable workflow parametreleri:

- `application_name`
- `environment`
- `artifact_version`
- `nexus_artifact_url`
- `iis_server_group`
- `iis_site_name`
- `iis_app_pool_name`
- `deploy_path`
- `health_check_url`
- `rollback_enabled`

Adimlar: Nexus'tan artifact indir, backup al, app pool stop, config transform, dosyalari kopyala, app pool start, health check, hata halinde rollback.

## 10. Kubernetes Deployment Model

Kubernetes deploy reusable workflow parametreleri:

- `application_name`
- `environment`
- `image_name`
- `image_tag`
- `image_digest`
- `harbor_project`
- `k8s_namespace`
- `helm_chart_path`
- `helm_values_file`
- `release_name`
- `health_check_url`
- `rollback_enabled`

Adimlar: immutable image digest dogrula, namespace'e Helm deploy, rollout status bekle, health check calistir, gerekirse Helm rollback.

## 11. GraphNode Integration

GraphNode iki mod destekler:

- Onboarding full scan: `POST /api/projects/{projectKey}/full-scan`
- Pipeline incremental scan: `POST /api/projects/{projectKey}/incremental-scan`

Onboarding full scan icin `reusable-graphnode-full-scan.yaml`, normal pipeline calismalari icin `reusable-graphnode-sast.yaml` kullanilir.

Policy:

- `critical > 0`: her ortamda fail
- `high > 0`: DEV icin parametreli, TEST/PROD icin fail
- `medium/low`: evidence'a raporlanir

## 12. SonarQube Integration

SonarQube workflow `project_key`, `branch_name` ve solution path alir. Branch analysis calistirir, Quality Gate sonucunu bekler ve `OK` disinda pipeline'i durdurur. Dashboard URL deployment summary'ye eklenir.

## 13. Nexus Integration

Nexus iki rol oynar:

- NuGet dependency proxy: `NuGet.config` internet yerine Nexus group/proxy kullanir.
- Artifact repository: Build edilen `.zip` paketler versiyonlu publish edilir.

PROD deploy'da artifact tekrar uretilmez. Release manifestteki `artifactUrl` Nexus'tan indirilir ve deploy edilir.

## 14. Harbor and Twistlock Integration

Container akisi:

1. Docker image build
2. Tag uret: `{version}-{environment}-{shortSha}-{runNumber}`
3. Twistlock scan
4. Policy check
5. Harbor login/push
6. Image digest al
7. Evidence'a yaz

PROD icin Harbor project seviyesinde immutable tag policy ve content trust/signature onerilir. En guvenli referans deploy'da tag degil digest'tir.

## 15. Jira Integration

Jira reusable validation su kontrolleri yapar:

- Issue var mi?
- Status allowed list icinde mi?
- Required approval alanlari approved mi?
- PROD icin change window ve rollback plan var mi?

Jira transition workflow deploy sonucunda comment ekler ve hedef statüye gecirir. Yanlis statüde pipeline fail eder.

## 16. Security and Governance Model

Secrets:

- DEV/TEST/PROD secret'lari ayri GitHub Environment altinda tutulur.
- PROD secret'lar sadece PROD environment approval sonrasi erisilebilir.
- Mümkünse cloud ve internal secret manager entegrasyonunda OIDC kullanilir.

Runner:

- Banka ici Nexus, Jira, SonarQube, GraphNode, Harbor, Twistlock, IIS ve K8s endpointlerine self-hosted runner ile erisilir.
- DEV/TEST/PROD runner network segmentleri ayrilir.
- PROD runner sadece PROD hedeflerine ve gerekli artifact registry'lerine erisir.

Audit:

- GitHub run id, Jira issue key, artifact URL, image digest, scan id, approver ve timestamp evidence'a yazilir.
- Jira comment ve attachment change evidence olarak saklanir.
- GitHub audit log, Jira history, Nexus asset metadata, Harbor digest ve K8s rollout history birlikte tutulur.

## 17. Versioning and Release Promotion

Version modeli:

- Semantic version: `1.4.2`
- Build metadata: GitHub run number
- Commit identity: short SHA
- Artifact version: `1.4.2-TEST-a1b2c3d-145`
- Image tag: `payment-api:1.4.2-TEST-a1b2c3d-145`
- PROD promotion: TEST image digest ayni kalir, opsiyonel PROD alias tag eklenir.

Release manifest ornegi:

```json
{
  "application": "payment-api",
  "version": "1.4.2",
  "commitSha": "abc123",
  "artifactUrl": "https://nexus.bank.local/repository/releases/payment-api/1.4.2/payment-api.zip",
  "image": "harbor.bank.local/payment/payment-api:1.4.2-TEST-abc123-145",
  "imageTag": "1.4.2-TEST-abc123-145",
  "imageDigest": "sha256:example",
  "sonarQualityGate": "PASSED",
  "graphNode": {
    "scanId": "scan-9876",
    "critical": 0,
    "high": 0
  },
  "twistlock": {
    "scanId": "tw-1234",
    "critical": 0,
    "high": 0
  },
  "jiraIssueKey": "SDLC-1234",
  "approvedBy": ["manager.user", "security.user"],
  "testApprovedBy": "test.user",
  "testDeployment": {
    "environment": "TEST",
    "status": "APPROVED"
  },
  "rollbackPlan": "Nexus artifact rollback or Helm rollback to previous revision",
  "createdAt": "2026-04-30T21:00:00+03:00"
}
```

## 18. Full YAML Examples

YAML dosyalari bu repo icinde yer alir:

- Application repo: `.github/workflows/dev-ci-cd.yaml`, `jira-test-deploy.yaml`, `jira-prod-deploy.yaml`
- Central repo: `.github/workflows/dotnet-*.yaml`, `.github/workflows/reusable-*.yaml`

Ornekler calisabilir iskelet olarak hazirlandi; kurum ici Jira custom field id'leri, runner label'lari ve endpoint URL'leri ortam standardina gore uyarlanmalidir.

## 19. Script Examples

Scriptler:

- `scripts/security/graphnode-scan.sh`
- `scripts/jira/validate-status.sh`
- `scripts/jira/transition-issue.sh`
- `scripts/nexus/upload-artifact.sh`
- `scripts/nexus/download-artifact.sh`
- `scripts/iis/deploy-iis.ps1`
- `scripts/iis/rollback-iis.ps1`
- `scripts/k8s/deploy.sh`
- `scripts/k8s/rollback.sh`
- `scripts/release/validate-release-manifest.sh`
- `scripts/security/twistlock-policy-check.sh`

## 20. Best Practices

- Merkezi pipeline repository kullan.
- Workflow'lari version tag ile cagir.
- Uygulama repo'larinda pipeline logic kopyalama.
- PROD'da rebuild alma.
- TEST'te onaylanan artifact/image'i promote et.
- Security scan sonuclarini release evidence'a bagla.
- Jira statüsü ve onaylari dogrulanmadan deployment yapma.
- DEV/TEST/PROD secret'larini environment bazinda ayir.
- Harbor image immutability ve Nexus artifact immutability uygula.
- Self-hosted runner network erisimini least privilege tasarla.

## 21. Anti-Patterns

- Her uygulama reposuna ayri pipeline logic kopyalamak.
- PROD icin yeniden build almak.
- Guvenlik tarama sonucunu sadece loglarda birakmak.
- Jira onaylarini sadece insan beyanina gore kabul etmek.
- DEV/TEST/PROD secret'larini ayni yerde tutmak.
- `main` branch'ten reusable workflow cagirmak.
- Mutable `latest` tag ile PROD deploy etmek.
- Deployment evidence uretmeden change kapatmak.

## 22. Final Recommended Operating Model

Merkezi DevOps ekibi pipeline platform repo'sunu urun gibi yonetmelidir: semantic version, changelog, backward compatibility, test repo'lari ve release approval. Uygulama ekipleri yalnizca parametre setlerini ve deployment config dosyalarini sahiplenir.

Operasyon modeli:

- DEV otomatik, ama scan ve evidence zorunlu.
- TEST Jira kontrollu release candidate akisi.
- PROD Jira + GitHub environment approval + evidence validation akisi.
- PROD rebuild yasagi teknik kontrolle uygulanir.
- Release manifest, deployment manifest ve scan report linkleri Jira talebinde saklanir.
- Rollback plan her PROD talebi icin zorunlu alandir.
