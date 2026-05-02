# GitHub Test Plan

This plan validates the platform safely before real bank integrations are connected.

## Completed Test Layers

1. `actionlint` validates workflow syntax and common GitHub Actions mistakes.
2. `platform validation` runs YAML, shell, JSON and local SDLC dry-run checks in the platform repository.
3. `Reusable Workflow Smoke Test` proves the application repository can call a private reusable workflow from the platform repository.
4. `SDLC Dry Run` proves positive and negative release governance behavior without external systems.
5. `Environment Smoke Test` proves GitHub Environment routing for `DEV`, `TEST` and `PROD`.

## Next Integration Gates

1. Add repository and environment secrets.
2. Register self-hosted runner labels: `self-hosted`, `linux`, `k8s`, `windows`, `iis`.
3. Test DEV with mock/non-production endpoints.
4. Test TEST with a real Jira issue in an approved status.
5. Test PROD only after release evidence is produced by TEST.

## Current Limitation

Real deployment workflows still require bank network access and secrets for Jira, Nexus, SonarQube, GraphNode, Harbor, Twistlock, Kubernetes and IIS.
