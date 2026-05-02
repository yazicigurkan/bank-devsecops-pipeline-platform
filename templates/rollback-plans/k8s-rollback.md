# Kubernetes Rollback Plan

1. Jira rollback approval is confirmed.
2. Run `helm rollback <release> <revision> --namespace <namespace>`.
3. Wait for rollout status.
4. Run health check.
5. Add rollback evidence to Jira.
