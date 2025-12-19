# 🚀 Hướng dẫn Setup Nginx Reverse Proxy trên EC2

## 📋 Tổng quan

Tất cả domain đều trỏ về cùng 1 IP: `13.250.98.119`

| Domain | Service | Port nội bộ |
|--------|---------|-------------|
| `medcure.com.vn` | Patient UI | 5173 |
| `admin.medcure.com.vn` | Admin UI | 5174 |
| `api.medcure.com.vn` | API Gateway | 5001 |

---

## 📦 BƯỚC 1: Cài đặt Nginx

```bash
# SSH vào EC2
ssh -i your-key.pem ubuntu@13.250.98.119

# Update packages
sudo apt update && sudo apt upgrade -y

# Cài đặt Nginx
sudo apt install nginx -y

# Kiểm tra trạng thái
sudo systemctl status nginx

# Enable Nginx khởi động cùng hệ thống
sudo systemctl enable nginx
```

---

## 🔧 BƯỚC 2: Tạo file cấu hình Nginx

### 2.1. Xóa config mặc định

```bash
sudo rm /etc/nginx/sites-enabled/default
```

### 2.2. Tạo file config cho Patient UI (medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-patient
```

**Nội dung:**

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

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 2.3. Tạo file config cho Admin UI (admin.medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-admin
```

**Nội dung:**

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

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 2.4. Tạo file config cho API (api.medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-api
```

**Nội dung:**

```nginx
server {
    listen 80;
    server_name api.medcure.com.vn;

    # Increase max body size for file uploads
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
        
        # Timeout settings for long-running requests
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;
    }

    # SignalR Hub - WebSocket support
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
        
        # WebSocket timeout (24 hours)
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

---

## 🔗 BƯỚC 3: Enable các site config

```bash
# Tạo symbolic links
sudo ln -s /etc/nginx/sites-available/medcure-patient /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-admin /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-api /etc/nginx/sites-enabled/

# Kiểm tra cấu hình Nginx
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## 🔒 BƯỚC 4: Cài đặt SSL với Let's Encrypt

### 4.1. Cài đặt Certbot

```bash
# Cài đặt Certbot
sudo apt install certbot python3-certbot-nginx -y
```

### 4.2. Lấy SSL Certificate

```bash
# Lấy certificate cho tất cả domains
sudo certbot --nginx -d medcure.com.vn -d www.medcure.com.vn -d admin.medcure.com.vn -d api.medcure.com.vn

# Làm theo hướng dẫn:
# 1. Nhập email của bạn
# 2. Đồng ý terms of service (Y)
# 3. Chọn có muốn share email không (N)
# 4. Chọn redirect HTTP to HTTPS (2)
```

### 4.3. Kiểm tra auto-renewal

```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot tự động tạo cron job để renew certificate
```

---

## 🐳 BƯỚC 5: Deploy Docker Containers

### 5.1. Cài đặt Docker (nếu chưa có)

```bash
# Cài đặt Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Thêm user vào docker group
sudo usermod -aG docker $USER

# Log out và log in lại, hoặc:
newgrp docker

# Cài đặt Docker Compose
sudo apt install docker-compose-plugin -y

# Kiểm tra
docker --version
docker compose version
```

### 5.2. Clone repository và deploy

```bash
# Tạo thư mục
mkdir -p ~/bookingcare
cd ~/bookingcare

# Clone hoặc copy các file cần thiết
# Option 1: Git clone
git clone https://github.com/Capstone-FA25-MABS/booking-care-integration.git
cd booking-care-integration

# Option 2: Copy file .env và docker-compose.yml từ local
# scp -i your-key.pem .env ubuntu@13.250.98.119:~/bookingcare/
# scp -i your-key.pem docker-compose.yml ubuntu@13.250.98.119:~/bookingcare/
```

### 5.3. Tạo/Cập nhật file .env

```bash
nano .env
```

**Đảm bảo các biến sau đúng:**

```env
# Frontend URLs
VITE_API_URL=https://api.medcure.com.vn/api

# Frontend redirect URLs (cho backend)
FRONTEND_CLIENT_BASEURL=https://medcure.com.vn/
FRONTEND_ADMIN_BASEURL=https://admin.medcure.com.vn/
FRONTEND_DEFAULT_BASEURL=https://medcure.com.vn/
FRONTEND_HOSTMAP_ADMIN=admin
FRONTEND_HOSTMAP_CLIENT=client
```

### 5.4. Pull và chạy containers

```bash
# Pull latest images
docker compose pull

# Start all services
docker compose up -d

# Kiểm tra trạng thái
docker compose ps

# Xem logs nếu cần
docker compose logs -f
```

---

## ✅ BƯỚC 6: Kiểm tra hoạt động

### 6.1. Kiểm tra các endpoint

```bash
# Kiểm tra Patient UI
curl -I https://medcure.com.vn

# Kiểm tra Admin UI
curl -I https://admin.medcure.com.vn

# Kiểm tra API
curl https://api.medcure.com.vn/health

# Kiểm tra API endpoint
curl https://api.medcure.com.vn/api/v1/hospitals
```

### 6.2. Kiểm tra SSL Certificate

```bash
# Kiểm tra SSL
openssl s_client -connect medcure.com.vn:443 -servername medcure.com.vn < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

---

## 🔥 BƯỚC 7: Cấu hình Firewall (nếu cần)

```bash
# Mở ports cần thiết
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Kiểm tra
sudo ufw status
```

---

## 🛠️ Troubleshooting

### Lỗi 502 Bad Gateway

```bash
# Kiểm tra Docker containers đang chạy
docker compose ps

# Kiểm tra logs của container
docker compose logs api-gateway
docker compose logs ui-user
docker compose logs ui-admin

# Restart containers
docker compose restart
```

### Lỗi SSL Certificate

```bash
# Kiểm tra certificate
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Force renew
sudo certbot renew --force-renewal
```

### Kiểm tra Nginx logs

```bash
# Access logs
sudo tail -f /var/log/nginx/access.log

# Error logs
sudo tail -f /var/log/nginx/error.log
```

### Kiểm tra ports đang sử dụng

```bash
# Xem ports đang listen
sudo netstat -tlnp | grep -E ':(80|443|5001|5173|5174)'

# Hoặc dùng ss
sudo ss -tlnp | grep -E ':(80|443|5001|5173|5174)'
```

---

## 📊 Monitoring (Optional)

### Cài đặt htop để monitor resources

```bash
sudo apt install htop -y
htop
```

### Monitor Docker

```bash
# Xem resource usage
docker stats

# Xem logs real-time
docker compose logs -f --tail=100
```

---

## 🔄 Cập nhật ứng dụng

```bash
cd ~/bookingcare/booking-care-integration

# Pull images mới
docker compose pull

# Restart với images mới
docker compose up -d

# Xóa images cũ
docker image prune -f
```

---

## 📝 Quick Reference Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart all services
docker compose restart

# View logs
docker compose logs -f

# Reload Nginx
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# Check Nginx config
sudo nginx -t

# Renew SSL
sudo certbot renew
```

---

## ⚠️ Lưu ý quan trọng

1. **Cloudflare Proxy**: 
   - Với `medcure.com.vn` và `admin.medcure.com.vn` đang **Proxied** (mây cam), traffic sẽ đi qua Cloudflare
   - Vào Cloudflare → SSL/TLS → chọn **Full** hoặc **Full (strict)** để SSL hoạt động đúng
   
2. **API domain**: 
   - `api.medcure.com.vn` đang **DNS only** (mây xám), traffic đi thẳng đến server
   - SSL certificate từ Let's Encrypt sẽ hoạt động trực tiếp

3. **Backup**: Luôn backup trước khi thay đổi cấu hình
   ```bash
   sudo cp /etc/nginx/sites-available/medcure-* ~/nginx-backup/
   ```


## 📊 BƯỚC 8: Cấu hình Nginx cho Prometheus & Grafana (Optional)

### 8.1. Tổng quan

| Domain | Service | Port nội bộ |
|--------|---------|-------------|
| `monitoring.medcure.com.vn` | Grafana | 3000 |
| `prometheus.medcure.com.vn` | Prometheus | 9090 |

### 8.2. Tạo file config cho Grafana (monitoring.medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-grafana
```

**Nội dung:**

```nginx
server {
    listen 80;
    server_name monitoring.medcure.com.vn;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Grafana
    location / {
        proxy_pass http://localhost:3000;
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

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 8.3. Tạo file config cho Prometheus (prometheus.medcure.com.vn)

```bash
sudo nano /etc/nginx/sites-available/medcure-prometheus
```

**Nội dung:**

```nginx
server {
    listen 80;
    server_name prometheus.medcure.com.vn;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Prometheus
    location / {
        proxy_pass http://localhost:9090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### 8.4. Enable các site config

```bash
# Tạo symbolic links
sudo ln -s /etc/nginx/sites-available/medcure-grafana /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/medcure-prometheus /etc/nginx/sites-enabled/

# Kiểm tra cấu hình Nginx
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### 8.5. Cấu hình SSL cho Monitoring services

```bash
# Lấy SSL certificate cho monitoring domains
sudo certbot --nginx -d monitoring.medcure.com.vn -d prometheus.medcure.com.vn
```

### 8.6. Kiểm tra hoạt động

```bash
# Kiểm tra Grafana
curl -I https://monitoring.medcure.com.vn

# Kiểm tra Prometheus
curl -I https://prometheus.medcure.com.vn
```