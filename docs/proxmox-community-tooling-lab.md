# Proxmox Community Tooling Lab

This lab provides self-hosted community/open-source equivalents for the bank DevSecOps pipeline platform.

## Tool Mapping

| Enterprise target | Lab/community tool | Purpose | Notes |
| --- | --- | --- | --- |
| Jira | OpenProject Community | SDLC/change ticketing | Used until Jira is available. Work package status can model SDLC gates. |
| Nexus | Sonatype Nexus Repository Community Edition | NuGet proxy and artifact repository | Use as dependency proxy and release artifact repository. |
| SonarQube | SonarQube Community Build | Code quality and Quality Gate | Branch/PR analysis capabilities differ by edition; validate exact needs before production. |
| GraphNode SAST | Semgrep Community Edition | SAST substitute | CLI-based in this lab. A small HTTP wrapper can be added if we want GraphNode-like API behavior. |
| Harbor | Harbor | Container registry | Installed with the built-in Trivy adapter. |
| Twistlock | Trivy | Container/image vulnerability scanning | Used as the lab substitute for image policy checks. |

## Proxmox LXC Inventory

| VMID | Hostname | IP | Service | URL |
| --- | --- | --- | --- | --- |
| 110 | openproject | 192.168.18.50 | OpenProject | http://192.168.18.50 |
| 111 | nexus | 192.168.18.51 | Nexus Repository | http://192.168.18.51:8081 |
| 112 | sonarqube | 192.168.18.52 | SonarQube | http://192.168.18.52:9000 |
| 113 | harbor | 192.168.18.53 | Harbor + Trivy adapter | http://192.168.18.53 |
| 114 | security-tools | 192.168.18.54 | Semgrep + Trivy CLI runners | CLI only |

The `security-tools` container also hosts:

- GitHub Actions self-hosted runner for `yazicigurkan/banking-dotnet-payment-api`
- k3s single-node Kubernetes lab cluster
- GraphNode-compatible lab API on `http://192.168.18.54:8080`
- `twistcli` shim that executes Trivy and emits Twistlock-like JSON

## Runtime Model

All services run in separate Debian 12 LXC containers with Docker Engine and Docker Compose.

Docker-in-LXC requires the following LXC settings:

```text
features: nesting=1,keyctl=1
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.mount.auto: proc:rw sys:rw
```

SonarQube also requires this host-level sysctl:

```text
vm.max_map_count=262144
```

## Initial Access

Do not store generated passwords in Git.

OpenProject:

```bash
# Default first login is normally admin/admin, then force-change on first login.
open http://192.168.18.50
```

Nexus:

```bash
ssh root@192.168.18.2 "pct exec 111 -- docker exec nexus cat /nexus-data/admin.password"
```

SonarQube:

```bash
# Default first login is admin/admin, then force-change on first login.
open http://192.168.18.52:9000
```

Harbor:

```bash
# Username: admin
ssh root@192.168.18.2 "pct exec 113 -- cat /root/harbor-admin-password.txt"
```

Security tools:

```bash
ssh root@192.168.18.2 "pct exec 114 -- /opt/security-tools/run-smoke.sh"
```

## Configured Lab Resources

Nexus repositories:

| Repository | Format | Type | Purpose |
| --- | --- | --- | --- |
| `nuget-proxy` | NuGet | proxy | NuGet dependency proxy to nuget.org |
| `dotnet-releases` | raw | hosted | Versioned .NET zip artifacts |
| `release-evidence` | raw | hosted | Release manifest and evidence files |

Harbor resources:

| Resource | Value |
| --- | --- |
| Project | `payment` |
| Scan on push | Enabled through project metadata |
| Scanner | Harbor Trivy adapter |
| Lab registry URL | `192.168.18.53` |

SonarQube resources:

| Resource | Value |
| --- | --- |
| Project key | `payment-api` |
| Token | Stored on the Sonar LXC under `/root/devsecops-secrets/sonar-github-actions-token` |

OpenProject resources:

| Resource | Value |
| --- | --- |
| Project | `devsecops-sdlc` |
| Work package type | `SDLC Change` |
| SDLC statuses | Jira-equivalent Turkish status list |
| API token | Stored on the OpenProject LXC under `/root/devsecops-secrets/openproject-api-token` |

## Pipeline Endpoint Mapping

Use these as GitHub Environment secrets or organization-level variables:

| Pipeline variable/secret | Lab value |
| --- | --- |
| `OPENPROJECT_BASE_URL` or `JIRA_BASE_URL` | `http://192.168.18.50` |
| `NEXUS_URL` | `http://192.168.18.51:8081` |
| `SONAR_HOST_URL` | `http://192.168.18.52:9000` |
| `HARBOR_REGISTRY` | `192.168.18.53` |
| `HARBOR_PROJECT` | `payment` |
| `TWISTLOCK_URL` | Replace with Trivy/Harbor scanner integration in lab |
| `GRAPHNODE_URL` | Replace with Semgrep wrapper API, or run Semgrep CLI |

In this lab, set:

| Pipeline secret | Lab value |
| --- | --- |
| `GRAPHNODE_BASE_URL` | `http://192.168.18.54:8080` |
| `TWISTLOCK_CONSOLE_URL` | `http://192.168.18.54:8080` |
| `TWISTLOCK_USER` | `trivy-lab` |
| `TWISTLOCK_PASSWORD` | `trivy-lab` |

The `twistcli` command is provided by `/usr/local/bin/twistcli` on the runner host and delegates image scanning to Trivy.

## GitHub Runner

The lab runner is registered to the application repository:

```text
Repository: yazicigurkan/banking-dotnet-payment-api
Runner: proxmox-security-tools-114
Labels: self-hosted, linux, k8s, devsecops-lab
```

The runner has direct network access to the lab services and can deploy to the local k3s cluster.

## k3s Lab Cluster

k3s runs inside CT `114`.

```bash
ssh root@192.168.18.2 "pct exec 114 -- kubectl get nodes"
ssh root@192.168.18.2 "pct exec 114 -- kubectl get pods -A"
```

The application repository stores `KUBE_CONFIG` as a base64-encoded GitHub secret. The lab kubeconfig points to `127.0.0.1:6443`, which is correct because deployment jobs run on the same self-hosted runner.

Harbor is HTTP-only in the lab, so Docker and k3s containerd are configured with `192.168.18.53` as an insecure registry. Production must use TLS.

## Next Configuration Tasks

1. OpenProject: create SDLC workflow statuses equivalent to Jira statuses.
2. Nexus: create a least-privilege service account instead of using `admin`.
3. SonarQube: tune Quality Gate thresholds after the first real scan.
4. Harbor: add immutable tag rules for `*-TEST-*` and `*-PROD-*`.
5. OpenProject: map real workflow transitions and approvals.
6. GitHub: move from broad repo-level secrets to stricter environment-only access after workflow hardening.

## Production Notes

This lab is useful for pipeline validation, but production should add TLS, DNS names, backups, external identity integration, network segmentation, monitored storage, and formal account lifecycle controls.
