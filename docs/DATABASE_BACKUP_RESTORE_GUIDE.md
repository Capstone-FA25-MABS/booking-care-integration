# Database Backup & Restore Guide

Hướng dẫn chi tiết backup database từ local và restore lên EC2.

## 📋 Tổng Quan

Hướng dẫn này giúp bạn:
1. Backup toàn bộ databases từ local (với tables + data)
2. Transfer backup lên EC2
3. Restore databases trên EC2
4. Verify data đã restore đúng

---

## 🔧 Phần 1: Backup Database Trên Local

### 1.1. Đảm Bảo Containers Đang Chạy

```bash
# Di chuyển vào thư mục BookingCareSystemBackend
cd ~/Documents/capstone-src/BookingCareSystemBackend

# Kiểm tra containers
docker-compose ps | grep -E "sqlserver|mongodb"

# Nếu chưa chạy, start containers
docker-compose up -d
```

### 1.2. Verify Databases Có Data

```bash
# Check SQL Server User database
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P 'SA_PASSWORD_HERE' \
    -Q "USE MABS_User; SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"

# Check MongoDB
docker exec bookingcare_mongodb mongosh \
    -u admin -p 'MONGO_PASSWORD_HERE' \
    --authenticationDatabase admin \
    --eval "db.getMongo().getDBNames()"
```

**Kỳ vọng:** Phải thấy list tables/collections, không phải empty.

### 1.3. Run Backup Script

```bash
# Di chuyển vào thư mục integration
cd ~/Documents/capstone-src/booking-care-integration/scripts

# Create backup directory nếu chưa có
mkdir -p backups/databases

# Run backup
./backup-databases.sh

# Output sẽ hiển thị progress
```

**Output mẫu:**
```
[INFO] Starting database backup...
[INFO] Backup directory: ./backups/databases/20251213_143000
[INFO] Backing up SQL Server databases...
[SUCCESS] Backed up MABS_User to MABS_User.bak
[SUCCESS] Backed up MABS_Auth to MABS_Auth.bak
...
[SUCCESS] Backup completed successfully!
[INFO] Backup location: ./backups/databases/20251213_143000
```

### 1.4. Verify Backup Files

```bash
# Check backup directory
ls -lh backups/databases/

# Check latest backup
LATEST_BACKUP=$(ls -t backups/databases/ | head -1)
echo "Latest backup: $LATEST_BACKUP"

# List files trong backup
ls -lh backups/databases/$LATEST_BACKUP/

# Kỳ vọng thấy các files .bak
# - MABS_User.bak
# - MABS_Auth.bak
# - MABS_Doctor.bak
# - MABS_Hospital.bak
# - MABS_Appointment.bak
# - MABS_Schedule.bak
# - MABS_Payment.bak
# - MABS_Discount.bak
# - MABS_ServiceMedical.bak
# - MABS_Saga.bak
# - MABS_AI.bak
# - mongodb_dump/ (nếu có)
```

### 1.5. Test Restore Trên Local (Optional - để verify)

```bash
# Tạo test database để verify backup hoạt động
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P 'SA_PASSWORD_HERE' \
    -Q "CREATE DATABASE MABS_User_Test"

# Copy backup file vào container
docker cp backups/databases/$LATEST_BACKUP/MABS_User.bak \
    bookingcare_sqlserver_user:/var/opt/mssql/backup/

# Restore test
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P 'SA_PASSWORD_HERE' \
    -Q "RESTORE DATABASE MABS_User_Test FROM DISK='/var/opt/mssql/backup/MABS_User.bak' WITH MOVE 'MABS_User' TO '/var/opt/mssql/data/MABS_User_Test.mdf', MOVE 'MABS_User_log' TO '/var/opt/mssql/data/MABS_User_Test_log.ldf', REPLACE"

# Verify tables
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P 'SA_PASSWORD_HERE' \
    -Q "USE MABS_User_Test; SELECT COUNT(*) AS TableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"

# Nếu thành công, cleanup
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P 'SA_PASSWORD_HERE' \
    -Q "DROP DATABASE MABS_User_Test"
```

---

## 📤 Phần 2: Transfer Backup Lên EC2

### 2.1. Archive Backup (Optional - để transfer nhanh hơn)

```bash
cd ~/Documents/capstone-src/booking-care-integration/scripts/backups/databases

# Get latest backup folder
LATEST_BACKUP=$(ls -t | head -1)
echo "Archiving: $LATEST_BACKUP"

# Create tar.gz archive
tar czf ${LATEST_BACKUP}.tar.gz ${LATEST_BACKUP}/

# Check size
ls -lh ${LATEST_BACKUP}.tar.gz
```

### 2.2. Transfer Sang EC2

**Option 1: Transfer archive (Khuyến nghị - nhanh hơn)**

```bash
# Set EC2 IP
export EC2_IP=13.213.141.45

# Get backup name
BACKUP_DATE=$(ls -t backups/databases/ | head -1 | sed 's/.tar.gz//')

# Transfer
scp -i ~/.ssh/bookingcare-key.pem \
    backups/databases/${BACKUP_DATE}.tar.gz \
    ubuntu@$EC2_IP:/home/ubuntu/booking-care-integration/scripts/backups/databases/

# Hoặc dùng rsync (có progress bar)
rsync -avz --progress \
    -e "ssh -i ~/.ssh/bookingcare-key.pem" \
    backups/databases/${BACKUP_DATE}.tar.gz \
    ubuntu@$EC2_IP:/home/ubuntu/booking-care-integration/scripts/backups/databases/
```

**Option 2: Transfer directory trực tiếp**

```bash
scp -i ~/.ssh/bookingcare-key.pem -r \
    backups/databases/${BACKUP_DATE} \
    ubuntu@$EC2_IP:/home/ubuntu/booking-care-integration/scripts/backups/databases/
```

### 2.3. Verify Transfer Trên EC2

**SSH vào EC2:**

```bash
ssh ubuntu@$EC2_IP
```

**Check files:**

```bash
cd ~/booking-care-integration/scripts/backups/databases

# List backups
ls -lh

# Nếu transfer archive, extract
BACKUP_DATE=20251213_143000  # Thay bằng tên backup của bạn
tar xzf ${BACKUP_DATE}.tar.gz

# Verify extracted files
ls -lh ${BACKUP_DATE}/

# Phải thấy tất cả .bak files
ls ${BACKUP_DATE}/*.bak
```

---

## 🔄 Phần 3: Restore Database Trên EC2

### 3.1. Prepare Environment

```bash
cd ~/booking-care-integration

# Verify .env file đã setup đúng
cat .env | grep -E "SQLSERVER|MONGO"

# Đảm bảo passwords trong .env khớp với khi backup
```

### 3.2. Start SQL Server Instances

```bash
# Start tất cả SQL Server instances
docker-compose up -d \
    sqlserver-discount \
    sqlserver-saga \
    sqlserver-user \
    sqlserver-doctor \
    sqlserver-auth \
    sqlserver-appointment \
    sqlserver-hospital \
    sqlserver-schedule \
    sqlserver-payment \
    sqlserver-servicemedical \
    sqlserver-ai

# Start MongoDB
docker-compose up -d mongodb

# Đợi containers ready (30-60 giây)
sleep 30

# Verify containers healthy
docker-compose ps | grep -E "sqlserver|mongodb"
```

### 3.3. Run Restore Script

```bash
cd ~/booking-care-integration/scripts

# Set backup date
BACKUP_DATE=20251213_143000  # Thay bằng backup của bạn

# Run restore
./restore-databases.sh backups/databases/${BACKUP_DATE}

# Script sẽ hỏi confirmation
# Type: y
```

**Script sẽ:**
1. Copy .bak files vào containers
2. Create databases nếu chưa có
3. Restore từ .bak files
4. Verify tables đã được restore

**Output mẫu:**
```
[INFO] Starting database restore...
[INFO] Restoring SQL Server databases...
[INFO] Copying MABS_User.bak to container...
[SUCCESS] Restored MABS_User (45 tables, 1523 rows)
[INFO] Copying MABS_Auth.bak to container...
[SUCCESS] Restored MABS_Auth (12 tables, 234 rows)
...
[SUCCESS] All databases restored successfully!
```

### 3.4. Verify Restore

```bash
# Check User database
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "${User@1234!}" \
    -Q "USE MABS_User; SELECT COUNT(*) AS TableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"

# Check có data không
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "${SQLSERVER_USER_PASSWORD}" \
    -Q "USE MABS_User; SELECT TOP 5 Id, Email FROM Users"

# Check Auth database
docker exec bookingcare_sqlserver_auth /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "${SQLSERVER_AUTH_PASSWORD}" \
    -Q "USE MABS_Auth; SELECT COUNT(*) AS TableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"

# Check MongoDB
docker exec bookingcare_mongodb mongosh \
    -u admin -p "${MONGO_INITDB_ROOT_PASSWORD}" \
    --authenticationDatabase admin \
    --eval "db.getMongo().getDBNames()"
```

**Kỳ vọng:**
- Mỗi database có nhiều tables (không phải 0)
- Có data trong tables chính (Users, Doctors, Hospitals, etc.)

---

## 🚀 Phần 4: Start Application Services

### 4.1. Start Tất Cả Services

```bash
cd ~/booking-care-integration

# Start all services
docker-compose up -d

# Monitor logs
docker-compose logs -f api-gateway auth-service user-service doctor-service
```

### 4.2. Services Sẽ KHÔNG Chạy Migration

Vì databases đã có đầy đủ tables từ backup, services sẽ:
- ✅ Connect tới databases
- ✅ Detect tables đã có sẵn
- ✅ Skip migration (hoặc detect no changes)
- ✅ Start bình thường

**Check logs:**

```bash
# Check auth service
docker-compose logs auth-service | grep -i "database"

# Không thấy "Creating database" hoặc "Running migrations"
# Chỉ thấy "Database connection successful"
```

### 4.3. Test API

```bash
# Test API Gateway
curl http://localhost:5001/health

# Test Auth API
curl http://localhost:6003/health

# Test User API  
curl http://localhost:6016/health

# Test với data từ database
curl http://localhost:5001/api/v1/servicetypes/all
```

---

## 🔍 Phần 5: Troubleshooting

### Lỗi: Restore Failed - Database Already Exists

```bash
# Drop database và restore lại
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "${SQLSERVER_USER_PASSWORD}" \
    -Q "DROP DATABASE IF EXISTS MABS_User"

# Run restore lại
./restore-databases.sh backups/databases/${BACKUP_DATE}
```

### Lỗi: Permission Denied Khi Restore

```bash
# Check container đang chạy
docker ps | grep sqlserver_user

# Restart container
docker-compose restart sqlserver-user

# Đợi 10s và retry
sleep 10
./restore-databases.sh backups/databases/${BACKUP_DATE}
```

### Lỗi: Cannot Open Backup Device

```bash
# Verify backup file exists trong container
docker exec bookingcare_sqlserver_user ls -l /var/opt/mssql/backup/

# Nếu không có, copy lại
docker cp backups/databases/${BACKUP_DATE}/MABS_User.bak \
    bookingcare_sqlserver_user:/var/opt/mssql/backup/
```

### Verify Tables Nhưng Không Có Data

```bash
# Check row counts
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "${SQLSERVER_USER_PASSWORD}" \
    -Q "USE MABS_User; SELECT t.name AS TableName, SUM(p.rows) AS RowCount FROM sys.tables t INNER JOIN sys.partitions p ON t.object_id = p.object_id WHERE p.index_id IN (0,1) GROUP BY t.name ORDER BY RowCount DESC"

# Nếu tất cả = 0, backup ban đầu không có data
# Cần re-backup từ local với data
```

---

## 📝 Phần 6: Best Practices

### 6.1. Scheduled Backups Trên EC2

```bash
# Tạo cron job để backup định kỳ
crontab -e

# Thêm dòng này (backup mỗi ngày lúc 2AM)
0 2 * * * cd /home/ubuntu/booking-care-integration/scripts && ./backup-databases.sh > /home/ubuntu/logs/backup.log 2>&1
```

### 6.2. Backup Retention

```bash
# Tạo script cleanup old backups (giữ 7 ngày gần nhất)
cat > ~/booking-care-integration/scripts/cleanup-old-backups.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/booking-care-integration/scripts/backups/databases"
find $BACKUP_DIR -name "20*" -type d -mtime +7 -exec rm -rf {} \;
echo "Cleaned up backups older than 7 days"
EOF

chmod +x ~/booking-care-integration/scripts/cleanup-old-backups.sh

# Add to cron (chạy mỗi ngày lúc 3AM)
0 3 * * * /home/ubuntu/booking-care-integration/scripts/cleanup-old-backups.sh
```

### 6.3. Monitoring Backup Status

```bash
# Check last backup
ls -lt ~/booking-care-integration/scripts/backups/databases/ | head -5

# Check backup size
du -sh ~/booking-care-integration/scripts/backups/databases/*

# Verify backup không corrupt
cd ~/booking-care-integration/scripts/backups/databases
LATEST=$(ls -t | head -1)
tar tzf ${LATEST}.tar.gz > /dev/null 2>&1 && echo "Backup OK" || echo "Backup CORRUPTED"
```

---

## 📊 Phần 7: Quick Reference Commands

### Backup Workflow (Local → EC2)

```bash
# 1. Local: Backup
cd ~/Documents/capstone-src/booking-care-integration/scripts
./backup-databases.sh
BACKUP_DATE=$(ls -t backups/databases/ | head -1)

# 2. Local: Transfer
scp -r backups/databases/${BACKUP_DATE} ubuntu@13.213.141.45:/home/ubuntu/booking-care-integration/scripts/backups/databases/

# 3. EC2: Restore
cd ~/booking-care-integration/scripts
./restore-databases.sh backups/databases/${BACKUP_DATE}

# 4. EC2: Start services
docker-compose up -d
```

### Quick Verify

```bash
# EC2: Check databases
for db in user auth doctor hospital appointment; do
    echo "=== ${db} database ==="
    docker exec bookingcare_sqlserver_${db} /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "${SQLSERVER_${db^^}_PASSWORD}" \
        -Q "USE MABS_${db^}; SELECT COUNT(*) AS Tables FROM INFORMATION_SCHEMA.TABLES"
done
```

---

## 🎯 Summary Checklist

**Trên Local:**
- [ ] Containers đang chạy
- [ ] Databases có tables + data
- [ ] Run `./backup-databases.sh` thành công
- [ ] Verify .bak files được tạo
- [ ] Transfer backup lên EC2

**Trên EC2:**
- [ ] Backup files đã transfer xong
- [ ] SQL Server containers đang chạy
- [ ] Run `./restore-databases.sh` thành công
- [ ] Verify tables đã có
- [ ] Verify data đã có
- [ ] Start services
- [ ] Test API endpoints

**Done! 🎉**

---

## 🆘 Support

Nếu gặp vấn đề:

1. Check logs: `docker-compose logs -f [service-name]`
2. Check container status: `docker-compose ps`
3. Check disk space: `df -h`
4. Check backup files: `ls -lh backups/databases/`
5. Re-run scripts với verbose: `bash -x ./backup-databases.sh`

---

**Last Updated:** 13 December 2025
