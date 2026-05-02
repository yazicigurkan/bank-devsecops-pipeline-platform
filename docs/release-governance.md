# Release Governance

Release candidate TEST ortaminda uretilir ve evidence ile baglanir. PROD deploy, bu evidence icindeki artifact URL veya image digest'i kullanir. Yeni build veya yeni image uretilmez.

TEST workflow'u `reusable-release-evidence-publish.yaml` ile manifest'i Nexus `release-evidence` repository'sine yazar. PROD workflow'u `reusable-release-governance.yaml` ile ayni manifest'i indirir ve deploy oncesi dogrular.

Zorunlu evidence:

- Jira issue key
- Approver listesi
- SonarQube Quality Gate
- GraphNode scan id
- Twistlock scan id
- Nexus artifact URL veya Harbor image digest
- Rollback plan
- Change window

PROD icin zorunlu fail kosullari:

- SonarQube Quality Gate `PASSED` degilse
- GraphNode critical veya high bulgusu varsa
- Twistlock critical veya high vulnerability varsa
- TEST deployment status `APPROVED` degilse
- IIS icin Nexus artifact URL bos veya erisilemezse
- Kubernetes icin image digest bos ise
