# Hướng dẫn cấu hình Domain cho Production

## 📋 Thông tin Domain mới

| Service | Domain | URL |
|---------|--------|-----|
| Frontend Patient | medcure.com.vn | https://medcure.com.vn |
| Frontend Admin | admin.medcure.com.vn | https://admin.medcure.com.vn |
| Backend API | api.medcure.com.vn | https://api.medcure.com.vn |

---

## 🔧 CÁC FILE CẦN CẬP NHẬT

### 1. Frontend Patient (booking-care-system-ui)

#### File: `.env.production`
```env
VITE_RECAPTCHA_SITE_KEY=6LcV_KUrAAAAANoaMiIxrwva-Sj6h0w-0zXkRuWp
VITE_API_URL=https://api.medcure.com.vn/api
VITE_GOOGLE_CLIENT_ID=766011988725-2ef6bioidme1bur67ndammjj22cpefo9.apps.googleusercontent.com
VITE_FACEBOOK_APP_ID=1157258869837908
VITE_DEVICE_ID=68ca20290a4096a8570e72b2
```

---

### 2. Frontend Admin (booking-care-system-ui-admin)

#### File: `.env.production`
```env
MABS_APP_NAME=BookingCare
VITE_RECAPTCHA_SITE_KEY=6LcV_KUrAAAAANoaMiIxrwva-Sj6h0w-0zXkRuWp
VITE_API_URL=https://api.medcure.com.vn/api
VITE_GOOGLE_CLIENT_ID=766011988725-2ef6bioidme1bur67ndammjj22cpefo9.apps.googleusercontent.com
VITE_FACEBOOK_APP_ID=1157258869837908
```

---

### 3. Backend - API Gateway (BookingCareSystemBackend)

#### File: `src/ApiGateway/BookingCare.ApiGateway.Ocelot/appsettings.Production.json`
```json
{
  "AllowedOrigins": [
    "https://medcure.com.vn",
    "https://admin.medcure.com.vn",
    "http://medcure.com.vn",
    "http://admin.medcure.com.vn"
  ]
}
```

---

### 4. Backend - Communication Service (SignalR CORS)

#### File: `src/Services/BookingCare.Services.Communication/Program.cs`
Cập nhật CORS policy tại dòng ~130:
```csharp
.WithOrigins(
    "https://medcure.com.vn",
    "https://admin.medcure.com.vn",
    "http://medcure.com.vn",
    "http://admin.medcure.com.vn"
)
```

Hoặc tốt hơn, nên đọc từ config:
```csharp
var allowedOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>();
// ...
.WithOrigins(allowedOrigins ?? Array.Empty<string>())
```

#### Thêm vào `src/Services/BookingCare.Services.Communication/appsettings.Production.json`:
```json
{
  "AllowedOrigins": [
    "https://medcure.com.vn",
    "https://admin.medcure.com.vn"
  ]
}
```

---

### 5. Backend - Payment Service (VNPay, PayOS, Stripe callback URLs)

#### File: `src/Services/BookingCare.Services.Payment/appsettings.Production.json`
```json
{
  "VNPayConfiguration": {
    "ReturnUrl": "https://api.medcure.com.vn/api/v1.0/vnpay/callback"
  },
  "PayOSConfiguration": {
    "ReturnUrl": "https://api.medcure.com.vn/api/v1.0/payos/payos-return",
    "CancelUrl": "https://api.medcure.com.vn/api/v1.0/payos/cancel-callback"
  },
  "StripeConfiguration": {
    "SuccessUrl": "https://api.medcure.com.vn/api/v1.0/stripe/success",
    "CancelUrl": "https://api.medcure.com.vn/api/v1.0/stripe/cancel"
  }
}
```

---

### 6. Integration Docker Compose Environment

#### File: `booking-care-integration/.env`
```env
# Frontend UI Configuration
VITE_API_URL=https://api.medcure.com.vn/api

# Frontend URLs for Backend redirect
FRONTEND_CLIENT_BASEURL=https://medcure.com.vn/
FRONTEND_ADMIN_BASEURL=https://admin.medcure.com.vn/
FRONTEND_DEFAULT_BASEURL=https://medcure.com.vn/
FRONTEND_HOSTMAP_ADMIN=admin
FRONTEND_HOSTMAP_CLIENT=client
```

#### File: `booking-care-integration/docker-compose.yml`
Cập nhật FrontendOptions:
```yaml
environment:
  - FrontendOptions__Client__BaseUrl=https://medcure.com.vn/
  - FrontendOptions__Admin__BaseUrl=https://admin.medcure.com.vn/
  - FrontendOptions__HostMap__medcure.com.vn=client
  - FrontendOptions__HostMap__admin.medcure.com.vn=admin
```

---

## 🌐 CẤU HÌNH DNS VÀ SSL

### 1. Cấu hình DNS Records

Tại nhà cung cấp domain (Tenten, MatBao, Cloudflare, v.v.):

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A | @ | `<EC2_PUBLIC_IP>` | 3600 |
| A | admin | `<EC2_PUBLIC_IP>` | 3600 |
| A | api | `<EC2_PUBLIC_IP>` | 3600 |

Hoặc nếu dùng CNAME (nếu có domain):
```
@ → ec2-xxx-xxx-xxx-xxx.compute.amazonaws.com
admin → ec2-xxx-xxx-xxx-xxx.compute.amazonaws.com
api → ec2-xxx-xxx-xxx-xxx.compute.amazonaws.com
```

---

### 2. Cấu hình Nginx Reverse Proxy (trên EC2)

Tạo file `/etc/nginx/sites-available/medcure`:

```nginx
# Patient Frontend
server {
    listen 80;
    server_name medcure.com.vn www.medcure.com.vn;
    
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
    }
}

# Admin Frontend
server {
    listen 80;
    server_name admin.medcure.com.vn;
    
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
    }
}

# API Backend
server {
    listen 80;
    server_name api.medcure.com.vn;
    
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
        
        # WebSocket support for SignalR
        proxy_read_timeout 86400;
    }
    
    # Specific location for SignalR hub
    location /hubs/ {
        proxy_pass http://localhost:6005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/medcure /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

### 3. Cài đặt SSL với Let's Encrypt

```bash
# Cài đặt Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx -y

# Tạo certificate cho tất cả domains
sudo certbot --nginx -d medcure.com.vn -d www.medcure.com.vn -d admin.medcure.com.vn -d api.medcure.com.vn

# Auto renewal (thường được tự động cấu hình)
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

---

## 🔐 CẤU HÌNH OAUTH (Google, Facebook)

### Google OAuth Console

1. Truy cập [Google Cloud Console](https://console.cloud.google.com/)
2. Vào **APIs & Services** → **Credentials**
3. Chọn OAuth 2.0 Client ID đang dùng
4. Cập nhật **Authorized JavaScript origins**:
   ```
   https://medcure.com.vn
   https://admin.medcure.com.vn
   ```
5. Cập nhật **Authorized redirect URIs**:
   ```
   https://medcure.com.vn/auth/google/callback
   https://admin.medcure.com.vn/auth/google/callback
   ```

### Facebook Developer Console

1. Truy cập [Facebook Developers](https://developers.facebook.com/)
2. Vào App Settings → Basic
3. Thêm **App Domains**:
   ```
   medcure.com.vn
   admin.medcure.com.vn
   ```
4. Cập nhật **Website Site URL**:
   ```
   https://medcure.com.vn
   ```
5. Trong **Facebook Login** → **Settings**:
   - Valid OAuth Redirect URIs:
     ```
     https://medcure.com.vn/
     https://admin.medcure.com.vn/
     ```

---

## 📋 CHECKLIST TRIỂN KHAI

### Trước khi deploy:

- [ ] Cập nhật `.env.production` trên booking-care-system-ui
- [ ] Cập nhật `.env.production` trên booking-care-system-ui-admin
- [ ] Cập nhật `appsettings.Production.json` trên API Gateway
- [ ] Cập nhật CORS trong Communication Service
- [ ] Cập nhật callback URLs trong Payment Service
- [ ] Cập nhật `.env` trên booking-care-integration
- [ ] Cập nhật docker-compose.yml

### Trên EC2:

- [ ] Cấu hình DNS records (A records cho các subdomain)
- [ ] Cài đặt và cấu hình Nginx reverse proxy
- [ ] Cài đặt SSL certificates với Certbot
- [ ] Mở Security Group ports (80, 443)

### Sau khi deploy:

- [ ] Test truy cập https://medcure.com.vn
- [ ] Test truy cập https://admin.medcure.com.vn
- [ ] Test API calls từ frontend đến https://api.medcure.com.vn
- [ ] Test Google/Facebook OAuth login
- [ ] Test payment flows (VNPay, PayOS, Stripe)
- [ ] Test SignalR real-time notifications
- [ ] Verify SSL certificates đều valid

---

## 🚨 LƯU Ý QUAN TRỌNG

1. **CORS Issues**: Đảm bảo tất cả origins được whitelist ở backend
2. **Mixed Content**: Tránh mix HTTP/HTTPS - nên dùng HTTPS toàn bộ
3. **Cookie Security**: Với HTTPS, cần set Secure flag cho cookies
4. **OAuth Redirect**: Google/Facebook OAuth cần được cấu hình đúng redirect URIs
5. **Payment Callbacks**: VNPay, PayOS cần đăng ký webhook URL mới với provider
6. **DNS Propagation**: DNS có thể mất 24-48h để propagate toàn cầu

---

## 📞 Liên hệ hỗ trợ

Nếu gặp vấn đề, kiểm tra:
1. `docker logs <container_name>` - xem logs
2. `nginx -t` - test nginx config
3. Browser DevTools → Network tab - xem CORS errors
4. `curl -I https://domain.com` - test SSL
