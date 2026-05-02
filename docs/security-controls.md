# Security Controls

- SonarQube Quality Gate fail olursa pipeline durur.
- GraphNode critical her ortamda fail eder; high TEST/PROD icin fail eder.
- Twistlock critical/high policy ihlali image push veya deploy oncesi fail eder.
- PROD rebuild yasaktir; release manifest dogrulanir.
- PROD promotion sadece Nexus `release-evidence` manifest'i SonarQube, GraphNode ve Twistlock kontrollerinden gectiyse calisir.
- GraphNode ve Twistlock severity count degerleri manifest'e yazilir; sadece loglarda birakilmaz.
- PROD secret'lari GitHub PROD environment altinda tutulur.
- Self-hosted runner erisimleri ortam bazinda segmente edilir.
