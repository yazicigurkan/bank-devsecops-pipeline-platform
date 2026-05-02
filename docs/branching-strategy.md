# Branching Strategy

| Branch | Environment | Rule |
| --- | --- | --- |
| DEV | DEV | Push sonrasi otomatik CI/CD |
| TEST | TEST | Jira SDLC talebi ile deploy |
| PROD | PROD | Jira SDLC + GitHub environment approval |

PROD branch build icin degil, onayli release durumunu temsil etmek icin kullanilir.

