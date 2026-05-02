# Workflow Contract

Bu dokuman uygulama repo'larinin merkezi platform workflow'larini hangi kontratla cagiracagini ozetler.

## Orchestration Workflows

| Workflow | Amac | Trigger eden repo |
| --- | --- | --- |
| `dotnet-dev-ci-cd.yaml` | DEV otomatik CI/CD | Uygulama repo |
| `dotnet-jira-test-release.yaml` | Jira kontrollu TEST release | Uygulama repo |
| `dotnet-jira-prod-release.yaml` | Jira + GitHub approval kontrollu PROD promotion | Uygulama repo |

## Ortak Input Kurallari

- `application_name`: Kisa uygulama adi. Artifact, image ve evidence path icin kullanilir.
- `deployment_type`: Sadece `iis` veya `kubernetes`.
- `target_environment`: `DEV`, `TEST` veya `PROD`.
- `branch_name`: TEST workflow icin `TEST`, PROD workflow icin `PROD` olmak zorundadir.
- `release_version`: Semantic version olmalidir. Ornek: `1.4.2`.

## Platform Versiyonlama

Uygulama repo'lari workflow'lari tag ile cagirmalidir:

```yaml
uses: yazicigurkan/bank-devsecops-pipeline-platform/.github/workflows/dotnet-jira-test-release.yaml@v1.0.0
```

Merkezi workflow'lar kendi composite action ve scriptlerini de `platform_repository` ve `platform_ref` input'lariyla checkout eder. Varsayilan:

```yaml
platform_repository: yazicigurkan/bank-devsecops-pipeline-platform
platform_ref: v1.0.0
```

Platform yeni tag'e gectiginde uygulama repo workflow'lari ve gerekirse bu input'lar birlikte guncellenmelidir.

## Jira Kontrati

Jira talebinde en az su bilgiler bulunmalidir:

- issue key
- status
- manager approval
- test approval
- PROD icin information security approval
- PROD icin change window
- PROD icin rollback plan

TEST allowed status:

- `TEST Deploy`
- `TEST Deploy Approved`

PROD allowed status:

- `DevOps Deploy Bekliyor`
- `DevOps Deployment Ready`

## Release Evidence Kontrati

PROD workflow'u su path'te release manifest bekler:

```text
${NEXUS_BASE_URL}/repository/release-evidence/<application>/<version>/release-manifest.json
```

Manifestte zorunlu alanlar:

- `application`
- `version`
- `jiraIssueKey`
- `testDeployment.status = APPROVED`
- `sonarQualityGate = PASSED`
- `graphNode.critical = 0`
- `graphNode.high = 0`
- `twistlock.critical = 0`
- `twistlock.high = 0`
- IIS icin `artifactUrl`
- Kubernetes icin `imageTag` ve `imageDigest`

## PROD Rebuild Yasagi

PROD orchestration workflow'unda build workflow'u, Docker build workflow'u veya Nexus publish workflow'u cagrilmaz. Sadece su kaynaklar kullanilir:

- IIS: TEST release manifestteki `artifactUrl`
- Kubernetes: TEST release manifestteki `imageTag` ve `imageDigest`
