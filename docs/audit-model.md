# Audit Model

Audit trail kaynaklari:

- GitHub Actions run id ve logs
- Jira issue history, comment ve transition history
- Nexus artifact metadata
- Harbor image digest ve immutability policy
- SonarQube, GraphNode ve Twistlock report URL'leri
- Kubernetes rollout history veya IIS backup timestamp

Her deployment sonunda evidence JSON uretilmeli ve Jira talebine comment veya attachment olarak eklenmelidir.
