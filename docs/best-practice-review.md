# Best Practice Review

This document records the hardening decisions made after the OpenProject driven TEST/PROD lab run.

## Findings Fixed

| Area | Finding | Risk | Fix |
| --- | --- | --- | --- |
| Release versioning | TEST/PROD artifact and image tags included environment, SHA and run number. | PROD identity was noisy and not the business-approved release version. | TEST/PROD now use the OpenProject release version directly, for example `v1.1.1`. DEV keeps ephemeral `payment-api-DEV-<short_sha>-<run_number>`. |
| Release input validation | `release_version` was accepted as a raw string. | Invalid Docker tags, Nexus paths or accidental wrong release names could pass into promotion. | TEST/PROD input guards validate a SemVer-like, Docker/Nexus-safe value. |
| Target environment binding | Jira/OpenProject validation checked status and approvals but not whether the issue was raised for TEST or PROD. | A PROD-oriented issue could be accidentally routed through TEST if a human clicked the wrong trigger. | Jira validation now requires the issue target environment field to match the pipeline target environment. |
| PROD promotion | Governance validated the manifest but did not enforce artifact/image tag equality with the approved release version. | A manifest could point to a different artifact or image tag while keeping the same release field. | PROD governance now requires `artifactVersion == release_version` and Kubernetes `imageTag == release_version`. |
| Deployment concurrency | Multiple deploys for the same application/environment could overlap. | GitOps commits, Argo CD sync and deployment evidence could race. | Orchestration workflows now serialize by repository, application and target environment. |
| Kubernetes image identity | Helm chart stored digest values but rendered only `repository:tag`. | Runtime did not actually consume the immutable digest evidence. | Chart renders `repository:tag@digest` when a digest is available. |
| Mutable chart default | Chart default used `latest`. | Accidental installs could deploy a mutable image. | Default tag is now an explicit placeholder and environment values must provide the real tag. |
| Platform validation | Shell validation used `xargs`, which can fail with large file sets. | CI validation was brittle. | Validation now iterates scripts safely with `find -print0` and a loop. |
| Credential handling docs | Lab docs encouraged printing product credentials. | Secrets could be copied into logs or tickets. | Docs now prefer piping credentials directly into GitHub Environment secrets. |

## Remaining Production Requirements

- Replace the lab OpenProject Jira-compatible adapter with a supported Jira/OpenProject integration service owned as production code, with authentication, structured logs, tests and HA.
- Replace lab admin credentials with least-privilege service accounts for Nexus, Harbor, SonarQube, OpenProject/Jira and Kubernetes.
- Enforce Harbor immutable tag policy for `v*` release tags and configure retention for `*-DEV-*` tags.
- Add branch protection and required checks for the pipeline platform repository before publishing new platform tags.
- Move from broad `secrets: inherit` to explicit secret contracts as the next compatibility-breaking platform release.
