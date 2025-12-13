# BookingCare EC2 Deployment Guide

Hướng dẫn chi tiết từng bước để deploy BookingCare System lên EC2 sau khi chạy Terraform.

## 📋 Mục Lục

- [Chuẩn Bị](#chuẩn-bị)
- [Bước 1: Backup Data Trên Local](#bước-1-backup-data-trên-local)
- [Bước 2: Truy Cập EC2](#bước-2-truy-cập-ec2)
- [Bước 3: Setup Môi Trường](#bước-3-setup-môi-trường)
- [Bước 4: Clone Project](#bước-4-clone-project)
- [Bước 5: Transfer Backup](#bước-5-transfer-backup)
- [Bước 6: Restore Data](#bước-6-restore-data)
- [Bước 7: Start Services](#bước-7-start-services)
- [Bước 8: Verify Deployment](#bước-8-verify-deployment)
- [Troubleshooting](#troubleshooting)

---

## 🆕 Backup/Restore Methods

Guide này hướng dẫn 2 phương pháp backup/restore:

### Method 1: Database Native Backup (Khuyến nghị) ⭐
- **File**: [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md)
- **Ưu điểm**: 
  - Nhỏ gọn (~5MB)
  - Transfer nhanh
  - Native database tools (mongodump, data files)
- **Nhược điểm**: 
  - SQL Server dùng data files (phức tạp hơn)
  - Cần restore từng database riêng lẻ

### Method 2: Docker Volume Backup (Dưới đây)
- **File**: Guide này
- **Ưu điểm**:
  - Backup toàn bộ volume
  - Exact copy của data
  - Reliable
- **Nhược điểm**:
  - File lớn (~500MB-1GB)
  - Transfer lâu hơn

**💡 Gợi ý**: Dùng **Method 1** cho mock data nhỏ, **Method 2** cho production data migration.

---

## 🎯 Chuẩn Bị

### 1. Trên Local Machine

**Cần có:**
- ✅ Docker Desktop đang chạy
- ✅ BookingCare System đang chạy với data đầy đủ
- ✅ SSH key để connect EC2 (từ Terraform output)
- ✅ EC2 public IP (từ Terraform output)

**Lấy thông tin từ Terraform:**
```bash
cd BookingCareSystemBackend/infrastructure/terraform

# Lấy EC2 IP
terraform output ec2_public_ip

# Lấy SSH key path (nếu dùng key có sẵn)
terraform output -raw private_key_path
```

### 2. Kiểm Tra Local Setup

```bash
# Kiểm tra containers đang chạy
docker ps

# Kiểm tra volumes
docker volume ls | grep bookingcare

# Test các services
curl http://localhost:5001/health  # API Gateway
curl http://localhost:15672        # RabbitMQ UI
```

---

## 🗄️ Bước 1: Backup Data Trên Local

### 1.1. Backup Volumes (Khuyến nghị)

```bash
# Di chuyển vào thư mục scripts
cd booking-care-integration/scripts

# Backup tất cả volumes
./backup-volumes.sh

# Output sẽ ở: backups/volumes/YYYYMMDD_HHMMSS/
# Ví dụ: backups/volumes/20251212_100000/
```

**Kết quả:**
```
backups/volumes/20251212_100000/
├── metadata.json
├── README.md
├── bookingcaresystembackend_rabbitmq_data.tar.gz
├── bookingcaresystembackend_redis_data.tar.gz
├── bookingcaresystembackend_mongodb_data.tar.gz
├── bookingcaresystembackend_sqlserver_discount_data.tar.gz
├── bookingcaresystembackend_sqlserver_saga_data.tar.gz
├── bookingcaresystembackend_sqlserver_user_data.tar.gz
├── bookingcaresystembackend_sqlserver_doctor_data.tar.gz
├── bookingcaresystembackend_sqlserver_auth_data.tar.gz
├── bookingcaresystembackend_sqlserver_appointment_data.tar.gz
├── bookingcaresystembackend_sqlserver_hospital_data.tar.gz
├── bookingcaresystembackend_sqlserver_schedule_data.tar.gz
├── bookingcaresystembackend_sqlserver_payment_data.tar.gz
├── bookingcaresystembackend_sqlserver_servicemedical_data.tar.gz
└── bookingcaresystembackend_sqlserver_ai_data.tar.gz
```

### 1.2. Kiểm Tra Backup

```bash
# Xem metadata
cat backups/volumes/20251212_100000/metadata.json

# Kiểm tra kích thước
du -sh backups/volumes/20251212_100000/
```

### 1.3. Archive Backup (Optional - để transfer dễ hơn)

```bash
# Tạo archive duy nhất
cd backups/volumes
tar czf 20251212_100000.tar.gz 20251212_100000/

# Kiểm tra
ls -lh 20251212_100000.tar.gz
```

---

## 🔐 Bước 2: Truy Cập EC2

### 2.1. Chuẩn Bị SSH Key

```bash
# Nếu Terraform tạo key mới
chmod 400 ~/.ssh/bookingcare-key.pem

# Nếu dùng key có sẵn (đã có trong ~/.ssh/)
chmod 600 ~/.ssh/id_rsa
```

### 2.2. Connect SSH

```bash
# Lấy EC2 IP từ Terraform
export EC2_IP=$(cd BookingCareSystemBackend/infrastructure/terraform && terraform output -raw ec2_public_ip)

# Connect với key mới (nếu Terraform tạo)
ssh -i ~/.ssh/bookingcare-key.pem ubuntu@$EC2_IP

# Hoặc với key có sẵn
ssh ubuntu@$EC2_IP
```

**Lần đầu connect sẽ hỏi:**
```
The authenticity of host 'X.X.X.X' can't be established.
Are you sure you want to continue connecting (yes/no)? yes
```

### 2.3. Kiểm Tra EC2 Instance

```bash
# Kiểm tra thông tin system
uname -a
lsb_release -a

# Kiểm tra disk space
df -h

# Kiểm tra memory
free -h

# Kiểm tra network
ip addr show
```

---

## 🛠️ Bước 3: Setup Môi Trường

### 3.1. Update System

```bash
# Update package list
sudo apt update

# Upgrade packages (optional nhưng khuyến nghị)
sudo apt upgrade -y
```

### 3.2. Cài Đặt Docker

```bash
# Cài đặt Docker
sudo apt install -y docker.io

# Start và enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Kiểm tra Docker version
docker --version

# Add user vào docker group
sudo usermod -aG docker ubuntu

# ⚠️ QUAN TRỌNG: PHẢI logout và login lại để group có hiệu lực
# Restart Docker KHÔNG ĐỦ, bạn PHẢI logout/login!
exit

# Login lại từ local machine
ssh ubuntu@$EC2_IP

# Verify docker group đã được add
groups
# Phải thấy "docker" trong list: ubuntu adm dialout ... docker ...
```

### 3.3. Verify Docker Access

```bash
# Test Docker command (phải chạy ĐƯỢC không cần sudo)
docker ps

# Nếu vẫn báo "permission denied":
# 1. Check groups
groups  # Phải thấy "docker" trong list

# 2. Nếu không có "docker", nghĩa là chưa logout/login
# Logout và login lại:
exit
# Từ local: ssh ubuntu@$EC2_IP
5. Cài Đặt Git (nếu chưa có)

```bash
# Cài Git
sudo apt install -y git

# Verify
git --version
```

### 3.6. Cài Đặt Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose

# Cấp quyền execute
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### 3.4. Cài Đặt Git (nếu chưa có)

```bash
# Cài Git
sudo apt install -y git

# Verify
git --version
```

### 3.5. Cài Đặt Tools Khác (Optional nhưng hữu ích)

```bash
# Cài các tools hữu ích
sudo apt install -y \
    htop \
    ncdu \
    tree \
    curl \
    wget \
    net-tools \
    unzip

# htop: monitor resources
# ncdu: disk usage analyzer
# tree: view directory structure
```

---

## 📦 Bước 4: Clone Project

### 4.1. Setup SSH Key cho GitHub (nếu private repo)

```bash
# Generate SSH key trên EC2
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
# Press Enter 3 times (default location, no passphrase)

# Copy public key
cat ~/.ssh/id_rsa.pub

# Add key vào GitHub:
# 1. Vào GitHub → Settings → SSH and GPG keys
# 2. Click "New SSH key"
# 3. Paste public key
# 4. Save
```

### 4.2. Clone Repository

```bash
# Clone integration repo (chứa docker-compose.yml)
cd ~
git clone git@github.com:Capstone-FA25-MABS/booking-care-integration.git

# Verify
ls -la booking-care-integration/
```

### 4.3. Setup Environment Variables

```bash
cd ~/booking-care-integration

# Tạo file .env từ template
cp .env.example .env

# Edit .env với thông tin production
nano .env
```

**Cấu hình .env quan trọng:**
```bash
# Database Passwords (đổi thành production passwords)
SQLSERVER_DISCOUNT_PASSWORD=YourStrongPassword123!
SQLSERVER_SAGA_PASSWORD=YourStrongPassword123!
SQLSERVER_USER_PASSWORD=YourStrongPassword123!
SQLSERVER_DOCTOR_PASSWORD=YourStrongPassword123!
SQLSERVER_AUTH_PASSWORD=YourStrongPassword123!
SQLSERVER_APPOINTMENT_PASSWORD=YourStrongPassword123!
SQLSERVER_HOSPITAL_PASSWORD=YourStrongPassword123!
SQLSERVER_SCHEDULE_PASSWORD=YourStrongPassword123!
SQLSERVER_PAYMENT_PASSWORD=YourStrongPassword123!
SQLSERVER_SERVICEMEDICAL_PASSWORD=YourStrongPassword123!
SQLSERVER_AI_PASSWORD=YourStrongPassword123!

# MongoDB
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=YourMongoPassword123!

# RabbitMQ
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=YourRabbitPassword123!

# Redis (không cần password mặc định)

# JWT
JWT_KEY=your-secret-jwt-key-min-32-characters-long-production
JWT_ISSUER=https://yourdomain.com
JWT_AUDIENCE=https://yourdomain.com

# AWS S3 (nếu dùng)
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
S3_BUCKET_NAME=bookingcare-bucket
S3_REGION=ap-southeast-1

# Docker Hub
DOCKER_USERNAME=hiumx
VERSION=latest

# Environment
ASPNETCORE_ENVIRONMENT=Production
```

**Lưu file:** `Ctrl + O` → `Enter` → `Ctrl + X`

### 4.4. Tạo Directories Cần Thiết

```bash
# Tạo backup directory
mkdir -p ~/booking-care-integration/scripts/backups/volumes
mkdir -p ~/booking-care-integration/scripts/backups/databases

# Tạo logs directory (optional)
mkdir -p ~/booking-care-integration/logs
```

---

## 📤 Bước 5: Transfer Backup

### 5.1. Transfer từ Local → EC2

**Trên Local machine** (mở terminal mới):

```bash
# Set variables
export EC2_IP=$(cd BookingCareSystemBackend/infrastructure/terraform && terraform output -raw ec2_public_ip)
export BACKUP_DATE=20251212_100000  # Thay bằng backup date của bạn

# Option 1: Transfer archive
scp -i ~/.ssh/bookingcare-key.pem \
    booking-care-integration/scripts/backups/volumes/${BACKUP_DATE}.tar.gz \
    ubuntu@$EC2_IP:/home/ubuntu/booking-care-integration/scripts/backups/volumes/

# Option 2: Transfer directory (nếu không archive)
scp -i ~/.ssh/bookingcare-key.pem -r \
    booking-care-integration/scripts/backups/volumes/${BACKUP_DATE} \
    ubuntu@$EC2_IP:/home/ubuntu/booking-care-integration/scripts/backups/volumes/

# Option 3: Sử dụng rsync (nhanh hơn cho file lớn)
rsync -avz --progress \
    -e "ssh -i ~/.ssh/bookingcare-key.pem" \
    booking-care-integration/scripts/backups/volumes/${BACKUP_DATE}.tar.gz \
    ubuntu@$EC2_IP:/home/ubuntu/booking-care-integration/scripts/backups/volumes/
```

### 5.2. Verify Transfer

**Quay lại terminal EC2:**

```bash
# Kiểm tra file đã transfer
ls -lh ~/booking-care-integration/scripts/backups/volumes/

# Kiểm tra kích thước
du -sh ~/booking-care-integration/scripts/backups/volumes/*

# Nếu transfer archive, extract
cd ~/booking-care-integration/scripts/backups/volumes
tar xzf 20251212_100000.tar.gz

# Verify extracted files
ls -la 20251212_100000/
```

---

## 🔄 Bước 6: Restore Data

### 6.1. Tạo Docker Volumes

```bash
cd ~/booking-care-integration

# Tạo tất cả volumes
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

# Hoặc dùng script
./scripts/create-volumes.sh

# Verify volumes
docker volume ls | grep bookingcare
```

### 6.2. Restore Volumes

```bash
cd ~/booking-care-integration/scripts

# Set executable permission
chmod +x *.sh

# Restore từ backup
./restore-volumes.sh backups/volumes/20251212_100000
```

**Script sẽ hỏi confirmation:**
```
This will restore volumes from the backup. Continue? (y/N) y
```

**Cho mỗi volume:**
```
[WARNING] Volume already exists. It will be overwritten.
Continue with this volume? (y/N) y
```

### 6.3. Verify Restore

```bash
# Kiểm tra volumes đã có data
docker run --rm -v bookingcaresystembackend_mongodb_data:/data alpine du -sh /data
docker run --rm -v bookingcaresystembackend_redis_data:/data alpine du -sh /data
docker run --rm -v bookingcaresystembackend_sqlserver_user_data:/data alpine du -sh /data
```

---

## 🚀 Bước 7: Start Services

### 7.1. Pull Docker Images

```bash
cd ~/booking-care-integration

# Pull tất cả images
docker-compose pull

# Hoặc pull từng image
docker pull hiumx/bookingcare-api-gateway:v1.0.0
docker pull hiumx/bookingcare-ai-service:v1.0.0
# ... etc
```

**⚠️ Nếu gặp lỗi platform mismatch:**

```
Error response from daemon: image with reference hiumx/bookingcare-xxx-service:v1.0.0 was found 
but does not provide the specified platform (linux/amd64)
```

**Nguyên nhân:** Image được build sai platform (ARM thay vì AMD64) hoặc không có multi-platform manifest.

**Giải pháp 1 - Check image trên Docker Hub:**
```bash
# Từ local machine, check platform của image
docker buildx imagetools inspect hiumx/bookingcare-analytics-service:v1.0.0

# Output phải có: linux/amd64
# Nếu chỉ có linux/arm64, cần rebuild
```

**Giải pháp 2 - Rebuild image cụ thể (từ local):**
```bash
# Từ local machine
cd BookingCareSystemBackend

# Rebuild service bị lỗi cho linux/amd64
docker buildx build --platform linux/amd64 \
    -f src/Services/BookingCare.Services.Analytics/Dockerfile \
    -t hiumx/bookingcare-analytics-service:v1.0.0 \
    --push .

# Sau đó quay lại EC2 pull lại
docker pull hiumx/bookingcare-analytics-service:v1.0.0
```

**Giải pháp 3 - Rebuild tất cả images (nếu nhiều images lỗi):**
```bash
# Từ local machine
cd BookingCareSystemBackend/scripts
./build-and-push-all-services.sh

# Đợi build xong (15-30 phút)
# Sau đó quay lại EC2 pull lại tất cả
docker-compose pull
```

### 7.2. Start Infrastructure Services Trước

```bash
# Start databases và infrastructure
docker-compose up -d rabbitmq redis mongodb

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

# Đợi containers healthy (30-60 giây)
watch docker-compose ps
# Press Ctrl+C khi tất cả containers healthy
```

### 7.3. Start Application Services

```bash
# Start tất cả microservices
docker-compose up -d

# Hoặc start từng service để dễ monitor
docker-compose up -d api-gateway
docker-compose up -d auth-service user-service
docker-compose up -d doctor-service hospital-service
docker-compose up -d appointment-service schedule-service
docker-compose up -d payment-service discount-service
docker-compose up -d notification-service communication-service
docker-compose up -d review-service favorites-service
docker-compose up -d content-service analytics-service ai-service
docker-compose up -d saga-service servicemedical-service
```

### 7.4. Monitor Logs

```bash
# Xem logs tất cả services
docker-compose logs -f

# Xem logs một service cụ thể
docker-compose logs -f api-gateway
docker-compose logs -f auth-service

# Xem logs infrastructure
docker-compose logs -f mongodb
docker-compose logs -f sqlserver-user

# Press Ctrl+C để stop following logs
```

---

## ✅ Bước 8: Verify Deployment

### 8.1. Kiểm Tra Container Status

```bash
# Xem tất cả containers
docker-compose ps

# Hoặc
docker ps

# Đếm số containers đang chạy
docker ps | wc -l
# Kỳ vọng: 29 containers (11 SQL + 3 infra + 15 services + 1 gateway)
```

### 8.2. Test API Gateway

```bash
# Health check
curl http://localhost:5001/health

# Hoặc từ local machine
curl http://$EC2_IP:5001/health
```

### 8.3. Test Infrastructure

```bash
# RabbitMQ Management UI
curl http://localhost:15672
# Mở browser: http://<EC2_IP>:15672
# Login: admin / <RABBITMQ_DEFAULT_PASS>

# Redis
docker exec bookingcare_redis redis-cli ping
# Kỳ vọng: PONG

# MongoDB
docker exec bookingcare_mongodb mongosh \
    -u admin -p <MONGO_INITDB_ROOT_PASSWORD> \
    --authenticationDatabase admin \
    --eval "db.adminCommand('listDatabases')"
```

### 8.4. Test Databases

```bash
# Test SQL Server User database
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P '<SQLSERVER_USER_PASSWORD>' \
    -Q "SELECT name FROM sys.databases"

# Kiểm tra có data trong MABS_User
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P '<SQLSERVER_USER_PASSWORD>' \
    -Q "USE MABS_User; SELECT TOP 5 * FROM Users"
```

### 8.5. Test Specific Services

```bash
# Auth Service health
curl http://localhost:6003/health

# User Service health  
curl http://localhost:6016/health

# Doctor Service health
curl http://localhost:6008/health

# Appointment Service health
curl http://localhost:6002/health
```

### 8.6. Monitor Resources

```bash
# CPU và Memory usage
docker stats

# Disk usage
docker system df

# Disk space còn lại
df -h

# Network
docker network ls
```

### 8.7. Check Logs for Errors

```bash
# Grep errors trong logs
docker-compose logs | grep -i error
docker-compose logs | grep -i exception
docker-compose logs | grep -i failed

# Check specific service errors
docker-compose logs auth-service | grep -i error
```

---

## 🔧 Troubleshooting

### Container Không Start

```bash
# Xem logs chi tiết
docker logs <container_name>

# Xem events
docker events --since 10m

# Inspect container
docker inspect <container_name>

# Restart container
docker-compose restart <service_name>
```

### Database Connection Issues

```bash
# Test SQL Server connection
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P '<PASSWORD>' -Q "SELECT @@VERSION"

# Nếu fail, check logs
docker logs bookingcare_sqlserver_user

# Restart SQL Server
docker-compose restart sqlserver-user
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a --volumes
# WARNING: Sẽ xóa tất cả unused data

# Hoặc chỉ prune containers
docker container prune
docker image prune
```

### Network Issues

```bash
# Check network
docker network ls
docker network inspect bookingcare-network

# Recreate network
docker-compose down
docker network rm bookingcare-network
docker-compose up -d
```

### Service Cannot Connect to Database

```bash
# Check environment variables
docker-compose config

# Check .env file
cat .env | grep SQLSERVER

# Recreate service
docker-compose up -d --force-recreate auth-service
```

### Slow Performance

```bash
# Check resources
htop
docker stats

# Check logs for bottlenecks
docker-compose logs | grep -i timeout
docker-compose logs | grep -i slow

# Increase resources nếu cần (resize EC2 instance)
```

### Platform Mismatch Error

**Lỗi:**
```
Error response from daemon: image with reference hiumx/bookingcare-xxx-service:v1.0.0 
was found but does not provide the specified platform (linux/amd64)
```

**Nguyên nhân:** 
- Image được build trên Apple Silicon (ARM) nhưng không có flag `--platform linux/amd64`
- Dockerfile không có cross-compilation support
- Build process không thành công hoàn toàn

**Cách fix:**

```bash
# 1. Check platform của image (từ local machine)
docker buildx imagetools inspect hiumx/bookingcare-analytics-service:v1.0.0

# Output nên có:
# Platform:    linux/amd64
#              linux/arm64  (optional)

# 2. Nếu không có linux/amd64, check Dockerfile
cat BookingCareSystemBackend/src/Services/BookingCare.Services.Analytics/Dockerfile

# Phải có:
# FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0
# ARG TARGETARCH
# RUN dotnet restore -a $TARGETARCH
# RUN dotnet publish -a $TARGETARCH

# 3. Rebuild image với đúng platform
cd BookingCareSystemBackend
docker buildx build --platform linux/amd64 \
    -f src/Services/BookingCare.Services.Analytics/Dockerfile \
    -t hiumx/bookingcare-analytics-service:v1.0.0 \
    --push .

# 4. Pull lại trên EC2
docker pull hiumx/bookingcare-analytics-service:v1.0.0

# 5. Restart service
docker-compose up -d analytics-service
```

**Nếu nhiều services bị lỗi:**
```bash
# Từ local, rebuild tất cả
cd BookingCareSystemBackend/scripts
./build-and-push-all-services.sh

# Đợi hoàn thành, sau đó trên EC2:
docker-compose pull
docker-compose up -d --force-recreate
```

---

## 📝 Maintenance Commands

### Start/Stop Services

```bash
# Stop tất cả
docker-compose stop

# Start tất cả
docker-compose start

# Restart tất cả
docker-compose restart

# Stop và remove containers
docker-compose down

# Start lại
docker-compose up -d
```

### Update Services

```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d --force-recreate

# Hoặc update một service
docker-compose pull auth-service
docker-compose up -d --force-recreate auth-service
```

### Backup on EC2

```bash
# Backup volumes
cd ~/booking-care-integration/scripts
./backup-volumes.sh

# Backup sẽ lưu ở: backups/volumes/YYYYMMDD_HHMMSS/
```

### View Logs

```bash
# Follow all logs
docker-compose logs -f

# Logs của một service
docker-compose logs -f auth-service

# Last 100 lines
docker-compose logs --tail=100

# Since timestamp
docker-compose logs --since 2024-12-12T10:00:00
```

---

## 🔒 Security Best Practices

### 1. Firewall Configuration

```bash
# Allow only specific ports
sudo ufw allow 22          # SSH
sudo ufw allow 5001        # API Gateway
sudo ufw allow 15672       # RabbitMQ (nếu cần access từ ngoài)
sudo ufw enable

# Check rules
sudo ufw status
```

### 2. Change Default Passwords

Đảm bảo tất cả passwords trong `.env` đã được thay đổi từ defaults.

### 3. SSL/TLS Certificate

```bash
# Cài Certbot
sudo apt install certbot

# Lấy SSL certificate
sudo certbot certonly --standalone -d yourdomain.com
```

### 4. Regular Updates

```bash
# Schedule updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

---

## 📊 Monitoring Setup

### Install Monitoring Tools

```bash
# Docker stats dashboard
docker run -d --name cadvisor \
    -p 8080:8080 \
    -v /:/rootfs:ro \
    -v /var/run:/var/run:rw \
    -v /sys:/sys:ro \
    -v /var/lib/docker/:/var/lib/docker:ro \
    google/cadvisor:latest

# Access: http://<EC2_IP>:8080
```

---

## 📚 Next Steps

Sau khi deployment thành công:

1. ✅ **Setup Domain**: Point domain to EC2 IP
2. ✅ **Setup SSL**: Install SSL certificate  
3. ✅ **Setup CI/CD**: Automate deployment
4. ✅ **Setup Monitoring**: Grafana + Prometheus
5. ✅ **Setup Backup**: Schedule automatic backups
6. ✅ **Setup Alerts**: Email/Slack notifications
7. ✅ **Load Testing**: Test performance
8. ✅ **Documentation**: Update API docs

---

## 🆘 Support

Nếu gặp vấn đề:

1. Check logs: `docker-compose logs -f`
2. Check resources: `htop`, `docker stats`
3. Check disk: `df -h`
4. Check network: `netstat -tulpn`
5. Contact team hoặc tạo issue trên GitHub

---

## 📖 References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [SQL Server on Linux](https://docs.microsoft.com/en-us/sql/linux/)
- [MongoDB Documentation](https://docs.mongodb.com/)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)

---

**Good luck with your deployment! 🚀**
