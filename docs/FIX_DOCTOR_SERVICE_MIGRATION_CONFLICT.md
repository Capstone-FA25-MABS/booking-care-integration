# Fix Doctor Service Migration Conflict

## ❌ Vấn đề

```
There is already an object named 'doctor_service_types' in the database.
```

**Nguyên nhân**: Database đã có tables nhưng `__EFMigrationsHistory` không có record của migration, nên EF Core cố tạo lại table.

## ✅ Giải pháp - Chọn 1 trong 3 options

### **Option 1: Add Migration Record (Recommended - Giữ data)**

Đánh dấu migration đã chạy mà không execute lại:

#### 1.1. Stop doctor service

```bash
docker-compose stop doctor-service
```

#### 1.2. Connect to SQL Server container

```bash
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -d MABS_Doctor
```

#### 1.3. Insert migration record

```sql
-- Check current migrations
SELECT * FROM [__EFMigrationsHistory];
GO

-- If migration not exists, insert it
INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) 
VALUES (N'20251203034141_AddInitDatabase', N'8.0.0');
GO

-- Verify
SELECT * FROM [__EFMigrationsHistory];
GO

-- Exit
EXIT
```

**Expected output**:
```
MigrationId                              ProductVersion
---------------------------------------- --------------
20251024071625_AddImageUrlColumnToServiceType  8.0.0
20251203034141_AddInitDatabase                  8.0.0
```

#### 1.4. Start doctor service

```bash
docker-compose up -d doctor-service

# Check logs (should start without migration errors)
docker-compose logs -f doctor-service
```

**Expected**: Service starts successfully, no migration errors

---

### **Option 2: Drop và Recreate Database (Clean start - MẤT DATA)**

⚠️ **WARNING: Sẽ XÓA TẤT CẢ DATA trong database!**

#### 2.1. Stop doctor service

```bash
docker-compose stop doctor-service
```

#### 2.2. Backup data nếu cần

```bash
# Backup (optional)
docker exec bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -Q "BACKUP DATABASE [MABS_Doctor] TO DISK = '/var/opt/mssql/backup/MABS_Doctor_$(date +%Y%m%d).bak'"
```

#### 2.3. Drop database

```bash
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C
```

```sql
USE [master];
GO

-- Force close all connections
ALTER DATABASE [MABS_Doctor] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

-- Drop database
DROP DATABASE [MABS_Doctor];
GO

-- Verify
SELECT name FROM sys.databases WHERE name = 'MABS_Doctor';
GO
-- Should return 0 rows

EXIT
```

#### 2.4. Start doctor service (auto recreate)

```bash
docker-compose up -d doctor-service

# Watch logs (should create database and run migrations)
docker-compose logs -f doctor-service
```

**Expected logs**:
```
info: Database MABS_Doctor does not exist. Creating...
info: Database created successfully
info: Applying migration '20251203034141_AddInitDatabase'
info: Applied migration successfully
```

#### 2.5. Import initial data (if needed)

```bash
# Copy SQL file to container
docker cp /Users/hieumaixuan/Documents/capstone-src/booking-care-integration/data/db_doctor.sql bookingcare_sqlserver_doctor:/tmp/

# Import data
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -d MABS_Doctor -i /tmp/db_doctor.sql
```

---

### **Option 3: Run Safe Migration Script (Best practice)**

Sử dụng script với IF NOT EXISTS checks:

#### 3.1. Copy safe migration script to container

```bash
docker cp /Users/hieumaixuan/Documents/capstone-src/booking-care-integration/data/db_doctor_safe_migration.sql bookingcare_sqlserver_doctor:/tmp/
```

#### 3.2. Stop doctor service

```bash
docker-compose stop doctor-service
```

#### 3.3. Run safe migration script

```bash
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -i /tmp/db_doctor_safe_migration.sql
```

**Expected output**:
```
Database MABS_Doctor already exists
Table doctor_service_types already exists - skipping
Migration record added: 20251203034141_AddInitDatabase
Migration Status:
MigrationId                                    ProductVersion
--------------------------------------------- --------------
20251024071625_AddImageUrlColumnToServiceType 8.0.0
20251203034141_AddInitDatabase                8.0.0
Database initialization completed successfully!
```

#### 3.4. Start doctor service

```bash
docker-compose up -d doctor-service

# Check logs
docker-compose logs -f doctor-service
```

---

## 🧪 Verify After Fix

### Check migration history

```bash
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -d MABS_Doctor -Q "SELECT * FROM [__EFMigrationsHistory]"
```

**Expected**:
```
MigrationId                                    ProductVersion
--------------------------------------------- --------------
20251024071625_AddImageUrlColumnToServiceType 8.0.0
20251203034141_AddInitDatabase                8.0.0
```

### Check service health

```bash
# Check container running
docker ps | grep doctor-service

# Check logs (no errors)
docker-compose logs doctor-service | grep -i error

# Test API endpoint
curl http://localhost:6002/health
```

**Expected**: HTTP 200 OK, `{"status":"Healthy"}`

### Check tables exist

```bash
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -d MABS_Doctor -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME"
```

**Expected tables**:
```
__EFMigrationsHistory
doctor_languages
doctor_prices
doctor_service_types
doctors
languages
positions
specialties
```

---

## 🔍 Root Cause Analysis

**Vấn đề xảy ra khi:**
1. Database được import từ SQL file (có tables)
2. Nhưng `__EFMigrationsHistory` table không có hoặc thiếu migration records
3. EF Core nghĩ database chưa có tables → cố chạy migration lại

**Giải pháp đúng:**
- Luôn đảm bảo `__EFMigrationsHistory` đồng bộ với database schema
- Hoặc sử dụng EF Core migrations từ đầu (không import SQL file trực tiếp)
- Hoặc dùng safe migration scripts với IF NOT EXISTS checks

---

## 📝 Prevention

### Để tránh vấn đề này trong tương lai:

**1. Sử dụng EF Core Migrations properly:**

```bash
# In development
dotnet ef migrations add YourMigrationName
dotnet ef database update

# In production (via code)
await context.Database.MigrateAsync();
```

**2. Nếu phải import SQL file:**

Luôn include `__EFMigrationsHistory` records:

```sql
-- After creating tables
INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) 
VALUES (N'20251203034141_AddInitDatabase', N'8.0.0');
```

**3. Database initialization trong code:**

```csharp
public async Task InitializeAsync()
{
    try
    {
        // Check if database exists
        var canConnect = await _context.Database.CanConnectAsync();
        
        if (!canConnect)
        {
            // Create and migrate
            await _context.Database.MigrateAsync();
        }
        else
        {
            // Get pending migrations
            var pendingMigrations = await _context.Database.GetPendingMigrationsAsync();
            
            if (pendingMigrations.Any())
            {
                // Apply pending migrations
                await _context.Database.MigrateAsync();
            }
        }
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Database initialization failed");
        throw;
    }
}
```

---

## 🎯 Quick Fix Commands

Tùy vào situation, chọn commands phù hợp:

```bash
# Option 1: Add migration record only (GIỮ DATA)
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -d MABS_Doctor -Q "INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES (N'20251203034141_AddInitDatabase', N'8.0.0')"

# Option 2: Drop and recreate (MẤT DATA)
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -Q "USE [master]; ALTER DATABASE [MABS_Doctor] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [MABS_Doctor];"
docker-compose up -d --force-recreate doctor-service

# Option 3: Run safe migration (BEST)
docker cp /path/to/db_doctor_safe_migration.sql bookingcare_sqlserver_doctor:/tmp/
docker exec -it bookingcare_sqlserver_doctor /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Doctor@1234!" -C -i /tmp/db_doctor_safe_migration.sql
```

---

## ✅ Success Criteria

Sau khi fix, bạn sẽ thấy:

1. ✅ Doctor service starts without errors
2. ✅ No migration conflicts in logs
3. ✅ `__EFMigrationsHistory` có đủ migration records
4. ✅ All tables exist in database
5. ✅ API endpoints return 200 OK
6. ✅ No "object already exists" errors

Chúc bạn fix thành công! 🚀
