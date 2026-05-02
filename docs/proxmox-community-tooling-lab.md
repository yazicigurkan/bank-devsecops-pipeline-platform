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

## Next Configuration Tasks

1. OpenProject: create SDLC workflow statuses equivalent to Jira statuses.
2. Nexus: create NuGet proxy, hosted release repository, and service account.
3. SonarQube: create a token and Quality Gate.
4. Harbor: create project `payment`, enable vulnerability scanning, and set tag immutability rules.
5. security-tools: add a small Semgrep HTTP wrapper if pipeline compatibility with GraphNode endpoints is required.
6. GitHub: add environment-level secrets for DEV, TEST, and PROD.

## Production Notes

This lab is useful for pipeline validation, but production should add TLS, DNS names, backups, external identity integration, network segmentation, monitored storage, and formal account lifecycle controls.
