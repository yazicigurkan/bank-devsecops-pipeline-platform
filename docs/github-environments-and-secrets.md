# GitHub Environments and Secrets

The application repository uses three GitHub Environments:

- `DEV`
- `TEST`
- `PROD`

These environments were created in `yazicigurkan/banking-dotnet-payment-api`.

## Required Environment Secrets

Set these secrets on each environment before running real pipelines:

- `NUGET_USERNAME`
- `NUGET_PASSWORD`
- `SONAR_HOST_URL`
- `SONAR_TOKEN`
- `GRAPHNODE_BASE_URL`
- `GRAPHNODE_TOKEN`
- `NEXUS_BASE_URL`
- `NEXUS_USERNAME`
- `NEXUS_PASSWORD`
- `HARBOR_REGISTRY`
- `HARBOR_USERNAME`
- `HARBOR_PASSWORD`
- `TWISTLOCK_CONSOLE_URL`
- `TWISTLOCK_USER`
- `TWISTLOCK_PASSWORD`
- `JIRA_BASE_URL`
- `JIRA_USER_EMAIL`
- `JIRA_API_TOKEN`
- `KUBE_CONFIG`
- `WINDOWS_DEPLOY_USERNAME`
- `WINDOWS_DEPLOY_PASSWORD`

## Setting Secrets With GitHub CLI

Example:

```bash
gh secret set SONAR_HOST_URL --repo yazicigurkan/banking-dotnet-payment-api --env DEV
gh secret set SONAR_TOKEN --repo yazicigurkan/banking-dotnet-payment-api --env DEV
```

Repeat for `TEST` and `PROD` with environment-specific values.

## Readiness Check

The sample application includes `Secret Readiness Check`.

Run it from GitHub Actions with a target environment:

```bash
gh workflow run "Secret Readiness Check" \
  --repo yazicigurkan/banking-dotnet-payment-api \
  --ref main \
  -f target_environment=DEV
```

The workflow prints only `present` or `missing`; it never prints secret values.

## PROD Protection

For a real bank setup, configure the `PROD` environment with:

- Required reviewers from a DevOps or release manager group
- Optional wait timer aligned with change window practice
- Environment-specific secrets only available after approval

For this personal test repository, reviewer protection is intentionally not enforced yet so smoke tests can run without blocking on self-approval behavior.
