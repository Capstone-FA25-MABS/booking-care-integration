# EC2 Database Restore Guide

Hướng dẫn chi tiết restore databases từ backup local lên EC2.

## 📋 Tổng Quan Quy Trình

```
Local Backup → Transfer to EC2 → Extract → Restore → Verify
```

**Thời gian ước tính**: 10-15 phút

---

## 🎯 Bước 1: Chuẩn Bị Backup Trên Local

### 1.1. Tạo Backup (Nếu Chưa Có)

```bash
cd ~/Documents/capstone-src/booking-care-integration/scripts
./backup-databases.sh
```

**Kết quả:** File archive tại `backups/databases/YYYYMMDD_HHMMSS_databases.tar.gz` (~5MB)

### 1.2. Kiểm Tra Backup

```bash
# List backup files
ls -lh backups/databases/*.tar.gz

# Check latest backup
ls -lt backups/databases/*.tar.gz | head -1
```

Lưu ý **timestamp** của backup mới nhất (ví dụ: `20251213_081030`)

---

## 🚀 Bước 2: Transfer Backup Lên EC2

### Option A: Sử dụng SCP (Khuyến nghị)

```bash
# Set EC2 details
EC2_IP="your-ec2-public-ip"
EC2_KEY="/path/to/your-key.pem"
BACKUP_FILE="backups/databases/20251213_081030_databases.tar.gz"

# Transfer to EC2
scp -i "${EC2_KEY}" \
    "${BACKUP_FILE}" \
    ubuntu@${EC2_IP}:~/backup.tar.gz
```

**Thời gian**: ~10-30 giây (tùy network speed)

### Option B: Sử dụng Rsync (Cho transfer lớn)

```bash
rsync -avz --progress \
    -e "ssh -i ${EC2_KEY}" \
    "${BACKUP_FILE}" \
    ubuntu@${EC2_IP}:~/backup.tar.gz
```

### Verify Transfer

```bash
# SSH vào EC2 và check file
ssh -i "${EC2_KEY}" ubuntu@${EC2_IP} "ls -lh ~/backup.tar.gz"
```

**Kỳ vọng**: File ~5MB xuất hiện trên EC2

---

## 🔧 Bước 3: Chuẩn Bị EC2 Environment

### 3.1. SSH Vào EC2

```bash
ssh -i "${EC2_KEY}" ubuntu@${EC2_IP}
```

### 3.2. Navigate Đến Project Directory

```bash
cd ~/booking-care-integration
```

### 3.3. Đảm Bảo Containers Đang Chạy

```bash
# Check container status
docker ps | grep -E "sqlserver|mongodb|redis|rabbitmq"

# Nếu chưa chạy, start containers
docker-compose up -d

# Wait for containers to be healthy
sleep 30
```

**Quan trọng**: Tất cả database containers phải đang chạy trước khi restore

---

## 📦 Bước 4: Extract Backup Archive

```bash
# Create restore directory
mkdir -p ~/restore-temp

# Extract archive
cd ~/restore-temp
tar xzf ~/backup.tar.gz

# Verify extraction
ls -lh
```

**Kỳ vọng**: Thấy folder với timestamp (ví dụ: `20251213_081030/`)

---

## 🔄 Bước 5: Restore Databases

### 5.1. Run Restore Script

```bash
cd ~/booking-care-integration/scripts

# Run restore với absolute path
./restore-databases.sh ~/restore-temp/20251213_081030
```

### 5.2. Xác Nhận Restore

Script sẽ hỏi xác nhận:
```
This will restore databases from the backup. Continue? (y/N)
```

Nhập `y` và Enter.

### 5.3. Theo Dõi Progress

Script sẽ hiển thị:
```
[INFO] Starting database restore process...

[INFO] Restoring MongoDB...
[SUCCESS] MongoDB restored

[INFO] Restoring Redis...
[SUCCESS] Redis restored

[INFO] Restoring RabbitMQ definitions...
[SUCCESS] RabbitMQ definitions restored

[INFO] Restoring SQL Server: MABS_Discount
[INFO] Stopping bookingcare_sqlserver_discount...
[INFO] Starting bookingcare_sqlserver_discount...
[SUCCESS] SQL Server MABS_Discount data files restored

... (11 SQL Server databases total)

════════════════════════════════════════════
[SUCCESS] DATABASE RESTORE COMPLETED
════════════════════════════════════════════
Databases Restored: 14
Failed Restores: 0
════════════════════════════════════════════
```

**Thời gian**: 3-5 phút (tùy số lượng databases)

---

## ✅ Bước 6: Verify Data Sau Khi Restore

### 6.1. Check MongoDB Data

```bash
# Count documents in MongoDB
docker exec bookingcare_mongodb mongosh \
    -u bookingcare \
    -p password123 \
    --authenticationDatabase admin \
    --quiet \
    --eval "
        db = db.getSiblingDB('MABS_Notification');
        print('Notifications:', db.notifications.countDocuments());
        db = db.getSiblingDB('MABS_Communication');
        print('Messages:', db.Messages.countDocuments());
        db = db.getSiblingDB('MABS_Favorites');
        print('Favorites:', db.favorites.countDocuments());
    "
```

**Kỳ vọng**: Thấy số lượng documents đúng với local backup

### 6.2. Check Redis Data

```bash
# Check Redis keys
docker exec bookingcare_redis redis-cli DBSIZE
```

### 6.3. Check RabbitMQ

```bash
# Check RabbitMQ queues
docker exec bookingcare_rabbitmq rabbitmqctl list_queues
```

### 6.4. Check SQL Server Databases

```bash
# List all databases (sử dụng mongosh vì không có sqlcmd)
# Alternative: Check từ application logs

# Kiểm tra xem các databases đã attach chưa
docker logs bookingcare_sqlserver_user 2>&1 | grep -i "database.*started"
docker logs bookingcare_sqlserver_discount 2>&1 | grep -i "database.*started"

# Hoặc check từ application services
docker logs bookingcare_user_service 2>&1 | grep -i "database" | tail -5
```

**Kỳ vọng**: Databases tự động attach và services connect thành công

### 6.5. Test Via Application

```bash
# Check services health
docker ps --filter "name=bookingcare" --format "table {{.Names}}\t{{.Status}}"

# Check API Gateway logs
docker logs bookingcare_api_gateway --tail 50

# Test API endpoint
curl -X GET http://localhost:5000/health
```

---

## 🔍 Troubleshooting

### Vấn Đề 1: SQL Server Không Attach Databases

**Triệu chứng**: Container chạy nhưng databases không xuất hiện

**Nguyên nhân**: Data files không được copied đúng khi container đang stop

**Giải pháp**:

```bash
# Method 1: Use docker volume để copy files
docker stop bookingcare_sqlserver_user
docker volume ls | grep sqlserver_user
# Copy files trực tiếp vào volume

# Method 2: Use EF Core migrations (Khuyến nghị)
# Để services tự tạo databases từ migrations
cd ~/BookingCareSystemBackend
docker-compose restart user_service
docker logs -f user_service
# Database sẽ được tạo tự động từ EF Core migrations
```

### Vấn Đề 2: MongoDB Restore Failed - Authentication Error

**Triệu chứng**: `Authentication failed`

**Giải pháp**:
```bash
# Check MongoDB credentials trong .env
cat ~/booking-care-integration/.env | grep MONGO

# Verify credentials
docker exec bookingcare_mongodb mongosh \
    -u bookingcare -p password123 \
    --authenticationDatabase admin \
    --eval "db.adminCommand('ping')"
```

### Vấn Đề 3: Containers Not Running

**Triệu chứng**: Restore script báo lỗi "container not found"

**Giải pháp**:
```bash
# Start all containers
cd ~/booking-care-integration
docker-compose up -d

# Wait for healthy status
docker ps --format "table {{.Names}}\t{{.Status}}" | grep bookingcare

# Check logs nếu container restart liên tục
docker logs bookingcare_sqlserver_user --tail 50
```

### Vấn Đề 4: Disk Space Full

**Triệu chứng**: `No space left on device`

**Giải pháp**:
```bash
# Check disk space
df -h

# Clean up Docker
docker system prune -a --volumes -f

# Remove old backups
rm -rf ~/restore-temp
rm ~/backup.tar.gz
```

---

## 🎯 Alternative Method: Sử Dụng EF Core Migrations

Nếu restore data files gặp vấn đề, khuyến nghị sử dụng **EF Core migrations** để tạo schema:

### Ưu Điểm
- ✅ Không cần backup/restore phức tạp
- ✅ Schema được version control
- ✅ Tự động chạy khi service start
- ✅ Luôn sync với code

### Steps

```bash
# 1. Đảm bảo không có backup data files
cd ~/booking-care-integration
docker-compose down -v  # Remove all volumes

# 2. Start containers fresh
docker-compose up -d

# 3. Services sẽ tự động:
#    - Chạy EF Core migrations
#    - Tạo tables
#    - Seed initial data (nếu có)

# 4. Check migration logs
docker logs bookingcare_user_service 2>&1 | grep -i migration
docker logs bookingcare_discount_service 2>&1 | grep -i migration
```

### Import Mock Data Sau Migrations

```bash
# Nếu cần import mock data sau khi migrations tạo schema:

# MongoDB: Use mongorestore cho collections
docker exec bookingcare_mongodb mongorestore \
    -u bookingcare -p password123 \
    --authenticationDatabase admin \
    --drop \
    /path/to/mongodb_backup

# SQL Server: Use custom import scripts
# (Create SQL scripts to INSERT mock data)
```

---

## 📊 Backup/Restore Best Practices

### For Development/Staging
✅ **Khuyến nghị**: EF Core Migrations + Seed Data
- Schema từ migrations
- Mock data từ seed scripts
- Fast và reliable

### For Production Data Migration
✅ **Khuyến nghị**: Native backup tools
- MongoDB: mongodump/mongorestore
- SQL Server: Data files hoặc .bak (nếu có sqlcmd)
- Redis: RDB snapshots

### Scheduled Backups on EC2
```bash
# Create cron job cho automated backups
crontab -e

# Add line (backup daily at 2 AM):
0 2 * * * cd /home/ubuntu/booking-care-integration/scripts && ./backup-databases.sh
```

---

## 📝 Quick Reference Commands

```bash
# ===================
# LOCAL BACKUP
# ===================
cd ~/Documents/capstone-src/booking-care-integration/scripts
./backup-databases.sh

# ===================
# TRANSFER TO EC2
# ===================
scp -i key.pem backups/databases/TIMESTAMP_databases.tar.gz ubuntu@EC2_IP:~/backup.tar.gz

# ===================
# EC2 RESTORE
# ===================
ssh -i key.pem ubuntu@EC2_IP
mkdir -p ~/restore-temp
tar xzf ~/backup.tar.gz -C ~/restore-temp
cd ~/booking-care-integration/scripts
./restore-databases.sh ~/restore-temp/TIMESTAMP

# ===================
# VERIFY
# ===================
docker exec bookingcare_mongodb mongosh -u bookingcare -p password123 --eval "db.adminCommand('listDatabases')"
docker ps | grep bookingcare
curl http://localhost:5000/health

# ===================
# CLEANUP
# ===================
rm -rf ~/restore-temp ~/backup.tar.gz
```

---

## ⚠️ Important Notes

1. **SQL Server Data Files Restore** có thể không reliable 100% do:
   - Container cần stop để copy files
   - Files có thể bị locked
   - Permissions issues

2. **Khuyến nghị cho Production**:
   - Sử dụng EF Core Migrations cho schema
   - Manual seed scripts cho critical data
   - Automated backup cho production data
   - Test restore procedure thường xuyên

3. **Data Consistency**:
   - Backup tất cả databases cùng lúc để đảm bảo consistency
   - Stop services trước khi backup để tránh in-flight transactions
   - Test restore trên staging trước khi restore production

---

## 🎉 Success Checklist

- [ ] Backup file đã transfer lên EC2
- [ ] Extract backup archive thành công
- [ ] Restore script chạy không lỗi
- [ ] MongoDB có data (check countDocuments)
- [ ] Redis có keys (check DBSIZE)
- [ ] RabbitMQ có queues
- [ ] SQL Server databases đã attach
- [ ] Application services start thành công
- [ ] API endpoints trả về data đúng
- [ ] Logs không có database connection errors

**Restore thành công!** 🚀
