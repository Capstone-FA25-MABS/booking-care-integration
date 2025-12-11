# BookingCare Backup & Restore Guide

Hướng dẫn chi tiết về cách backup và restore dữ liệu cho hệ thống BookingCare khi deploy lên EC2.

## 📋 Mục Lục

- [Tổng Quan](#tổng-quan)
- [Yêu Cầu](#yêu-cầu)
- [Backup Strategies](#backup-strategies)
- [Hướng Dẫn Sử Dụng](#hướng-dẫn-sử-dụng)
- [Migrate lên EC2](#migrate-lên-ec2)
- [Troubleshooting](#troubleshooting)

## 🎯 Tổng Quan

Hệ thống cung cấp 2 phương pháp backup:

### 1. **Volume Backup** (Backup toàn bộ volumes)
- Backup trực tiếp Docker volumes
- Phù hợp khi cần backup nhanh toàn bộ dữ liệu
- Đơn giản nhưng file backup lớn

### 2. **Database Backup** (Backup chuyên biệt cho databases)
- Sử dụng native database tools (mongodump, SQL Server backup, etc.)
- File backup nhỏ hơn, tối ưu hơn
- **Khuyến nghị cho production**

## 📦 Yêu Cầu

- Docker và Docker Compose đã cài đặt
- Bash shell (macOS/Linux) hoặc Git Bash (Windows)
- Đủ dung lượng disk cho backup
- Quyền truy cập SSH vào EC2 (nếu migrate)

## 🔄 Backup Strategies

### Danh Sách Volumes

Hệ thống có các volumes sau:

**Infrastructure:**
- `rabbitmq_data` - RabbitMQ message broker
- `redis_data` - Redis cache
- `mongodb_data` - MongoDB (Reviews)

**SQL Server Databases:**
- `sqlserver_discount_data` - Discount Service
- `sqlserver_saga_data` - Saga Orchestration
- `sqlserver_user_data` - User Service
- `sqlserver_doctor_data` - Doctor Service
- `sqlserver_auth_data` - Authentication Service
- `sqlserver_appointment_data` - Appointment Service
- `sqlserver_hospital_data` - Hospital Service
- `sqlserver_schedule_data` - Schedule Service
- `sqlserver_payment_data` - Payment Service
- `sqlserver_servicemedical_data` - Medical Service
- `sqlserver_ai_data` - AI Service

## 📝 Hướng Dẫn Sử Dụng

### Phương Pháp 1: Volume Backup (Nhanh & Đơn Giản)

#### Backup Volumes

```bash
cd booking-care-integration/scripts

# Backup với đường dẫn mặc định (./backups/volumes)
./backup-volumes.sh

# Hoặc chỉ định đường dẫn tùy chỉnh
./backup-volumes.sh /path/to/your/backups
```

**Output:**
- Folder: `./backups/volumes/YYYYMMDD_HHMMSS/`
- Archive: `./backups/volumes/YYYYMMDD_HHMMSS.tar.gz`
- Files: Các file `.tar.gz` cho từng volume
- Metadata: `metadata.json` và `README.md`

#### Restore Volumes

```bash
# Restore từ folder backup
./restore-volumes.sh ./backups/volumes/20241211_120000

# Hoặc từ archive file
./restore-volumes.sh ./backups/volumes/20241211_120000.tar.gz
```

### Phương Pháp 2: Database Backup (Khuyến Nghị cho Production)

#### Backup Databases

```bash
cd booking-care-integration/scripts

# Đảm bảo file .env tồn tại ở thư mục cha
# Backup sẽ sử dụng credentials từ .env
./backup-databases.sh

# Hoặc chỉ định đường dẫn
./backup-databases.sh /path/to/backups/databases
```

**Backup bao gồm:**
- MongoDB dump
- Redis RDB snapshot
- SQL Server .bak files (11 databases)
- RabbitMQ definitions (queues, exchanges, bindings)

#### Restore Databases

```bash
# Restore từ folder backup
./restore-databases.sh ./backups/databases/20241211_120000

# Hoặc từ archive file
./restore-databases.sh ./backups/databases/20241211_120000
```

## 🚀 Migrate Lên EC2

### Bước 1: Backup Trên Local

```bash
# Khuyến nghị: Sử dụng database backup
cd booking-care-integration/scripts
./backup-databases.sh

# Hoặc: Sử dụng volume backup
./backup-volumes.sh
```

### Bước 2: Transfer Backup Lên EC2

```bash
# Sử dụng SCP để transfer
scp ./backups/databases/20241211_120000_databases.tar.gz \
    ec2-user@your-ec2-ip:/home/ec2-user/backups/

# Hoặc sử dụng rsync (nhanh hơn cho file lớn)
rsync -avz --progress \
    ./backups/databases/20241211_120000_databases.tar.gz \
    ec2-user@your-ec2-ip:/home/ec2-user/backups/
```

### Bước 3: Setup Trên EC2

```bash
# SSH vào EC2
ssh ec2-user@your-ec2-ip

# Cài đặt Docker (nếu chưa có)
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Cài đặt Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone hoặc copy project
git clone <your-repo-url> /home/ec2-user/booking-care-integration
cd /home/ec2-user/booking-care-integration

# Copy file .env
nano .env  # Paste nội dung .env của bạn
```

### Bước 4: Tạo Volumes Trên EC2

```bash
cd /home/ec2-user/booking-care-integration

# Tạo tất cả volumes trước khi restore
docker volume create bookingcaresystembackend_rabbitmq_data
docker volume create bookingcaresystembackend_redis_data
docker volume create bookingcaresystembackend_mongodb_data
docker volume create bookingcaresystembackend_sqlserver_discount_data
docker volume create bookingcaresystembackend_sqlserver_saga_data
docker volume create bookingcaresystembackend_sqlserver_user_data
docker volume create bookingcaresystembackend_sqlserver_doctor_data
docker volume create bookingcaresystembackend_sqlserver_auth_data
docker volume create bookingcaresystembackend_sqlserver_appointment_data
docker volume create bookingcaresystembackend_sqlserver_hospital_data
docker volume create bookingcaresystembackend_sqlserver_schedule_data
docker volume create bookingcaresystembackend_sqlserver_payment_data
docker volume create bookingcaresystembackend_sqlserver_servicemedical_data
docker volume create bookingcaresystembackend_sqlserver_ai_data
```

### Bước 5: Start Infrastructure Services

```bash
# Start database containers trước
docker-compose up -d rabbitmq redis mongodb
docker-compose up -d sqlserver-discount sqlserver-saga sqlserver-user \
    sqlserver-doctor sqlserver-auth sqlserver-appointment \
    sqlserver-hospital sqlserver-schedule sqlserver-payment \
    sqlserver-servicemedical sqlserver-ai

# Đợi containers healthy
docker-compose ps
```

### Bước 6: Restore Data

```bash
cd /home/ec2-user/booking-care-integration/scripts

# Restore từ database backup (khuyến nghị)
./restore-databases.sh /home/ec2-user/backups/20241211_120000

# Hoặc restore từ volume backup
./restore-volumes.sh /home/ec2-user/backups/20241211_120000
```

### Bước 7: Start Application Services

```bash
cd /home/ec2-user/booking-care-integration

# Start tất cả services
docker-compose up -d

# Kiểm tra logs
docker-compose logs -f

# Kiểm tra health
docker-compose ps
```

## 🔍 Verification

### Kiểm Tra Sau Khi Restore

```bash
# 1. Kiểm tra volumes
docker volume ls | grep bookingcaresystembackend

# 2. Kiểm tra containers
docker-compose ps

# 3. Kiểm tra MongoDB
docker exec bookingcare_mongodb mongosh \
    -u admin -p password --authenticationDatabase admin \
    --eval "db.adminCommand('listDatabases')"

# 4. Kiểm tra Redis
docker exec bookingcare_redis redis-cli INFO stats

# 5. Kiểm tra SQL Server
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U SA -P 'YourPassword' \
    -Q "SELECT name FROM sys.databases"

# 6. Kiểm tra RabbitMQ
curl -u guest:guest http://localhost:15672/api/overview
```

## 📊 So Sánh Phương Pháp

| Tiêu Chí | Volume Backup | Database Backup |
|----------|---------------|-----------------|
| Tốc độ backup | ⚡⚡⚡ Nhanh | ⚡⚡ Trung bình |
| Kích thước file | 📦 Lớn | 📦 Nhỏ hơn 30-50% |
| Phục hồi | ⚡⚡⚡ Nhanh | ⚡⚡ Trung bình |
| Độ tin cậy | ✅ Tốt | ✅✅ Rất tốt |
| Production | ⚠️ OK | ✅ Khuyến nghị |
| Selective restore | ❌ Không | ✅ Có |

## 🛠️ Troubleshooting

### Lỗi Permission Denied

```bash
# Cấp quyền execute cho scripts
chmod +x scripts/*.sh
```

### Container Không Healthy

```bash
# Kiểm tra logs
docker logs <container_name>

# Restart container
docker restart <container_name>

# Kiểm tra health status
docker inspect <container_name> | grep Health -A 10
```

### Backup File Quá Lớn

```bash
# Sử dụng database backup thay vì volume backup
./backup-databases.sh

# Hoặc backup từng volume riêng lẻ
docker run --rm \
    -v bookingcaresystembackend_mongodb_data:/data:ro \
    -v $(pwd):/backup \
    alpine tar czf /backup/mongodb_data.tar.gz -C /data .
```

### Restore Bị Lỗi "Volume Already Exists"

```bash
# Xóa volume cũ (⚠️ Cẩn thận: Mất dữ liệu)
docker volume rm <volume_name>

# Hoặc restore với force (script sẽ hỏi confirm)
./restore-volumes.sh /path/to/backup
```

### SQL Server Restore Failed

```bash
# Kiểm tra SQL Server container logs
docker logs bookingcare_sqlserver_user

# Test connection
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U SA -P 'YourPassword' -Q "SELECT @@VERSION"

# Drop database manually nếu cần
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U SA -P 'YourPassword' \
    -Q "DROP DATABASE IF EXISTS MABS_User"
```

## 📅 Backup Best Practices

### 1. Lập Lịch Backup Tự Động

```bash
# Thêm vào crontab
crontab -e

# Backup hàng ngày lúc 2 giờ sáng
0 2 * * * /path/to/booking-care-integration/scripts/backup-databases.sh
```

### 2. Retention Policy

```bash
# Script để xóa backup cũ hơn 30 ngày
find ./backups -type f -name "*.tar.gz" -mtime +30 -delete
```

### 3. Backup trước khi Deploy

```bash
# Luôn backup trước khi deploy version mới
./backup-databases.sh ./backups/databases/pre-deploy-$(date +%Y%m%d)
```

### 4. Test Restore Định Kỳ

```bash
# Test restore trên môi trường staging hàng tháng
./restore-databases.sh ./backups/databases/latest
```

## 🔐 Security Notes

1. **Bảo vệ file backup:**
   ```bash
   # Encrypt backup trước khi transfer
   gpg --encrypt --recipient your-email@example.com backup.tar.gz
   ```

2. **Secure transfer:**
   ```bash
   # Sử dụng SSH keys thay vì password
   ssh-keygen -t rsa -b 4096
   ssh-copy-id ec2-user@your-ec2-ip
   ```

3. **Không commit .env vào git:**
   - File `.env` chứa credentials nhạy cảm
   - Sử dụng secrets manager trên production

## 📞 Support

Nếu gặp vấn đề, kiểm tra:
- Docker logs: `docker-compose logs -f`
- Container status: `docker-compose ps`
- Disk space: `df -h`
- Network: `docker network ls`

## 📚 Tài Liệu Liên Quan

- [Docker Volume Documentation](https://docs.docker.com/storage/volumes/)
- [MongoDB Backup Methods](https://docs.mongodb.com/manual/core/backups/)
- [SQL Server Backup](https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/)
- [Redis Persistence](https://redis.io/topics/persistence)

---

**Lưu ý:** Scripts này được thiết kế để chạy trên môi trường development và production. Hãy test kỹ trên staging environment trước khi áp dụng lên production.
