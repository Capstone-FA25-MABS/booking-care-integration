# Complete EC2 Deployment Guide - BookingCare System

## 📋 Mục đích

Guideline này hướng dẫn **TOÀN BỘ các bước** để deploy hệ thống BookingCare lên EC2 server với custom domains sau khi đã cấu hình DNS.

## 🎯 Yêu cầu trước khi bắt đầu

### ✅ Checklist cần có:

- [ ] EC2 instance đang chạy (Ubuntu 20.04/22.04)
- [ ] Security Group mở ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5001 (API), 5173 (UI User), 5174 (UI Admin)
- [ ] DNS đã được cấu hình trên Cloudflare:
  - `medcure.com.vn` → 13.250.98.119 (Proxied)
  - `admin.medcure.com.vn` → 13.250.98.119 (Proxied)
  - `api.medcure.com.vn` → 13.250.98.119 (DNS only)
- [ ] SSH key để truy cập EC2
- [ ] Có sẵn các thông tin:
  - Google reCAPTCHA Site Key
  - Google OAuth Client ID
  - Facebook App ID
  - Database passwords
  - RabbitMQ password

## 📖 Tổng quan các bước

1. **[Bước 1](#bước-1-kết-nối-ssh-và-cập-nhật-hệ-thống)**: Kết nối SSH và cập nhật hệ thống
2. **[Bước 2](#bước-2-cài-đặt-docker-và-docker-compose)**: Cài đặt Docker và Docker Compose
3. **[Bước 3](#bước-3-cài-đặt-nginx)**: Cài đặt Nginx
4. **[Bước 4](#bước-4-clone-source-code)**: Clone source code từ GitHub
5. **[Bước 5](#bước-5-tạo-file-envproduction)**: Tạo file .env.production
6. **[Bước 6](#bước-6-cấu-hình-nginx-cho-3-domains)**: Cấu hình Nginx cho 3 domains
7. **[Bước 7](#bước-7-cài-đặt-ssl-certificates)**: Cài đặt SSL certificates
8. **[Bước 8](#bước-8-build-và-deploy-docker-containers)**: Build và deploy Docker containers
9. **[Bước 9](#bước-9-verify-deployment)**: Verify deployment
10. **[Bước 10](#bước-10-cấu-hình-cloudflare-ssl)**: Cấu hình Cloudflare SSL mode

---

## Bước 1: Kết nối SSH và cập nhật hệ thống

### 1.1. Kết nối SSH

```bash
# Từ máy local
ssh -i /path/to/your-key.pem ubuntu@13.250.98.119
```

### 1.2. Cập nhật hệ thống

```bash
# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git vim nano htop net-tools
```

**Expected output**: Các package được update thành công

---

## Bước 2: Cài đặt Docker và Docker Compose

### 2.1. Cài đặt Docker

```bash
# Remove old Docker versions (if any)
sudo apt remove -y docker docker-engine docker.io containerd runc

# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Verify Docker installation
docker --version
```

**Expected output**: `Docker version 24.x.x, build xxxxxxx`

### 2.2. Thêm user vào Docker group

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Verify (should work without sudo)
docker ps
```

**Expected output**: Empty list hoặc container list (không có permission error)

### 2.3. Cài đặt Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Add execute permission
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

**Expected output**: `Docker Compose version v2.x.x`

### 2.4. Enable Docker service

```bash
# Enable Docker to start on boot
sudo systemctl enable docker

# Start Docker service
sudo systemctl start docker

# Check status
sudo systemctl status docker
```

**Expected output**: `Active: active (running)`

---

## Bước 3: Cài đặt Nginx

### 3.1. Install Nginx

```bash
# Install Nginx
sudo apt install -y nginx

# Start Nginx
sudo systemctl start nginx

# Enable Nginx on boot
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

**Expected output**: `Active: active (running)`

### 3.2. Configure firewall

```bash
# Allow Nginx through firewall
sudo ufw allow 'Nginx Full'

# Allow SSH
sudo ufw allow OpenSSH

# Enable firewall
sudo ufw --force enable

# Check status
sudo ufw status
```

**Expected output**:
```
Status: active
To                         Action      From
--                         ------      ----
Nginx Full                 ALLOW       Anywhere
OpenSSH                    ALLOW       Anywhere
```

### 3.3. Test Nginx

```bash
# Test from server
curl http://localhost
```

**Expected output**: HTML content of Nginx welcome page

Từ browser, truy cập: `http://13.250.98.119` → Should see Nginx welcome page

---

## Bước 4: Clone source code

### 4.1. Tạo thư mục làm việc

```bash
cd /home/ubuntu
mkdir -p projects
cd projects
```

### 4.2. Clone repositories

```bash
# Clone integration repository (Docker Compose configs)
git clone https://github.com/Capstone-FA25-MABS/booking-care-integration.git

# Clone patient UI
git clone https://github.com/Capstone-FA25-MABS/booking-care-system-ui.git

# Clone admin UI
git clone https://github.com/Capstone-FA25-MABS/booking-care-system-ui-admin.git

# Clone backend
git clone https://github.com/Capstone-FA25-MABS/BookingCareSystemBackend.git
```

### 4.3. Checkout deployment branches

```bash
# Checkout patient UI deployment branch
cd booking-care-system-ui
git checkout feature/fe-deployment_HieuMX
cd ..

# Checkout admin UI deployment branch
cd booking-care-system-ui-admin
git checkout feature/fe-deployment_HieuMX
cd ..

# Checkout backend deployment branch
cd BookingCareSystemBackend
git checkout feature/api-deployment_HieuMX
cd ..
```

### 4.4. Verify structure

```bash
ls -la /home/ubuntu/projects/
```

**Expected output**:
```
drwxrwxr-x  6 ubuntu ubuntu 4096 Dec 16 10:00 booking-care-integration
drwxrwxr-x 10 ubuntu ubuntu 4096 Dec 16 10:01 booking-care-system-ui
drwxrwxr-x 10 ubuntu ubuntu 4096 Dec 16 10:02 booking-care-system-ui-admin
drwxrwxr-x 15 ubuntu ubuntu 4096 Dec 16 10:03 BookingCareSystemBackend
```

---

## Bước 5: Tạo file .env.production

### 5.1. Tạo file .env.production

```bash
cd /home/ubuntu/projects/booking-care-integration
nano .env.production
```

### 5.2. Paste nội dung sau

**⚠️ QUAN TRỌNG: Thay thế tất cả giá trị `your_xxx` bằng giá trị thực tế của bạn**

```bash
# ============================================
# Production Environment Variables
# ============================================

# Docker Configuration
DOCKER_USERNAME=hiumx
VERSION=v1.0.0

# ============================================
# FRONTEND CONFIGURATION
# ============================================

# API Configuration - MUST use production domain
VITE_API_URL=https://api.medcure.com.vn/api

# reCAPTCHA Configuration
# Get from: https://www.google.com/recaptcha/admin
# IMPORTANT: Register medcure.com.vn and admin.medcure.com.vn as authorized domains
VITE_RECAPTCHA_SITE_KEY=your_recaptcha_site_key_here

# Google OAuth Configuration
# Get from: https://console.cloud.google.com/apis/credentials
# IMPORTANT: Add to Authorized JavaScript origins:
#   - https://medcure.com.vn
#   - https://admin.medcure.com.vn
# IMPORTANT: Add to Authorized redirect URIs:
#   - https://medcure.com.vn/auth/google/callback
#   - https://admin.medcure.com.vn/auth/google/callback
VITE_GOOGLE_CLIENT_ID=your_google_client_id_here.apps.googleusercontent.com

# Facebook OAuth Configuration
# Get from: https://developers.facebook.com/apps/
# IMPORTANT: Add to App Domains:
#   - medcure.com.vn
#   - admin.medcure.com.vn
# IMPORTANT: Add to Valid OAuth Redirect URIs:
#   - https://medcure.com.vn/auth/facebook/callback
#   - https://admin.medcure.com.vn/auth/facebook/callback
VITE_FACEBOOK_APP_ID=your_facebook_app_id_here

# Device Configuration (for patient app)
VITE_DEVICE_ID=web-production

# Admin App Configuration
MABS_APP_NAME=BookingCare Admin

# ============================================
# BACKEND CONFIGURATION
# ============================================

# Frontend Host Mapping
FRONTEND_HOSTMAP_CLIENT=client
FRONTEND_HOSTMAP_ADMIN=admin

# ============================================
# DATABASE CONFIGURATION
# ============================================

# MySQL Root Password
# IMPORTANT: Use strong password (min 16 characters, mix of letters, numbers, symbols)
DB_ROOT_PASSWORD=your_secure_mysql_root_password_here

# Database Connection Strings (will be used by backend services)
# Format: Server=mysql;Port=3306;Database={db_name};Uid=root;Pwd=${DB_ROOT_PASSWORD};

# ============================================
# RABBITMQ CONFIGURATION
# ============================================

# RabbitMQ Admin Credentials
# IMPORTANT: Use strong password
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=your_secure_rabbitmq_password_here

# ============================================
# REDIS CONFIGURATION (if used)
# ============================================

REDIS_PASSWORD=your_secure_redis_password_here

# ============================================
# PAYMENT GATEWAY CONFIGURATION
# ============================================

# VNPay Configuration (get from VNPay dashboard)
VNPAY_TMN_CODE=your_vnpay_tmn_code
VNPAY_HASH_SECRET=your_vnpay_hash_secret
VNPAY_PAYMENT_URL=https://sandbox.vnpayment.vn/paymentv2/vpcpay.html

# PayOS Configuration (get from PayOS dashboard)
PAYOS_CLIENT_ID=your_payos_client_id
PAYOS_API_KEY=your_payos_api_key
PAYOS_CHECKSUM_KEY=your_payos_checksum_key

# Stripe Configuration (get from Stripe dashboard)
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret

# ============================================
# EMAIL CONFIGURATION
# ============================================

# SMTP Configuration (for sending emails)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_specific_password
SMTP_FROM=noreply@medcure.com.vn
SMTP_FROM_NAME=MedCure Booking System

# ============================================
# STORAGE CONFIGURATION
# ============================================

# AWS S3 Configuration (if using S3 for file storage)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=ap-southeast-1
AWS_S3_BUCKET=bookingcare-production

# ============================================
# LOGGING AND MONITORING
# ============================================

# Serilog Configuration
SERILOG_MINIMUM_LEVEL=Information
SERILOG_SEQ_URL=http://seq:5341

# ============================================
# SECURITY
# ============================================

# JWT Configuration
JWT_SECRET_KEY=your_jwt_secret_key_min_32_characters_here
JWT_ISSUER=https://api.medcure.com.vn
JWT_AUDIENCE=https://medcure.com.vn
JWT_EXPIRATION_MINUTES=60

# ============================================
# CORS CONFIGURATION
# ============================================

ALLOWED_ORIGINS=https://medcure.com.vn,https://www.medcure.com.vn,https://admin.medcure.com.vn

# ============================================
# OTHER SETTINGS
# ============================================

# Environment
ASPNETCORE_ENVIRONMENT=Production
NODE_ENV=production

# Timezone
TZ=Asia/Ho_Chi_Minh
```

### 5.3. Lưu file

**Lưu file**: `Ctrl + O` → `Enter` → `Ctrl + X`

### 5.4. Bảo mật file

```bash
# Set permissions (chỉ owner đọc được)
chmod 600 .env.production

# Verify
ls -la .env.production
```

**Expected output**: `-rw------- 1 ubuntu ubuntu ... .env.production`

### 5.5. Verify content

```bash
# Show first 20 lines (không show passwords)
head -n 20 .env.production

# Check specific variables
grep "VITE_API_URL" .env.production
grep "DOCKER_USERNAME" .env.production
```

**Expected**: Các giá trị bạn vừa nhập

---

## Bước 6: Cấu hình Nginx cho 3 domains

### 6.1. Remove default Nginx config

```bash
sudo rm /etc/nginx/sites-enabled/default
```

### 6.2. Tạo config cho Patient Portal (medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-patient
```

Paste nội dung:

```nginx
# Patient Portal - medcure.com.vn
server {
    listen 80;
    listen [::]:80;
    server_name medcure.com.vn www.medcure.com.vn;

    # Logging
    access_log /var/log/nginx/medcure-patient-access.log;
    error_log /var/log/nginx/medcure-patient-error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy to Docker container
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

**Lưu**: `Ctrl + O` → `Enter` → `Ctrl + X`

### 6.3. Tạo config cho Admin Portal (admin.medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-admin
```

Paste nội dung:

```nginx
# Admin Portal - admin.medcure.com.vn
server {
    listen 80;
    listen [::]:80;
    server_name admin.medcure.com.vn;

    # Logging
    access_log /var/log/nginx/medcure-admin-access.log;
    error_log /var/log/nginx/medcure-admin-error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy to Docker container
    location / {
        proxy_pass http://localhost:5174;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

**Lưu**: `Ctrl + O` → `Enter` → `Ctrl + X`

### 6.4. Tạo config cho API Gateway (api.medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-api
```

Paste nội dung:

```nginx
# API Gateway - api.medcure.com.vn
server {
    listen 80;
    listen [::]:80;
    server_name api.medcure.com.vn;

    # Logging
    access_log /var/log/nginx/medcure-api-access.log;
    error_log /var/log/nginx/medcure-api-error.log;

    # Increase max body size for file uploads
    client_max_body_size 50M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # API endpoints
    location / {
        proxy_pass http://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts for API calls
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # WebSocket support for SignalR
    location /hubs/ {
        proxy_pass http://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://localhost:5001/health;
        proxy_set_header Host $host;
    }
}

# WebSocket connection upgrade mapping
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
```

**Lưu**: `Ctrl + O` → `Enter` → `Ctrl + X`

### 6.5. Enable sites

```bash
# Create symbolic links
sudo ln -s /etc/nginx/sites-available/medcure-patient /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-admin /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-api /etc/nginx/sites-enabled/

# Verify symbolic links
ls -la /etc/nginx/sites-enabled/
```

**Expected output**:
```
medcure-patient -> /etc/nginx/sites-available/medcure-patient
medcure-admin -> /etc/nginx/sites-available/medcure-admin
medcure-api -> /etc/nginx/sites-available/medcure-api
```

### 6.6. Test Nginx configuration

```bash
sudo nginx -t
```

**Expected output**:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 6.7. Reload Nginx

```bash
sudo systemctl reload nginx
```

---

## Bước 7: Cài đặt SSL Certificates

### 7.1. Install Certbot

```bash
# Install Certbot and Nginx plugin
sudo apt install -y certbot python3-certbot-nginx
```

### 7.2. Obtain SSL certificates cho TẤT CẢ domains

**⚠️ QUAN TRỌNG**: Chạy lệnh này **MỘT LẦN** cho tất cả domains:

```bash
sudo certbot --nginx -d medcure.com.vn -d www.medcure.com.vn -d admin.medcure.com.vn -d api.medcure.com.vn
```

Khi được hỏi:
1. **Email**: Nhập email của bạn (để nhận thông báo renew)
2. **Terms of Service**: Nhập `Y` (Yes)
3. **Share email**: Nhập `N` (No) hoặc `Y` (tùy ý)
4. **Redirect HTTP to HTTPS**: Nhập `2` (Yes, redirect)

**Expected output**:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/medcure.com.vn/fullchain.pem
Key is saved at: /etc/letsencrypt/live/medcure.com.vn/privkey.pem
This certificate expires on 2026-03-16.
```

### 7.3. Verify SSL certificates

```bash
# List certificates
sudo certbot certificates

# Check Nginx config (should have SSL directives now)
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### 7.4. Test auto-renewal

```bash
# Dry run to test renewal
sudo certbot renew --dry-run
```

**Expected output**: `Congratulations, all simulated renewals succeeded`

### 7.5. Verify cron job for auto-renewal

```bash
# Certbot automatically creates a systemd timer
sudo systemctl status certbot.timer
```

**Expected output**: `Active: active (waiting)`

---

## Bước 8: Build và Deploy Docker Containers

### 8.1. Load environment variables

```bash
cd /home/ubuntu/projects/booking-care-integration

# Load .env.production
export $(grep -v '^#' .env.production | xargs)

# Verify loaded variables
echo "API URL: $VITE_API_URL"
echo "Docker Username: $DOCKER_USERNAME"
```

**Expected**: Hiển thị các giá trị từ .env.production

### 8.2. Build Docker images

⚠️ **LƯU Ý**: Quá trình này sẽ mất **15-30 phút**

```bash
cd /home/ubuntu/projects/booking-care-integration

# Build ALL images
docker-compose build --no-cache
```

**Expected output**: 
- Frontend services: `Successfully tagged hiumx/bookingcare-frontend:v1.0.0`
- Backend services: Build logs cho các microservices
- Không có errors

### 8.3. Verify images được build

```bash
docker images | grep bookingcare
```

**Expected output**: Danh sách images với tags v1.0.0

### 8.4. Start containers

```bash
cd /home/ubuntu/projects/booking-care-integration

# Start tất cả services
docker-compose up -d

# Wait for containers to start (30-60 seconds)
sleep 60
```

### 8.5. Check containers status

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected output**: Tất cả containers đều `Up` và healthy

### 8.6. Check logs

```bash
# Check API Gateway logs
docker-compose logs api-gateway | tail -20

# Check Frontend logs
docker-compose logs ui-user | tail -20
docker-compose logs ui-admin | tail -20

# Check for errors
docker-compose logs | grep -i error | tail -20
```

### 8.7. Monitor containers

```bash
# Watch container status (Ctrl+C to exit)
watch -n 5 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

---

## Bước 9: Verify Deployment

### 9.1. Test internal endpoints (từ server)

```bash
# Test Patient UI
curl -I http://localhost:5173

# Test Admin UI
curl -I http://localhost:5174

# Test API Gateway
curl -I http://localhost:5001/health

# Test API Gateway với proper response
curl http://localhost:5001/health
```

**Expected**: Tất cả trả về HTTP/1.1 200 OK

### 9.2. Test domains (từ server)

```bash
# Test Patient Portal
curl -I https://medcure.com.vn

# Test Admin Portal
curl -I https://admin.medcure.com.vn

# Test API Gateway
curl -I https://api.medcure.com.vn/health

# Test API Gateway health với JSON response
curl https://api.medcure.com.vn/health
```

**Expected**: Tất cả trả về HTTP/2 200 OK (với HTTPS)

### 9.3. Test từ browser

**Mở browser và test:**

1. **Patient Portal**: https://medcure.com.vn
   - ✅ Website load được
   - ✅ SSL certificate hợp lệ (icon ổ khóa xanh)
   - ✅ Không có CORS errors trong Console
   - ✅ API calls đi đến `https://api.medcure.com.vn/api/`

2. **Admin Portal**: https://admin.medcure.com.vn
   - ✅ Website load được
   - ✅ SSL certificate hợp lệ
   - ✅ Không có CORS errors trong Console
   - ✅ API calls đi đến `https://api.medcure.com.vn/api/`

3. **API Gateway**: https://api.medcure.com.vn/health
   - ✅ Trả về JSON: `{"status":"Healthy"}`

### 9.4. Check browser DevTools

Mở DevTools (F12) → **Console tab**:
- ✅ Không có errors màu đỏ
- ✅ Không có CORS errors
- ✅ Không có "Mixed Content" warnings

Mở DevTools (F12) → **Network tab**:
- ✅ Các API requests đi đến `https://api.medcure.com.vn`
- ✅ Status codes: 200 OK hoặc 401 (nếu chưa login)
- ✅ Response times < 3s

### 9.5. Test www redirect

```bash
# Test www subdomain
curl -I https://www.medcure.com.vn
```

**Expected**: Nên access được (hoặc redirect về medcure.com.vn)

### 9.6. Verify environment variables trong containers

```bash
# Check frontend env vars
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env | head -10

# Should show:
# VITE_API_URL=https://api.medcure.com.vn/api
# VITE_RECAPTCHA_SITE_KEY=...
```

### 9.7. Check database connections

```bash
# Check Auth service logs for database connection
docker-compose logs auth-service | grep -i "database"

# Should NOT see connection errors
```

---

## Bước 10: Cấu hình Cloudflare SSL

### 10.1. Login vào Cloudflare Dashboard

1. Truy cập: https://dash.cloudflare.com/
2. Chọn domain: **medcure.com.vn**

### 10.2. Cấu hình SSL/TLS mode

1. Vào: **SSL/TLS** → **Overview**
2. Chọn SSL/TLS encryption mode: **Full (strict)**
   - ⚠️ KHÔNG chọn "Flexible" (sẽ gây lỗi redirect loop)
   - ✅ Chọn "Full (strict)" để Cloudflare verify Let's Encrypt certificate

![Cloudflare SSL Mode](https://developers.cloudflare.com/ssl/static/ssl-mode-full-strict.png)

3. Click **Save**

### 10.3. Enable Always Use HTTPS

1. Vào: **SSL/TLS** → **Edge Certificates**
2. Bật: **Always Use HTTPS** → ON
3. Bật: **Automatic HTTPS Rewrites** → ON

### 10.4. Cấu hình HSTS (Optional but Recommended)

1. Vào: **SSL/TLS** → **Edge Certificates**
2. Scroll xuống **HTTP Strict Transport Security (HSTS)**
3. Click **Enable HSTS**
4. Settings:
   - Max Age: **6 months** (15768000 seconds)
   - Apply HSTS to subdomains: **ON**
   - Preload: **OFF** (chỉ bật sau khi test kỹ)
   - No-Sniff Header: **ON**
5. Click **Save**

### 10.5. Clear Cloudflare cache

1. Vào: **Caching** → **Configuration**
2. Click **Purge Everything**
3. Confirm

### 10.6. Test lại từ browser

1. Clear browser cache: `Ctrl + Shift + Delete`
2. Test lại tất cả domains:
   - https://medcure.com.vn
   - https://admin.medcure.com.vn
   - https://api.medcure.com.vn/health

**Expected**: Tất cả load nhanh, có SSL, không errors

---

## 🎯 Post-Deployment Checklist

### ✅ Infrastructure

- [ ] EC2 instance đang chạy
- [ ] Docker và Docker Compose đã cài đặt
- [ ] Nginx đang chạy và configured
- [ ] SSL certificates đã install cho tất cả domains
- [ ] Firewall configured (ports 80, 443 open)

### ✅ DNS & SSL

- [ ] DNS records đã propagate (test: `nslookup medcure.com.vn`)
- [ ] SSL certificates valid cho tất cả domains
- [ ] Cloudflare SSL mode: Full (strict)
- [ ] Always Use HTTPS: Enabled
- [ ] No SSL/TLS errors trong browser

### ✅ Application

- [ ] Tất cả Docker containers đang chạy và healthy
- [ ] Frontend services accessible: medcure.com.vn, admin.medcure.com.vn
- [ ] API Gateway accessible: api.medcure.com.vn/health
- [ ] No CORS errors trong browser console
- [ ] API calls đi đến correct domain (api.medcure.com.vn)
- [ ] Database connections working
- [ ] RabbitMQ running

### ✅ Configuration

- [ ] .env.production file created với correct values
- [ ] Environment variables loaded correctly
- [ ] Frontend built với production API URL
- [ ] Backend services using production config
- [ ] OAuth clients configured (Google, Facebook)
- [ ] Payment gateways configured (VNPay, PayOS, Stripe)

### ✅ Testing

- [ ] Patient portal loads and works
- [ ] Admin portal loads and works
- [ ] User registration works
- [ ] User login works (email/password)
- [ ] OAuth login works (Google, Facebook)
- [ ] API endpoints return correct responses
- [ ] WebSocket connections work (SignalR)
- [ ] File uploads work
- [ ] Email notifications work

---

## 🛠️ Troubleshooting

### Issue 1: Website không load (502 Bad Gateway)

**Nguyên nhân**: Docker containers chưa start hoặc đã exit

**Giải pháp**:
```bash
# Check containers
docker ps -a

# Check logs
docker-compose logs [service_name]

# Restart containers
docker-compose restart

# If still not working, rebuild
docker-compose down
docker-compose up -d --build
```

### Issue 2: CORS errors trong browser console

**Triệu chứng**: `Access to XMLHttpRequest blocked by CORS policy`

**Giải pháp**:
```bash
# 1. Verify frontend API URL
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env | grep API_URL

# 2. Check backend CORS config
docker logs bookingcare_api_gateway 2>&1 | grep -i "AllowedOrigins"

# 3. Rebuild frontend với correct API URL
cd /home/ubuntu/projects/booking-care-integration
export $(grep -v '^#' .env.production | xargs)
docker-compose build --no-cache ui-user ui-admin
docker-compose up -d --force-recreate ui-user ui-admin
```

### Issue 3: SSL certificate errors

**Triệu chứng**: Browser hiển thị "Your connection is not private"

**Giải pháp**:
```bash
# 1. Verify certificates
sudo certbot certificates

# 2. Renew certificates
sudo certbot renew --force-renewal

# 3. Reload Nginx
sudo systemctl reload nginx

# 4. Check Cloudflare SSL mode (must be Full or Full Strict)
# Go to Cloudflare Dashboard → SSL/TLS → Full (strict)
```

### Issue 4: Redirect loop

**Triệu chứng**: Browser keeps redirecting, never loads page

**Nguyên nhân**: Cloudflare SSL mode = "Flexible"

**Giải pháp**:
1. Login Cloudflare Dashboard
2. SSL/TLS → Overview
3. Change to: **Full (strict)**
4. Clear browser cache
5. Test lại

### Issue 5: Database connection errors

**Triệu chứng**: Backend logs hiển thị "Unable to connect to database"

**Giải pháp**:
```bash
# 1. Check MySQL container
docker ps | grep mysql

# 2. Check MySQL logs
docker-compose logs mysql

# 3. Test connection from backend container
docker exec bookingcare_api_gateway ping mysql

# 4. Verify DB_ROOT_PASSWORD in .env.production
grep DB_ROOT_PASSWORD /home/ubuntu/projects/booking-care-integration/.env.production

# 5. Restart database and backend
docker-compose restart mysql
sleep 30
docker-compose restart api-gateway auth-service
```

### Issue 6: Frontend build với sai API URL

**Triệu chứng**: Browser DevTools shows API calls going to localhost or wrong domain

**Giải pháp**:
```bash
# 1. Verify .env.production
grep VITE_API_URL /home/ubuntu/projects/booking-care-integration/.env.production
# MUST be: VITE_API_URL=https://api.medcure.com.vn/api

# 2. Reload environment variables
cd /home/ubuntu/projects/booking-care-integration
export $(grep -v '^#' .env.production | xargs)
echo "Verify: $VITE_API_URL"

# 3. Rebuild frontend FROM SCRATCH
docker-compose stop ui-user ui-admin
docker-compose rm -f ui-user ui-admin
docker-compose build --no-cache ui-user ui-admin
docker-compose up -d ui-user ui-admin

# 4. Clear browser cache (Ctrl+Shift+Delete)
# 5. Test lại
```

### Issue 7: OAuth login không hoạt động

**Triệu chứng**: Lỗi "redirect_uri_mismatch" hoặc "invalid_client"

**Giải pháp Google OAuth**:
1. Truy cập: https://console.cloud.google.com/apis/credentials
2. Chọn OAuth 2.0 Client ID của bạn
3. **Authorized JavaScript origins** - Thêm:
   - `https://medcure.com.vn`
   - `https://admin.medcure.com.vn`
4. **Authorized redirect URIs** - Thêm:
   - `https://medcure.com.vn/auth/google/callback`
   - `https://admin.medcure.com.vn/auth/google/callback`
   - `https://api.medcure.com.vn/api/v1.0/auth/google/callback`
5. Click **Save**

**Giải pháp Facebook OAuth**:
1. Truy cập: https://developers.facebook.com/apps/
2. Chọn app của bạn
3. **Settings** → **Basic**:
   - **App Domains**: Thêm `medcure.com.vn`
4. **Facebook Login** → **Settings**:
   - **Valid OAuth Redirect URIs**: Thêm:
     - `https://medcure.com.vn/auth/facebook/callback`
     - `https://admin.medcure.com.vn/auth/facebook/callback`
     - `https://api.medcure.com.vn/api/v1.0/auth/facebook/callback`
5. Click **Save Changes**

### Issue 8: Containers keep restarting

**Giải pháp**:
```bash
# Check which containers are restarting
docker ps -a

# Check logs
docker logs [container_name] --tail 100

# Common causes:
# - Port already in use
# - Missing environment variables
# - Configuration errors
# - Database not ready

# Fix: Check logs and adjust configuration
```

---

## 📊 Monitoring Commands

### Check system resources

```bash
# CPU, Memory usage
htop

# Disk usage
df -h

# Docker stats
docker stats

# Check logs size
du -sh /var/log/nginx/
```

### Monitor containers

```bash
# Real-time logs
docker-compose logs -f

# Logs of specific service
docker-compose logs -f api-gateway

# Check health status
docker inspect bookingcare_ui_user --format='{{.State.Health.Status}}'
```

### Monitor Nginx

```bash
# Check Nginx status
sudo systemctl status nginx

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Check access logs
sudo tail -f /var/log/nginx/medcure-patient-access.log
```

### Monitor SSL certificates

```bash
# Check expiry date
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Check certificate validity from browser
openssl s_client -connect medcure.com.vn:443 -servername medcure.com.vn | openssl x509 -noout -dates
```

---

## 🔄 Update & Maintenance

### Update frontend code

```bash
cd /home/ubuntu/projects/booking-care-system-ui
git pull origin feature/fe-deployment_HieuMX

cd /home/ubuntu/projects/booking-care-system-ui-admin
git pull origin feature/fe-deployment_HieuMX

cd /home/ubuntu/projects/booking-care-integration
export $(grep -v '^#' .env.production | xargs)
docker-compose build ui-user ui-admin
docker-compose up -d --force-recreate ui-user ui-admin
```

### Update backend code

```bash
cd /home/ubuntu/projects/BookingCareSystemBackend
git pull origin feature/api-deployment_HieuMX

cd /home/ubuntu/projects/booking-care-integration
docker-compose build api-gateway
docker-compose up -d --force-recreate api-gateway
```

### Backup databases

```bash
# Create backup directory
mkdir -p /home/ubuntu/backups

# Backup all databases
docker exec mysql mysqldump -u root -p${DB_ROOT_PASSWORD} --all-databases > /home/ubuntu/backups/backup_$(date +%Y%m%d_%H%M%S).sql
```

### Clean up old Docker images

```bash
# Remove unused images
docker image prune -a

# Remove stopped containers
docker container prune

# Remove unused volumes
docker volume prune
```

---

## 📞 Support

Nếu gặp vấn đề, check:
1. **Container logs**: `docker-compose logs [service_name]`
2. **Nginx logs**: `/var/log/nginx/`
3. **System logs**: `journalctl -xe`
4. **Docker status**: `docker ps -a`

## 🎉 Hoàn thành!

Congratulations! Hệ thống BookingCare của bạn đã được deploy thành công với production domains! 🚀

**Live URLs**:
- 👥 Patient Portal: https://medcure.com.vn
- 👨‍💼 Admin Portal: https://admin.medcure.com.vn
- 🔌 API Gateway: https://api.medcure.com.vn

Enjoy your deployment! 🎊
