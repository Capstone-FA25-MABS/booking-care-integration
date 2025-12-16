# 🔧 Fix Domain Routing Issue - medcure.com.vn showing Admin UI

## ❌ Vấn đề

Truy cập **https://medcure.com.vn/login** nhưng lại hiển thị **Admin login page** thay vì Patient login page.

## 🔍 Nguyên nhân có thể

1. **Nginx config trên server routing sai ports**
2. **Docker containers chạy sai images**
3. **Ports bị đảo ngược (5173 ↔ 5174)**
4. **Container names bị nhầm**

## ✅ Cách kiểm tra và fix

### Bước 1: SSH vào server

```bash
ssh -i /path/to/your-key.pem ubuntu@13.212.79.196
```

### Bước 2: Kiểm tra containers đang chạy

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" | grep ui
```

**Expected output**:
```
bookingcare_ui_user     hiumx/bookingcare-frontend:latest         0.0.0.0:5173->80/tcp
bookingcare_ui_admin    hiumx/bookingcare-frontend-admin:latest   0.0.0.0:5174->80/tcp
```

**❌ Nếu thấy ngược lại:**
```
bookingcare_ui_user     hiumx/bookingcare-frontend-admin:latest   0.0.0.0:5173->80/tcp
bookingcare_ui_admin    hiumx/bookingcare-frontend:latest         0.0.0.0:5174->80/tcp
```

→ **Đây là vấn đề! Images bị nhầm!**

### Bước 3: Test trực tiếp vào containers

```bash
# Test port 5173 (should be Patient UI)
curl -s http://localhost:5173 | grep -i "title"

# Test port 5174 (should be Admin UI)
curl -s http://localhost:5174 | grep -i "title"
```

**Expected**:
- Port 5173: Title có chứa "BookingCare" hoặc patient-related text
- Port 5174: Title có chứa "Admin" hoặc "BookingCare Admin"

### Bước 4: Kiểm tra Nginx configs

```bash
# Check Patient Portal config
sudo cat /etc/nginx/sites-available/medcure-patient | grep proxy_pass
```

**Expected**: `proxy_pass http://localhost:5173;`

```bash
# Check Admin Portal config
sudo cat /etc/nginx/sites-available/medcure-admin | grep proxy_pass
```

**Expected**: `proxy_pass http://localhost:5174;`

### Bước 5: Check docker-compose.yml

```bash
cd /home/ubuntu/projects/booking-care-integration

# Check ui-user service
grep -A 10 "ui-user:" docker-compose.yml | grep -E "image:|ports:"

# Check ui-admin service
grep -A 10 "ui-admin:" docker-compose.yml | grep -E "image:|ports:"
```

**Expected**:
```
# ui-user:
image: hiumx/bookingcare-frontend:latest
- "5173:80"

# ui-admin:
image: hiumx/bookingcare-frontend-admin:latest
- "5174:80"
```

## 🛠️ Giải pháp dựa trên vấn đề tìm được

### ⚠️ Scenario 1: Images bị sai (Containers chạy sai images)

**Nếu Bước 2 cho thấy images bị nhầm:**

```bash
cd /home/ubuntu/projects/booking-care-integration

# Stop và remove containers
docker-compose stop ui-user ui-admin
docker-compose rm -f ui-user ui-admin

# Remove old images to force pull
docker rmi hiumx/bookingcare-frontend:latest
docker rmi hiumx/bookingcare-frontend-admin:latest

# Pull latest images (already built correctly)
docker-compose pull ui-user ui-admin

# Recreate containers với correct images
docker-compose up -d ui-user ui-admin

# Wait for containers to start
sleep 30

# Verify
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" | grep ui
```

### ⚠️ Scenario 2: Ports bị đảo ngược trong docker-compose.yml

**Nếu Bước 5 cho thấy ports sai:**

```bash
cd /home/ubuntu/projects/booking-care-integration

# Edit docker-compose.yml
nano docker-compose.yml
```

Tìm section `ui-user` và `ui-admin`, verify:

```yaml
  ui-user:
    image: hiumx/bookingcare-frontend:latest  # Patient UI
    ports:
      - "5173:80"  # MUST be 5173

  ui-admin:
    image: hiumx/bookingcare-frontend-admin:latest  # Admin UI
    ports:
      - "5174:80"  # MUST be 5174
```

**Nếu sai, fix và restart:**

```bash
# Recreate containers
docker-compose up -d --force-recreate ui-user ui-admin
```

### ⚠️ Scenario 3: Nginx config routing sai

**Nếu Bước 4 cho thấy proxy_pass sai:**

```bash
# Fix Patient Portal config
sudo nano /etc/nginx/sites-available/medcure-patient
```

Verify phần `proxy_pass`:

```nginx
server {
    server_name medcure.com.vn www.medcure.com.vn;
    
    location / {
        proxy_pass http://localhost:5173;  # MUST be 5173 for Patient UI
        # ... other settings
    }
}
```

```bash
# Fix Admin Portal config
sudo nano /etc/nginx/sites-available/medcure-admin
```

Verify phần `proxy_pass`:

```nginx
server {
    server_name admin.medcure.com.vn;
    
    location / {
        proxy_pass http://localhost:5174;  # MUST be 5174 for Admin UI
        # ... other settings
    }
}
```

**Sau khi fix, test và reload Nginx:**

```bash
# Test config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### ⚠️ Scenario 4: Docker images được build sai (từ local)

**Nếu bạn build images từ máy local và push lên Docker Hub:**

Kiểm tra xem có nhầm thư mục khi build không:

```bash
# Trên máy local, verify build commands trong build-fe.sh

# Patient UI build (MUST be in booking-care-system-ui folder)
cd booking-care-system-ui
docker buildx build ... -t hiumx/bookingcare-frontend:latest

# Admin UI build (MUST be in booking-care-system-ui-admin folder)
cd booking-care-system-ui-admin
docker buildx build ... -t hiumx/bookingcare-frontend-admin:latest
```

**Nếu build nhầm, rebuild lại:**

```bash
# Trên máy local
cd /path/to/booking-care-system-ui

# Build Patient UI
docker buildx build --platform linux/amd64 \
    --build-arg VITE_API_URL=https://api.medcure.com.vn/api \
    --build-arg VITE_RECAPTCHA_SITE_KEY=6LcV_KUrAAAAANoaMiIxrwva-Sj6h0w-0zXkRuWp \
    --build-arg VITE_GOOGLE_CLIENT_ID=766011988725-2ef6bioidme1bur67ndammjj22cpefo9.apps.googleusercontent.com \
    --build-arg VITE_FACEBOOK_APP_ID=1157258869837908 \
    --build-arg VITE_DEVICE_ID=web-production \
    -t hiumx/bookingcare-frontend:latest \
    --push .

cd /path/to/booking-care-system-ui-admin

# Build Admin UI
docker buildx build --platform linux/amd64 \
    --build-arg VITE_API_URL=https://api.medcure.com.vn/api \
    --build-arg VITE_RECAPTCHA_SITE_KEY=6LcV_KUrAAAAANoaMiIxrwva-Sj6h0w-0zXkRuWp \
    --build-arg VITE_GOOGLE_CLIENT_ID=766011988725-2ef6bioidme1bur67ndammjj22cpefo9.apps.googleusercontent.com \
    --build-arg VITE_FACEBOOK_APP_ID=1157258869837908 \
    --build-arg MABS_APP_NAME="BookingCare Admin" \
    -t hiumx/bookingcare-frontend-admin:latest \
    --push .
```

**Sau đó, trên server pull và recreate:**

```bash
cd /home/ubuntu/projects/booking-care-integration
docker-compose pull ui-user ui-admin
docker-compose up -d --force-recreate ui-user ui-admin
```

## 🧪 Bước 6: Verify sau khi fix

### Test 1: Check container titles

```bash
# Patient UI (port 5173) - should NOT contain "Admin"
curl -s http://localhost:5173 | grep -i "<title>"

# Admin UI (port 5174) - should contain "Admin"
curl -s http://localhost:5174 | grep -i "<title>"
```

### Test 2: Check via domains (from server)

```bash
# Patient Portal - should NOT contain "Admin"
curl -s https://medcure.com.vn | grep -i "<title>"

# Admin Portal - should contain "Admin"
curl -s https://admin.medcure.com.vn | grep -i "<title>"
```

### Test 3: Check from browser

1. **Clear browser cache**: `Ctrl + Shift + Delete`
2. **Hard refresh**: `Ctrl + Shift + R`
3. **Test URLs**:
   - ✅ https://medcure.com.vn → Patient UI (no "Admin" branding)
   - ✅ https://admin.medcure.com.vn → Admin UI (has "Admin" branding)

### Test 4: Check app titles in browser tab

- **medcure.com.vn** → Tab title: "BookingCare" hoặc "Đặt lịch khám bệnh"
- **admin.medcure.com.vn** → Tab title: "BookingCare Admin" hoặc "Quản trị hệ thống"

### Test 5: Visual verification

**Patient Portal** (medcure.com.vn) should have:
- ✅ Patient-friendly UI/colors
- ✅ "Đăng nhập" for patients
- ✅ Booking/appointment features visible

**Admin Portal** (admin.medcure.com.vn) should have:
- ✅ Professional admin UI
- ✅ "Đăng nhập quản trị" or admin login
- ✅ Dashboard/management features

## 📊 Debugging Commands

```bash
# View container logs
docker logs bookingcare_ui_user | tail -50
docker logs bookingcare_ui_admin | tail -50

# Check Nginx access logs
sudo tail -f /var/log/nginx/medcure-patient-access.log
sudo tail -f /var/log/nginx/medcure-admin-access.log

# Check Nginx error logs
sudo tail -f /var/log/nginx/medcure-patient-error.log
sudo tail -f /var/log/nginx/medcure-admin-error.log

# List all Nginx configs
ls -la /etc/nginx/sites-enabled/

# Show full Nginx config for patient portal
sudo cat /etc/nginx/sites-available/medcure-patient

# Show full Nginx config for admin portal
sudo cat /etc/nginx/sites-available/medcure-admin

# Check which process is listening on ports
sudo lsof -i :5173
sudo lsof -i :5174
sudo lsof -i :80
sudo lsof -i :443

# Check Nginx is running
sudo systemctl status nginx

# Check Docker containers
docker ps -a
```

## 🔄 Complete Fix Workflow (Recommended)

**Chạy tuần tự các commands này để fix chắc chắn:**

```bash
# 1. SSH to server
ssh -i /path/to/your-key.pem ubuntu@13.212.79.196

# 2. Go to project directory
cd /home/ubuntu/projects/booking-care-integration

# 3. Stop all frontend containers
docker-compose stop ui-user ui-admin

# 4. Remove containers
docker-compose rm -f ui-user ui-admin

# 5. Remove old images (force fresh pull)
docker rmi hiumx/bookingcare-frontend:latest || true
docker rmi hiumx/bookingcare-frontend-admin:latest || true

# 6. Pull latest images
docker-compose pull ui-user ui-admin

# 7. Verify images pulled correctly
docker images | grep bookingcare-frontend

# 8. Start containers
docker-compose up -d ui-user ui-admin

# 9. Wait for containers to be healthy
sleep 60

# 10. Check containers are running with correct images
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" | grep ui

# 11. Test Patient UI (should NOT have "Admin" in title)
curl -s http://localhost:5173 | grep -o "<title>.*</title>"

# 12. Test Admin UI (should have "Admin" in title)
curl -s http://localhost:5174 | grep -o "<title>.*</title>"

# 13. Verify Nginx configs
sudo cat /etc/nginx/sites-available/medcure-patient | grep proxy_pass
sudo cat /etc/nginx/sites-available/medcure-admin | grep proxy_pass

# 14. Reload Nginx (just in case)
sudo systemctl reload nginx

# 15. Test from domains
curl -s https://medcure.com.vn | grep -o "<title>.*</title>"
curl -s https://admin.medcure.com.vn | grep -o "<title>.*</title>"
```

**Expected outputs:**

Step 10:
```
NAMES                   IMAGE                                      PORTS
bookingcare_ui_user     hiumx/bookingcare-frontend:latest         0.0.0.0:5173->80/tcp
bookingcare_ui_admin    hiumx/bookingcare-frontend-admin:latest   0.0.0.0:5174->80/tcp
```

Step 11: `<title>BookingCare</title>` (NO "Admin")

Step 12: `<title>BookingCare Admin</title>` (HAS "Admin")

Step 13:
```
proxy_pass http://localhost:5173;  # for medcure-patient
proxy_pass http://localhost:5174;  # for medcure-admin
```

Step 15:
```
<title>BookingCare</title>           # medcure.com.vn
<title>BookingCare Admin</title>     # admin.medcure.com.vn
```

## 🎯 Root Cause Analysis

**Vấn đề thường gặp:**

1. **Images bị build nhầm thư mục** → Build lại đúng thư mục
2. **Containers chạy sai images** → Pull và recreate
3. **Ports mapping sai trong docker-compose.yml** → Fix config và recreate
4. **Nginx proxy_pass sai ports** → Fix Nginx config và reload
5. **Browser cache old version** → Clear cache và hard refresh

**Prevention:**

- Luôn verify `docker ps` output sau mỗi deploy
- Luôn test `curl localhost:5173` và `localhost:5174` trước khi expose ra ngoài
- Luôn check Nginx config trước khi reload
- Luôn clear browser cache sau mỗi update

## ✅ Success Criteria

Sau khi fix xong, bạn phải thấy:

1. ✅ `docker ps`: ui-user chạy `bookingcare-frontend`, ui-admin chạy `bookingcare-frontend-admin`
2. ✅ `curl localhost:5173`: Patient UI (no "Admin")
3. ✅ `curl localhost:5174`: Admin UI (has "Admin")
4. ✅ Browser `medcure.com.vn`: Patient portal
5. ✅ Browser `admin.medcure.com.vn`: Admin portal
6. ✅ No errors in Nginx logs
7. ✅ No errors in container logs

Chúc bạn fix thành công! 🚀
