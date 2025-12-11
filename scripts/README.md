# BookingCare Backup & Deployment Scripts

Scripts để backup, restore và deploy hệ thống BookingCare lên EC2.

## 📋 Danh Sách Scripts

### 🔄 Backup & Restore Scripts

| Script | Mô Tả | Sử Dụng |
|--------|-------|---------|
| `backup-volumes.sh` | Backup toàn bộ Docker volumes | `./backup-volumes.sh [backup-dir]` |
| `backup-databases.sh` | Backup chuyên biệt cho databases (khuyến nghị) | `./backup-databases.sh [backup-dir]` |
| `restore-volumes.sh` | Restore volumes từ backup | `./restore-volumes.sh <backup-path>` |
| `restore-databases.sh` | Restore databases từ backup | `./restore-databases.sh <backup-path>` |
| `quick-backup.sh` | Backup tất cả (volumes + databases) | `./quick-backup.sh [backup-dir]` |

### 🚀 Deployment Scripts

| Script | Mô Tả | Sử Dụng |
|--------|-------|---------|
| `create-volumes.sh` | Tạo tất cả volumes cần thiết | `./create-volumes.sh` |
| `deploy-to-ec2.sh` | Deploy tự động lên EC2 | `./deploy-to-ec2.sh <ec2-host>` |

### 🔧 Build Scripts

| Script | Mô Tả | Sử Dụng |
|--------|-------|---------|
| `build-and-push-all.sh` | Build và push tất cả Docker images | `./build-and-push-all.sh` |

## 🚀 Quick Start

### 1️⃣ Backup Local Data

**Cách 1: Database Backup (Khuyến nghị - file nhỏ hơn)**
```bash
cd scripts
./backup-databases.sh
```

**Cách 2: Volume Backup (Nhanh hơn)**
```bash
cd scripts
./backup-volumes.sh
```

**Cách 3: Backup tất cả**
```bash
cd scripts
./quick-backup.sh
```

### 2️⃣ Deploy Lên EC2 (Tự Động)

**Đơn giản nhất - 1 lệnh:**
```bash
./deploy-to-ec2.sh ec2-user@your-ec2-ip database
```

Script sẽ tự động:
1. ✅ Backup data từ local
2. ✅ Transfer backup lên EC2
3. ✅ Cài đặt Docker (nếu chưa có)
4. ✅ Tạo volumes
5. ✅ Start infrastructure services
6. ✅ Restore data
7. ✅ Start application services

### 3️⃣ Deploy Lên EC2 (Thủ Công)

#### Bước 1: Backup trên local
```bash
./backup-databases.sh
```

#### Bước 2: Transfer lên EC2
```bash
# Sử dụng SCP
scp ./backups/databases/20241211_120000_databases.tar.gz \
    ec2-user@your-ec2-ip:/home/ec2-user/backups/

# Hoặc sử dụng rsync (nhanh hơn)
rsync -avz ./backups/databases/20241211_120000_databases.tar.gz \
    ec2-user@your-ec2-ip:/home/ec2-user/backups/
```

#### Bước 3: Setup trên EC2
```bash
# SSH vào EC2
ssh ec2-user@your-ec2-ip

# Clone/copy project
git clone <repo-url> ~/booking-care-integration
cd ~/booking-care-integration

# Copy .env file
nano .env  # Paste your .env content

# Tạo volumes
./scripts/create-volumes.sh

# Start infrastructure
docker-compose up -d rabbitmq redis mongodb \
    sqlserver-discount sqlserver-saga sqlserver-user \
    sqlserver-doctor sqlserver-auth sqlserver-appointment \
    sqlserver-hospital sqlserver-schedule sqlserver-payment \
    sqlserver-servicemedical sqlserver-ai

# Restore data
./scripts/restore-databases.sh /home/ec2-user/backups/20241211_120000

# Start all services
docker-compose up -d
```

## 📊 Output Locations

### Backup Outputs

```
backups/
├── volumes/
│   ├── 20241211_120000/
│   │   ├── bookingcaresystembackend_rabbitmq_data.tar.gz
│   │   ├── bookingcaresystembackend_redis_data.tar.gz
│   │   ├── bookingcaresystembackend_mongodb_data.tar.gz
│   │   ├── bookingcaresystembackend_sqlserver_*.tar.gz
│   │   ├── metadata.json
│   │   └── README.md
│   └── 20241211_120000.tar.gz  # Compressed archive
│
└── databases/
    ├── 20241211_120000/
    │   ├── mongodb.tar.gz
    │   ├── redis_dump.rdb
    │   ├── rabbitmq_definitions.json
    │   ├── MABS_Discount.bak
    │   ├── MABS_Saga.bak
    │   ├── MABS_*.bak (11 databases)
    │   └── metadata.json
    └── 20241211_120000_databases.tar.gz  # Compressed archive
```

## 🔍 Verification Commands

```bash
# Kiểm tra volumes
docker volume ls | grep bookingcaresystembackend

# Kiểm tra containers
docker-compose ps

# Kiểm tra logs
docker-compose logs -f

# Kiểm tra MongoDB
docker exec bookingcare_mongodb mongosh \
    -u admin -p password --authenticationDatabase admin \
    --eval "db.adminCommand('listDatabases')"

# Kiểm tra Redis
docker exec bookingcare_redis redis-cli DBSIZE

# Kiểm tra SQL Server
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U SA -P 'YourPassword' \
    -Q "SELECT name FROM sys.databases"

# Kiểm tra disk usage
docker system df -v
```

## 🛠️ Troubleshooting

### Script không chạy được
```bash
# Cấp quyền execute
chmod +x scripts/*.sh
```

### Container không healthy
```bash
# Kiểm tra logs
docker logs <container_name>

# Restart container
docker restart <container_name>
```

### Backup file quá lớn
```bash
# Sử dụng database backup thay vì volume backup
./backup-databases.sh
# Database backup nhỏ hơn 30-50% so với volume backup
```

### SSH connection failed
```bash
# Kiểm tra SSH key
ssh-add -l

# Test connection
ssh -v ec2-user@your-ec2-ip

# Kiểm tra Security Group của EC2:
# - Inbound rule cho port 22 (SSH)
# - IP address được phép connect
```

## ⚙️ Environment Variables

Scripts sử dụng các biến môi trường từ file `.env`:

```bash
# MongoDB
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=password

# RabbitMQ
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest
RABBITMQ_DEFAULT_VHOST=/

# SQL Server (11 databases)
SQLSERVER_DISCOUNT_PASSWORD=YourPassword@123
SQLSERVER_SAGA_PASSWORD=YourPassword@123
# ... (và các password khác)
```

## 📖 Chi Tiết Hơn

Xem tài liệu đầy đủ tại: [../docs/BACKUP_RESTORE_GUIDE.md](../docs/BACKUP_RESTORE_GUIDE.md)

## 🆘 Support

Nếu gặp vấn đề:
1. Kiểm tra logs: `docker-compose logs -f`
2. Kiểm tra disk space: `df -h`
3. Kiểm tra Docker: `docker ps -a`
4. Đọc tài liệu: `docs/BACKUP_RESTORE_GUIDE.md`

## 📝 Notes

- ⚠️ Luôn test scripts trên staging trước khi chạy production
- ⚠️ Backup trước khi deploy version mới
- ⚠️ Giữ ít nhất 3 bản backup gần nhất
- ⚠️ Không commit file `.env` vào git

---

**Created:** December 2024  
**Version:** 1.0.0  
**Maintained by:** BookingCare Team
