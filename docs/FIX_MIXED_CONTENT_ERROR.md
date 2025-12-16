# 🔧 Fix Mixed Content Error - Quick Guide

## ❌ Vấn đề

Lỗi **"(blocked:mixed-content)"** trong browser DevTools Network tab:
- Website load qua HTTPS (secure)
- API calls đang dùng HTTP (not secure) 
- Browser block các requests này

## ✅ Nguyên nhân

Frontend được build với **HTTP API URL** hoặc chưa rebuild sau khi update domain.

## 🛠️ Giải pháp

### Bước 1: SSH vào EC2 server

```bash
ssh -i /path/to/your-key.pem ubuntu@13.212.79.196
```

### Bước 2: Kiểm tra .env.production

```bash
cd /home/ubuntu/projects/booking-care-integration

# Check VITE_API_URL
grep "VITE_API_URL" .env.production
```

**Expected**: `VITE_API_URL=https://api.medcure.com.vn/api`

**Nếu thấy HTTP**, sửa thành HTTPS:

```bash
nano .env.production
```

Sửa dòng:
```bash
# ❌ SAI
VITE_API_URL=http://api.medcure.com.vn/api

# ✅ ĐÚNG  
VITE_API_URL=https://api.medcure.com.vn/api
```

Lưu: `Ctrl + O` → `Enter` → `Ctrl + X`

### Bước 3: Stop frontend containers

```bash
cd /home/ubuntu/projects/booking-care-integration

# Stop frontend services
docker-compose stop ui-user ui-admin

# Remove containers (để build lại từ đầu)
docker-compose rm -f ui-user ui-admin
```

### Bước 4: Verify source code location

```bash
# Check thư mục tồn tại
ls -la /home/ubuntu/projects/ | grep booking-care

# Should see:
# booking-care-integration/
# booking-care-system-ui/
# booking-care-system-ui-admin/
```

**Nếu thiếu**, clone lại:

```bash
cd /home/ubuntu/projects

# Clone patient UI (nếu thiếu)
git clone https://github.com/Capstone-FA25-MABS/booking-care-system-ui.git
cd booking-care-system-ui
git checkout feature/fe-deployment_HieuMX
cd ..

# Clone admin UI (nếu thiếu)
git clone https://github.com/Capstone-FA25-MABS/booking-care-system-ui-admin.git
cd booking-care-system-ui-admin
git checkout feature/fe-deployment_HieuMX
cd ..
```

### Bước 5: Load environment variables

```bash
cd /home/ubuntu/projects/booking-care-integration

# Load .env.production
export $(grep -v '^#' .env.production | xargs)

# Verify (MUST show HTTPS)
echo "API URL: $VITE_API_URL"
```

**Expected output**: 
```
API URL: https://api.medcure.com.vn/api
```

⚠️ **Nếu thấy HTTP hoặc localhost, DỪNG LẠI và fix .env.production trước!**

### Bước 6: Rebuild frontend images

```bash
cd /home/ubuntu/projects/booking-care-integration

# Rebuild frontend (NO CACHE để build clean)
docker-compose build --no-cache ui-user ui-admin
```

**Expected**: 
- Build logs xuất hiện
- Cuối cùng: `Successfully tagged hiumx/bookingcare-frontend:latest`
- Không có errors
- Mất khoảng 5-10 phút

### Bước 7: Start containers

```bash
docker-compose up -d ui-user ui-admin

# Wait for containers to start
sleep 30

# Check status
docker ps | grep ui
```

**Expected**: 
```
bookingcare_ui_user    Up XX seconds    0.0.0.0:5173->80/tcp
bookingcare_ui_admin   Up XX seconds    0.0.0.0:5174->80/tcp
```

### Bước 8: Verify API URL trong containers

```bash
# Check patient UI
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env | grep API_URL

# Check admin UI  
docker exec bookingcare_ui_admin cat /usr/share/nginx/html/.env | grep API_URL
```

**Expected (MUST have HTTPS)**:
```
VITE_API_URL=https://api.medcure.com.vn/api
```

⚠️ **Nếu vẫn thấy HTTP, back to Bước 3 và rebuild lại!**

### Bước 9: Test từ browser

1. **Clear browser cache**: `Ctrl + Shift + Delete` → Clear All
2. **Hard refresh**: `Ctrl + Shift + R` (hoặc `Cmd + Shift + R` trên Mac)
3. Mở DevTools: `F12`
4. Vào **Network** tab
5. Reload page

**Expected**:
- ✅ Requests đến `https://api.medcure.com.vn/api/...` (HTTPS)
- ✅ Status: 200 OK (hoặc 401 nếu chưa login)
- ✅ KHÔNG còn "(blocked:mixed-content)"

### Bước 10: Verify trong Console tab

1. Mở DevTools: `F12`
2. Vào **Console** tab

**Expected**:
- ✅ Không có errors màu đỏ
- ✅ Không có warnings "Mixed Content"
- ✅ Không có CORS errors

## 🧪 Test checklist

### ✅ Server-side checks

```bash
# Check containers running
docker ps | grep bookingcare_ui

# Check container logs (no errors)
docker logs bookingcare_ui_user | tail -20
docker logs bookingcare_ui_admin | tail -20

# Test internal endpoints
curl -I http://localhost:5173
curl -I http://localhost:5174

# Expected: HTTP/1.1 200 OK
```

### ✅ Browser checks

- [ ] Patient Portal: https://medcure.com.vn loads
- [ ] Admin Portal: https://admin.medcure.com.vn loads
- [ ] No "mixed content" errors in DevTools
- [ ] API calls go to `https://api.medcure.com.vn` (HTTPS)
- [ ] SSL certificate valid (green padlock icon)
- [ ] No CORS errors in Console

## 🔍 Troubleshooting

### Issue: Vẫn thấy "(blocked:mixed-content)"

**Nguyên nhân**: Browser cache vẫn load old version

**Giải pháp**:
```bash
# 1. Clear browser cache completely
# Chrome: Ctrl+Shift+Delete → All time → Clear data

# 2. Open Incognito/Private window
# Chrome: Ctrl+Shift+N

# 3. Test in Incognito
```

### Issue: Container build bị lỗi "context not found"

**Giải pháp**:
```bash
# Check docker-compose.yml context paths
cd /home/ubuntu/projects/booking-care-integration
grep "context:" docker-compose.yml | grep ui

# Expected:
#   context: ../booking-care-system-ui
#   context: ../booking-care-system-ui-admin

# Verify directories exist
ls -la ../booking-care-system-ui/
ls -la ../booking-care-system-ui-admin/

# If not exist, clone them (see Bước 4)
```

### Issue: Environment variable không load

**Giải pháp**:
```bash
# Re-export properly
cd /home/ubuntu/projects/booking-care-integration
set -a
source .env.production
set +a

# Verify
env | grep VITE_API_URL

# Should show: VITE_API_URL=https://api.medcure.com.vn/api
```

### Issue: Build thành công nhưng API URL vẫn sai

**Giải pháp**:
```bash
# 1. Verify .env.production (MUST have HTTPS)
cat .env.production | grep VITE_API_URL

# 2. Remove old images completely
docker rmi hiumx/bookingcare-frontend:latest
docker rmi hiumx/bookingcare-frontend-admin:latest

# 3. Clean build cache
docker builder prune -af

# 4. Rebuild from scratch
export $(grep -v '^#' .env.production | xargs)
docker-compose build --no-cache --pull ui-user ui-admin

# 5. Recreate containers
docker-compose up -d --force-recreate ui-user ui-admin

# 6. Verify again
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env
```

### Issue: API calls work but CORS errors

**Nguyên nhân**: Backend CORS chưa có medcure.com.vn

**Giải pháp**: Check backend đã update CORS chưa (đã update rồi ở bước trước)

## 📝 Quick Reference

```bash
# Load env vars
cd /home/ubuntu/projects/booking-care-integration
export $(grep -v '^#' .env.production | xargs)

# Rebuild frontend
docker-compose build --no-cache ui-user ui-admin

# Restart containers
docker-compose up -d --force-recreate ui-user ui-admin

# Check API URL
docker exec bookingcare_ui_user cat /usr/share/nginx/html/.env | grep API_URL

# View logs
docker-compose logs -f ui-user ui-admin
```

## 🎯 Root Cause Summary

**Vấn đề**: Frontend được build với HTTP API URL

**Why**: 
1. `.env.production` có HTTP thay vì HTTPS, HOẶC
2. Container đang chạy được build trước khi update DNS, HOẶC
3. Environment variables không được load đúng lúc build

**Fix**: Rebuild frontend với HTTPS API URL từ .env.production

**Prevention**: 
- Luôn verify `.env.production` có HTTPS trước khi build
- Luôn verify env vars được load: `echo $VITE_API_URL`
- Luôn verify container env: `docker exec ... cat .env`
- Clear browser cache sau mỗi rebuild

## ✅ Success Criteria

Khi fix xong, bạn sẽ thấy:

1. **DevTools Network tab**:
   - Requests đến: `https://api.medcure.com.vn/api/...`
   - Status: 200/401 (not "blocked")
   - Size: actual data (not "0 kB")

2. **DevTools Console tab**:
   - No errors
   - No "Mixed Content" warnings

3. **Browser address bar**:
   - Green padlock icon
   - "Connection is secure"

4. **Application functionality**:
   - Login works
   - API data loads
   - No blank pages

Chúc bạn fix thành công! 🚀
