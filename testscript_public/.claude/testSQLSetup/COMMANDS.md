# SQL Server Docker - Quick Command Reference

## Container Management

### Start/Stop/Restart

```bash
# Start SQL Server container
docker compose up -d

# Stop SQL Server container
docker compose stop

# Restart SQL Server container
docker compose restart

# Stop and remove container (keeps data)
docker compose down

# Stop and remove container + volumes (DELETE ALL DATA!)
docker compose down -v
```

### View Logs

```bash
# Real-time logs
docker compose logs -f

# Last 100 lines
docker compose logs --tail=100

# Specific service logs
docker compose logs sqlserver
```

### Container Status

```bash
# List running containers
docker ps

# List all containers
docker ps -a

# Container stats (CPU, memory)
docker stats dams-sqlserver-dev

# Health check status
docker inspect --format='{{.State.Health.Status}}' dams-sqlserver-dev
```

## SQL Server Access

### Connect via sqlcmd (Inside Container)

```bash
# Interactive session
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!'

# Execute query
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "SELECT @@VERSION"

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -i /path/to/script.sql
```

### SSMS Connection

```
Server: localhost,1433
Authentication: SQL Server Authentication
Username: sa
Password: P@ssw0rd123!
```

### Connection String

```
Server=localhost,1433;User Id=sa;Password=P@ssw0rd123!;TrustServerCertificate=True;
```

## Database Operations

### Backup Database

```bash
# Using script
./backup-database.sh DAMSTest

# Using script with custom name
./backup-database.sh DAMSTest my_backup

# Manual backup
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "BACKUP DATABASE [DAMSTest] TO DISK='/var/opt/mssql/backup/DAMSTest.bak' WITH COMPRESSION;"
```

### Restore Database

```bash
# Using script
./restore-database.sh DAMSTest_20260126.bak DAMSTest

# Manual restore
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "RESTORE DATABASE [DAMSTest] FROM DISK='/var/opt/mssql/backup/DAMSTest.bak' WITH REPLACE;"
```

### List Databases

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "SELECT name, database_id, create_date FROM sys.databases;"
```

### Execute SQL Script

```bash
# Copy script to container
docker cp script.sql dams-sqlserver-dev:/tmp/script.sql

# Execute script
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -i /tmp/script.sql
```

## File Operations

### Copy Files To/From Container

```bash
# Copy file TO container
docker cp local-file.sql dams-sqlserver-dev:/tmp/

# Copy file FROM container
docker cp dams-sqlserver-dev:/var/opt/mssql/backup/backup.bak ./backups/

# Copy directory
docker cp ./scripts dams-sqlserver-dev:/scripts/
```

### List Files in Container

```bash
# List backups
docker exec dams-sqlserver-dev ls -lh /var/opt/mssql/backup/

# List data files
docker exec dams-sqlserver-dev ls -lh /var/opt/mssql/data/

# List logs
docker exec dams-sqlserver-dev ls -lh /var/opt/mssql/log/
```

## Maintenance

### Check Disk Space

```bash
# In container
docker exec dams-sqlserver-dev df -h

# On host
df -h
```

### Check Memory Usage

```bash
# Container stats
docker stats dams-sqlserver-dev --no-stream

# SQL Server memory
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "SELECT (physical_memory_in_use_kb/1024) AS memory_used_mb FROM sys.dm_os_process_memory;"
```

### Check Database Sizes

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "SELECT DB_NAME(database_id) AS DatabaseName, (SUM(size)*8/1024) AS SizeMB FROM sys.master_files GROUP BY database_id;"
```

### Update Statistics

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -d DAMSTest -Q "EXEC sp_updatestats;"
```

### Rebuild Indexes

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -d DAMSTest -Q "ALTER INDEX ALL ON dbo.TableName REBUILD;"
```

## Troubleshooting

### View Error Log

```bash
# Tail error log
docker exec dams-sqlserver-dev tail -f /var/opt/mssql/log/errorlog

# View entire error log
docker exec dams-sqlserver-dev cat /var/opt/mssql/log/errorlog
```

### Check Active Connections

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "SELECT DB_NAME(database_id) AS DatabaseName, COUNT(session_id) AS ConnectionCount FROM sys.dm_exec_sessions WHERE database_id > 0 GROUP BY database_id;"
```

### Check Blocking

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "SELECT blocking_session_id, session_id, wait_type, wait_time FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;"
```

### Restart SQL Server

```bash
# Restart container (gentle)
docker compose restart

# Force restart
docker compose stop && docker compose start
```

### Access Container Shell

```bash
# Bash shell
docker exec -it dams-sqlserver-dev bash

# As root user
docker exec -it --user root dams-sqlserver-dev bash
```

## Network

### Check Port Binding

```bash
# Check exposed ports
docker port dams-sqlserver-dev

# Check if port is listening
netstat -an | grep 1433

# Test connection (Windows)
Test-NetConnection -ComputerName localhost -Port 1433

# Test connection (Linux/macOS)
nc -zv localhost 1433
```

## Cleanup

### Remove Stopped Containers

```bash
docker container prune
```

### Remove Unused Volumes

```bash
docker volume prune
```

### Remove Unused Images

```bash
docker image prune
```

### Full Cleanup

```bash
# Remove everything (containers, volumes, networks, images)
docker system prune -a --volumes
```

## Backup/Restore Host Files

### Backup Data Directory

```bash
# Backup data directory
tar -czf dams-sqlserver-backup-$(date +%Y%m%d).tar.gz data/ logs/ backups/

# Restore data directory
tar -xzf dams-sqlserver-backup-20260126.tar.gz
```

### Full Container Backup

```bash
# Commit container to image
docker commit dams-sqlserver-dev dams-sqlserver-backup:$(date +%Y%m%d)

# Save image to file
docker save dams-sqlserver-backup:20260126 | gzip > dams-sqlserver-backup-20260126.tar.gz

# Load image from file
docker load < dams-sqlserver-backup-20260126.tar.gz
```

## Advanced Operations

### Inspect Container

```bash
# Full container details
docker inspect dams-sqlserver-dev

# Get IP address
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dams-sqlserver-dev

# Get volume mounts
docker inspect --format='{{json .Mounts}}' dams-sqlserver-dev | jq
```

### View Container Logs with Timestamps

```bash
docker compose logs -f --timestamps
```

### Follow Specific Log Pattern

```bash
docker compose logs -f | grep ERROR
docker compose logs -f | grep WARNING
```

### Execute Multiple Commands

```bash
docker exec dams-sqlserver-dev bash -c "cd /var/opt/mssql && ls -la && df -h"
```

## Quick Scripts

### Create Database

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "CREATE DATABASE [MyNewDB];"
```

### Drop Database

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -Q "DROP DATABASE [MyNewDB];"
```

### List All Tables

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -d DAMSTest -Q "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';"
```

### Get Row Counts

```bash
docker exec -it dams-sqlserver-dev /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'P@ssw0rd123!' -d DAMSTest -Q "SELECT OBJECT_NAME(object_id) AS TableName, SUM(row_count) AS RowCount FROM sys.dm_db_partition_stats WHERE index_id IN (0,1) GROUP BY object_id ORDER BY RowCount DESC;"
```

---

**For detailed documentation, see README.md**
