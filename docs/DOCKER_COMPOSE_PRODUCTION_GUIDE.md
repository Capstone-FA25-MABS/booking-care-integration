# Docker Compose Production Deployment Guide

## 📋 Tổng quan

Guideline này hướng dẫn cách deploy hệ thống BookingCare trên EC2 server sử dụng Docker Compose với **production environment variables**.

## ⚠️ Điểm quan trọng

**Frontend (Vite) cần BUILD với production env vars**, không thể inject runtime!
- ❌ Sai: Pass env vars khi `docker-compose up` (không hoạt động)
- ✅ Đúng: Pass env vars khi `docker-compose build` (ARG trong Dockerfile)

## 📁 Cấu trúc thư mục trên server

```
/home/ubuntu/
├── booking-care-integration/
│   ├── docker-compose.yml
│   ├── .env.production           # ← Tạo file này
│   ├── data/                      # SQL files
│   └── ...
├── booking-care-system-ui/        # Frontend patient
│   ├── Dockerfile
│   └── ...
├── booking-care-system-ui-admin/  # Frontend admin
│   ├── Dockerfile
│   └── ...
└── BookingCareSystemBackend/      # Backend microservices
    └── ...
```

## 🔧 Bước 1: Tạo file .env.production

SSH vào server và tạo file `.env.production` trong thư mục `booking-care-integration`:

```bash
cd /home/ubuntu/booking-care-integration
nano .env.production
```

Paste nội dung sau (thay thế các giá trị `your_xxx` bằng giá trị thực):

```bash
# Production Environment Variables for Docker Build
# These variables are used when BUILDING Docker images on server

# Docker Configuration
DOCKER_USERNAME=hiumx
VERSION=v1.0.0

# API Configuration - MUST use production domain
VITE_API_URL=https://api.medcure.com.vn/api

# reCAPTCHA Configuration
# Get from: https://www.google.com/recaptcha/admin
VITE_RECAPTCHA_SITE_KEY=6LeXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# OAuth Configuration
# Google: https://console.cloud.google.com/apis/credentials
# Facebook: https://developers.facebook.com/apps/
VITE_GOOGLE_CLIENT_ID=123456789012-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
VITE_FACEBOOK_APP_ID=1234567890123456

# Device Configuration (for patient app)
VITE_DEVICE_ID=web-production

# Admin App Configuration
MABS_APP_NAME=BookingCare Admin

# Backend Configuration
FRONTEND_HOSTMAP_CLIENT=client
FRONTEND_HOSTMAP_ADMIN=admin

# RabbitMQ Configuration
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=YourSecureRabbitMQPassword123!

# Database Configuration
DB_ROOT_PASSWORD=YourSecureMySQLRootPassword123!

# Redis Configuration (if used)
REDIS_PASSWORD=YourSecureRedisPassword123!
```

**Lưu file**: `Ctrl + O` → `Enter` → `Ctrl + X`

## 🔐 Bước 2: Bảo mật file .env.production

```bash
# Set quyền chỉ owner đọc được
chmod 600 .env.production

# Verify permissions
ls -la .env.production
# Expected: -rw------- 1 ubuntu ubuntu ... .env.production
```

## 🏗️ Bước 3: Build Docker images với production config

### Option A: Build tất cả services (khuyến nghị lần đầu)

```bash
cd /home/ubuntu/booking-care-integration

# Load environment variables
export $(grep -v '^#' .env.production | xargs)

# Build tất cả images (sẽ mất 15-30 phút)
docker-compose build --no-cache

# Verify images đã build
docker images | grep bookingcare
```

**Expected output:**
```
hiumx/bookingcare-frontend              v1.0.0    abc123def456   2 minutes ago    50.2MB
hiumx/bookingcare-frontend-admin        v1.0.0    def456abc789   2 minutes ago    48.7MB
hiumx/bookingcare-api-gateway           v1.0.0    xyz789abc123   5 minutes ago    212MB
...
```

### Option B: Build chỉ frontend (nếu backend đã có image sẵn)

```bash
cd /home/ubuntu/booking-care-integration

# Load environment variables
export $(grep -v '^#' .env.production | xargs)

# Build chỉ frontend services
docker-compose build ui-user ui-admin
```

## 🚀 Bước 4: Deploy với Docker Compose

### 4.1. Khởi động services

```bash
cd /home/ubuntu/booking-care-integration

# Load environment variables
export $(grep -v '^#' .env.production | xargs)

# Start tất cả services
docker-compose up -d

# Xem logs
docker-compose logs -f
```

### 4.2. Verify containers đang chạy

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected output:**
```
NAMES                           STATUS              PORTS
bookingcare_ui_user            Up 2 minutes        0.0.0.0:5173->80/tcp
bookingcare_ui_admin           Up 2 minutes        0.0.0.0:5174->80/tcp
bookingcare_api_gateway        Up 3 minutes        0.0.0.0:5001->5001/tcp
...
```

### 4.3. Check container health

```bash
# Check health status
docker inspect bookingcare_ui_user --format='{{.State.Health.Status}}'
docker inspect bookingcare_ui_admin --format='{{.State.Health.Status}}'

# Should show: healthy
```

## ✅ Bước 5: Verify environment variables trong containers

### 5.1. Check frontend environment variables

```bash
# Check ui-user container
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env

# Should show:
# VITE_API_URL=https://api.medcure.com.vn/api
# VITE_RECAPTCHA_SITE_KEY=6LeXXXXXXXX...
# ...
```

### 5.2. Check backend environment variables

```bash
# Check API Gateway CORS settings
docker logs bookingcare_api_gateway 2>&1 | grep -i "cors"

# Check Auth service frontend URLs
docker logs bookingcare_auth_service 2>&1 | grep -i "frontend"
```

## 🧪 Bước 6: Test các endpoints

### 6.1. Test internal ports (từ server)

```bash
# Test UI User (patient)
curl -I http://localhost:5173

# Test UI Admin
curl -I http://localhost:5174

# Test API Gateway
curl -I http://localhost:5001/health
```

**Expected**: HTTP/1.1 200 OK

### 6.2. Test public domains (từ browser)

1. **Patient Portal**: https://medcure.com.vn
   - Should load homepage
   - Check browser console: No CORS errors
   - Check API calls going to: `https://api.medcure.com.vn/api/`

2. **Admin Portal**: https://admin.medcure.com.vn
   - Should load login page
   - Check browser console: No CORS errors
   - Check API calls going to: `https://api.medcure.com.vn/api/`

3. **API Gateway**: https://api.medcure.com.vn/health
   - Should return: `{"status":"Healthy"}`

## 🔄 Bước 7: Update khi có thay đổi

### 7.1. Update frontend code

```bash
cd /home/ubuntu/booking-care-integration

# Stop frontend services
docker-compose stop ui-user ui-admin

# Rebuild với code mới
export $(grep -v '^#' .env.production | xargs)
docker-compose build ui-user ui-admin

# Start lại
docker-compose up -d ui-user ui-admin

# Clear browser cache và test
```

### 7.2. Update backend code

```bash
cd /home/ubuntu/booking-care-integration

# Stop backend services
docker-compose stop api-gateway auth-service payment-service

# Pull latest images (if using pre-built images)
docker-compose pull api-gateway auth-service payment-service

# Or rebuild (if building on server)
export $(grep -v '^#' .env.production | xargs)
docker-compose build api-gateway auth-service payment-service

# Start lại
docker-compose up -d api-gateway auth-service payment-service
```

### 7.3. Update environment variables

```bash
# Edit .env.production
nano /home/ubuntu/booking-care-integration/.env.production

# Rebuild services that use updated env vars
export $(grep -v '^#' .env.production | xargs)
docker-compose build ui-user ui-admin

# Recreate containers
docker-compose up -d --force-recreate ui-user ui-admin
```

## 🛠️ Troubleshooting

### Issue 1: Frontend không connect được API

**Triệu chứng**: Browser console hiện CORS error hoặc "Network Error"

**Nguyên nhân**: Frontend build với sai `VITE_API_URL`

**Giải pháp**:
```bash
# 1. Check env trong container
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env

# 2. Nếu sai, rebuild với .env.production đúng
cd /home/ubuntu/booking-care-integration
export $(grep -v '^#' .env.production | xargs)
echo "VITE_API_URL should be: $VITE_API_URL"  # Verify trước khi build

# 3. Rebuild
docker-compose build --no-cache ui-user ui-admin

# 4. Recreate containers
docker-compose up -d --force-recreate ui-user ui-admin

# 5. Clear browser cache và test lại
```

### Issue 2: CORS errors từ backend

**Triệu chứng**: Browser console: "Access to XMLHttpRequest blocked by CORS policy"

**Giải pháp**:
```bash
# 1. Check backend CORS config
docker logs bookingcare_api_gateway 2>&1 | grep -i "AllowedOrigins"

# 2. Nếu không có medcure.com.vn, cần update backend code và rebuild
cd /home/ubuntu/BookingCareSystemBackend
# (Update appsettings.Production.json như đã làm ở bước trước)

# 3. Rebuild backend
cd /home/ubuntu/booking-care-integration
docker-compose build api-gateway communication-service
docker-compose up -d --force-recreate api-gateway communication-service
```

### Issue 3: Container exit ngay sau khi start

**Triệu chứng**: `docker ps` không thấy container, `docker ps -a` thấy status "Exited"

**Giải pháp**:
```bash
# 1. Check logs
docker logs bookingcare_ui_user

# 2. Common issues:
# - Missing build args → Rebuild với .env.production
# - Port already in use → sudo lsof -i :5173
# - Nginx config error → Check nginx.conf

# 3. Restart container
docker-compose restart ui-user
```

### Issue 4: Build bị lỗi "context" not found

**Triệu chứng**: `ERROR: build path ... either does not exist, is not accessible or is not a valid URL`

**Giải pháp**:
```bash
# Verify cấu trúc thư mục
ls -la /home/ubuntu/ | grep booking-care

# Should show:
# booking-care-integration/
# booking-care-system-ui/
# booking-care-system-ui-admin/
# BookingCareSystemBackend/

# Nếu thiếu, clone repositories:
cd /home/ubuntu
git clone https://github.com/Capstone-FA25-MABS/booking-care-system-ui.git
git clone https://github.com/Capstone-FA25-MABS/booking-care-system-ui-admin.git
```

## 📝 Quick Reference Commands

```bash
# Load environment variables
cd /home/ubuntu/booking-care-integration
export $(grep -v '^#' .env.production | xargs)

# Build all images
docker-compose build --no-cache

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f [service_name]

# Restart specific service
docker-compose restart [service_name]

# Stop all services
docker-compose down

# Remove all (including volumes)
docker-compose down -v

# Check running containers
docker ps

# Check container health
docker inspect [container_name] --format='{{.State.Health.Status}}'

# Check container env vars
docker exec [container_name] env

# Clean up old images
docker image prune -a
```

## 🎯 Deployment Checklist

- [ ] Clone tất cả 4 repositories về `/home/ubuntu/`
- [ ] Tạo file `.env.production` với đầy đủ biến môi trường
- [ ] Set permissions cho `.env.production` (`chmod 600`)
- [ ] Load environment variables (`export $(grep -v '^#' .env.production | xargs)`)
- [ ] Build Docker images (`docker-compose build`)
- [ ] Start services (`docker-compose up -d`)
- [ ] Verify containers running (`docker ps`)
- [ ] Check container health (`docker inspect ... Health.Status`)
- [ ] Test internal endpoints (`curl http://localhost:5173`)
- [ ] Test public domains (browser)
- [ ] Verify frontend API URL trong browser DevTools
- [ ] Check backend CORS logs
- [ ] Configure Cloudflare SSL mode (Full/Full Strict)
- [ ] Test OAuth login (Google/Facebook)
- [ ] Monitor logs for errors (`docker-compose logs -f`)

## 🔗 Liên quan

- [EC2_SETUP_AFTER_DNS.md](./EC2_SETUP_AFTER_DNS.md) - Nginx và SSL setup
- [EC2_NGINX_SETUP_GUIDE.md](./EC2_NGINX_SETUP_GUIDE.md) - Comprehensive guide
- [DATABASE_BACKUP_RESTORE_GUIDE.md](./DATABASE_BACKUP_RESTORE_GUIDE.md) - Database management
