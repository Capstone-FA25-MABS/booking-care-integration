# 🚀 Guideline Setup EC2 sau khi config DNS

## 📋 Prerequisites

- ✅ DNS đã được config trên Cloudflare:
  - `medcure.com.vn` → `13.250.98.119` (Proxied)
  - `admin.medcure.com.vn` → `13.250.98.119` (Proxied)
  - `api.medcure.com.vn` → `13.250.98.119` (DNS only)
- ✅ EC2 instance đang chạy
- ✅ Security Group mở port 22, 80, 443

---

## 🎯 Tổng quan các bước

1. [Cài đặt môi trường cơ bản](#bước-1-cài-đặt-môi-trường-cơ-bản)
2. [Cài đặt và cấu hình Nginx](#bước-2-cài-đặt-và-cấu-hình-nginx)
3. [Cài đặt SSL Certificate](#bước-3-cài-đặt-ssl-certificate)
4. [Deploy ứng dụng với Docker](#bước-4-deploy-ứng-dụng-với-docker)
5. [Kiểm tra và xác nhận](#bước-5-kiểm-tra-và-xác-nhận)
6. [Cấu hình Cloudflare SSL](#bước-6-cấu-hình-cloudflare-ssl)

---

## BƯỚC 1: Cài đặt môi trường cơ bản

### 1.1. SSH vào EC2

```bash
ssh -i your-key.pem ubuntu@13.250.98.119
```

### 1.2. Update hệ thống

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.3. Cài đặt Docker

```bash
# Download và cài đặt Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Thêm user vào docker group
sudo usermod -aG docker $USER

# Apply changes (hoặc logout và login lại)
newgrp docker

# Cài Docker Compose
sudo apt install docker-compose-plugin -y

# Verify installation
docker --version
docker compose version
```

### 1.4. Cài đặt Nginx

```bash
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## BƯỚC 2: Cài đặt và cấu hình Nginx

### 2.1. Xóa config mặc định

```bash
sudo rm /etc/nginx/sites-enabled/default
```

### 2.2. Tạo config cho Patient UI

```bash
sudo nano /etc/nginx/sites-available/medcure-patient
```

**Paste nội dung sau:**

```nginx
server {
    listen 80;
    server_name medcure.com.vn www.medcure.com.vn;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

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
        proxy_read_timeout 86400;
    }
}
```

**Lưu file:** `Ctrl + X` → `Y` → `Enter`

### 2.3. Tạo config cho Admin UI

```bash
sudo nano /etc/nginx/sites-available/medcure-admin
```

**Paste nội dung sau:**

```nginx
server {
    listen 80;
    server_name admin.medcure.com.vn;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

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
        proxy_read_timeout 86400;
    }
}
```

**Lưu file:** `Ctrl + X` → `Y` → `Enter`

### 2.4. Tạo config cho API

```bash
sudo nano /etc/nginx/sites-available/medcure-api
```

**Paste nội dung sau:**

```nginx
server {
    listen 80;
    server_name api.medcure.com.vn;

    # Max upload size
    client_max_body_size 50M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # API Gateway
    location / {
        proxy_pass http://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;
    }

    # SignalR Hub - WebSocket
    location /api/hubs {
        proxy_pass http://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

**Lưu file:** `Ctrl + X` → `Y` → `Enter`

### 2.5. Enable các site configs

```bash
# Tạo symbolic links
sudo ln -s /etc/nginx/sites-available/medcure-patient /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-admin /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-api /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

✅ **Expected output:** `nginx: configuration file /etc/nginx/nginx.conf test is successful`

---

## BƯỚC 3: Cài đặt SSL Certificate

### 3.1. Cài Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

### 3.2. Tạo SSL certificates

```bash
sudo certbot --nginx -d medcure.com.vn -d www.medcure.com.vn -d admin.medcure.com.vn -d api.medcure.com.vn
```

**Làm theo hướng dẫn:**
1. Nhập email của bạn
2. Agree to terms: `Y`
3. Share email: `N` (optional)
4. Redirect HTTP to HTTPS: `2` (Yes, redirect)

### 3.3. Verify auto-renewal

```bash
sudo certbot renew --dry-run
```

✅ **Expected output:** `Congratulations, all simulated renewals succeeded`

---

## BƯỚC 4: Deploy ứng dụng với Docker

### 4.1. Tạo thư mục project

```bash
mkdir -p ~/bookingcare
cd ~/bookingcare
```

### 4.2. Clone repository

```bash
git clone https://github.com/Capstone-FA25-MABS/booking-care-integration.git
cd booking-care-integration
```

### 4.3. Copy và cấu hình .env

**Option A: Copy từ local (recommended)**

Từ máy local, chạy:

```bash
scp -i your-key.pem /path/to/local/.env ubuntu@13.250.98.119:~/bookingcare/booking-care-integration/
```

**Option B: Tạo mới trên server**

```bash
nano .env
```

Paste nội dung từ `.env` local và đảm bảo các biến sau đúng:

```env
# Frontend URLs
VITE_API_URL=https://api.medcure.com.vn/api

# Frontend redirect URLs
FRONTEND_CLIENT_BASEURL=https://medcure.com.vn/
FRONTEND_ADMIN_BASEURL=https://admin.medcure.com.vn/
FRONTEND_DEFAULT_BASEURL=https://medcure.com.vn/
FRONTEND_HOSTMAP_ADMIN=admin
FRONTEND_HOSTMAP_CLIENT=client
```

### 4.4. Pull và start containers

```bash
# Pull images từ Docker Hub
docker compose pull

# Start tất cả services
docker compose up -d

# Đợi khoảng 2-3 phút để các services khởi động

# Kiểm tra trạng thái
docker compose ps
```

✅ **Expected output:** Tất cả containers đều ở trạng thái `Up` hoặc `healthy`

---

## BƯỚC 5: Kiểm tra và xác nhận

### 5.1. Kiểm tra Docker containers

```bash
# Xem logs
docker compose logs -f --tail=50

# Kiểm tra specific service
docker compose logs api-gateway
docker compose logs ui-user
docker compose logs ui-admin
```

### 5.2. Test endpoints từ server

```bash
# Test Patient UI (internal)
curl -I http://localhost:5173

# Test Admin UI (internal)
curl -I http://localhost:5174

# Test API Gateway (internal)
curl http://localhost:5001/health

# Test domains (external)
curl -I https://medcure.com.vn
curl -I https://admin.medcure.com.vn
curl https://api.medcure.com.vn/health
```

### 5.3. Test từ trình duyệt

Mở trình duyệt và truy cập:

- ✅ `https://medcure.com.vn` - Patient UI
- ✅ `https://admin.medcure.com.vn` - Admin UI
- ✅ `https://api.medcure.com.vn/health` - API health check

### 5.4. Kiểm tra SSL

```bash
# Check certificate
openssl s_client -connect medcure.com.vn:443 -servername medcure.com.vn < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Check all domains
for domain in medcure.com.vn admin.medcure.com.vn api.medcure.com.vn; do
  echo "Checking $domain..."
  openssl s_client -connect $domain:443 -servername $domain < /dev/null 2>/dev/null | openssl x509 -noout -subject -dates
done
```

---

## BƯỚC 6: Cấu hình Cloudflare SSL

### 6.1. Login vào Cloudflare Dashboard

Truy cập: https://dash.cloudflare.com/

### 6.2. Chọn domain `medcure.com.vn`

### 6.3. Vào SSL/TLS settings

Chọn **SSL/TLS** trong menu bên trái

### 6.4. Chọn SSL mode

Chọn **Full** hoặc **Full (strict)** mode:

- **Full**: Cloudflare sẽ kết nối qua HTTPS đến origin server, chấp nhận self-signed cert
- **Full (strict)**: Cloudflare yêu cầu valid SSL certificate từ CA (Let's Encrypt) - **Recommended**

### 6.5. Enable Always Use HTTPS

Vào **SSL/TLS** → **Edge Certificates** → Enable:
- ✅ Always Use HTTPS
- ✅ Automatic HTTPS Rewrites

---

## 🎉 HOÀN THÀNH!

Hệ thống đã được setup thành công. Bạn có thể:

1. ✅ Truy cập Patient UI: https://medcure.com.vn
2. ✅ Truy cập Admin UI: https://admin.medcure.com.vn
3. ✅ API hoạt động: https://api.medcure.com.vn

---

## 🔧 Troubleshooting

### Lỗi 502 Bad Gateway

```bash
# Kiểm tra containers
docker compose ps

# Restart containers
docker compose restart

# Xem logs
docker compose logs -f
```

### Lỗi SSL Certificate

```bash
# Kiểm tra certificates
sudo certbot certificates

# Renew thủ công
sudo certbot renew

# Force renew
sudo certbot renew --force-renewal
```

### Nginx không start

```bash
# Kiểm tra config
sudo nginx -t

# Xem error logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### Docker container không start

```bash
# Xem logs chi tiết
docker compose logs <service-name>

# Restart specific service
docker compose restart <service-name>

# Rebuild nếu cần
docker compose up -d --force-recreate
```

### Port đã được sử dụng

```bash
# Check ports
sudo netstat -tlnp | grep -E ':(80|443|5001|5173|5174)'

# Hoặc dùng ss
sudo ss -tlnp | grep -E ':(80|443|5001|5173|5174)'

# Kill process nếu cần
sudo kill -9 <PID>
```

---

## 📝 Commands Tham khảo

```bash
# Docker Management
docker compose up -d          # Start all services
docker compose down           # Stop all services
docker compose restart        # Restart all services
docker compose ps             # Check status
docker compose logs -f        # View logs
docker compose pull           # Pull latest images

# Nginx Management
sudo systemctl start nginx    # Start Nginx
sudo systemctl stop nginx     # Stop Nginx
sudo systemctl restart nginx  # Restart Nginx
sudo systemctl reload nginx   # Reload config
sudo nginx -t                 # Test config

# SSL Certificate
sudo certbot renew            # Renew certificates
sudo certbot certificates     # List certificates
sudo certbot delete           # Delete certificate

# System Monitoring
htop                          # Monitor resources
docker stats                  # Docker resource usage
df -h                         # Disk usage
free -h                       # Memory usage
```

---

## 🔄 Cập nhật ứng dụng

Khi có version mới:

```bash
cd ~/bookingcare/booking-care-integration

# Pull images mới
docker compose pull

# Restart với images mới (zero-downtime)
docker compose up -d

# Xóa images cũ
docker image prune -f
```

---

## 📞 Liên hệ

Nếu gặp vấn đề, check:
1. Docker logs: `docker compose logs -f`
2. Nginx logs: `sudo tail -f /var/log/nginx/error.log`
3. System logs: `sudo journalctl -xe`

---

## 🎯 Next Steps

- [ ] Setup monitoring (Prometheus/Grafana)
- [ ] Setup backup strategy
- [ ] Configure firewall rules
- [ ] Setup log rotation
- [ ] Configure auto-scaling (if needed)
