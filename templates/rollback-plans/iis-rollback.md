# IIS Rollback Plan

1. Jira rollback approval is confirmed.
2. Stop affected IIS app pool.
3. Restore last backup from `D:\Backups\<ApplicationName>\<Timestamp>`.
4. Start app pool.
5. Run health check.
6. Add rollback evidence to Jira.
