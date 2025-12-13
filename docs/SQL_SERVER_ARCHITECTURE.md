# SQL Server Architecture & Restore Mapping

## 🏗️ Kiến Trúc SQL Server

### Container Isolation

```
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Host                              │
│                                                                   │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ Container: discount  │  │ Container: user      │             │
│  │ Port: 1434:1433     │  │ Port: 1445:1433     │             │
│  │                      │  │                      │             │
│  │ ┌──────────────────┐ │  │ ┌──────────────────┐ │             │
│  │ │ MABS_Discount    │ │  │ │ MABS_User        │ │             │
│  │ │ *.mdf, *.ldf     │ │  │ │ *.mdf, *.ldf     │ │             │
│  │ └──────────────────┘ │  │ └──────────────────┘ │             │
│  │                      │  │                      │             │
│  │ Volume:              │  │ Volume:              │             │
│  │ sqlserver_discount   │  │ sqlserver_user       │             │
│  └──────────────────────┘  └──────────────────────┘             │
│                                                                   │
│  ┌──────────────────────┐  ... (9 containers nữa)               │
│  │ Container: doctor    │                                        │
│  │ Port: 1446:1433     │                                        │
│  │ ┌──────────────────┐ │                                        │
│  │ │ MABS_Doctor      │ │                                        │
│  │ │ *.mdf, *.ldf     │ │                                        │
│  │ └──────────────────┘ │                                        │
│  │ Volume:              │                                        │
│  │ sqlserver_doctor     │                                        │
│  └──────────────────────┘                                        │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**Điểm quan trọng**:
- Mỗi container **hoàn toàn độc lập**
- Mỗi container có **1 database duy nhất**
- Mỗi container có **volume riêng**
- Data files **không bao giờ conflict** với nhau

---

## 📦 Backup Structure

```
backups/databases/20251213_081030/
│
├── MABS_Discount_datafiles.tar.gz      ← Từ bookingcare_sqlserver_discount
│   └── MABS_Discount.mdf
│   └── MABS_Discount_log.ldf
│
├── MABS_User_datafiles.tar.gz          ← Từ bookingcare_sqlserver_user
│   └── MABS_User.mdf
│   └── MABS_User_log.ldf
│
├── MABS_Doctor_datafiles.tar.gz        ← Từ bookingcare_sqlserver_doctor
│   └── MABS_Doctor.mdf
│   └── MABS_Doctor_log.ldf
│
├── ... (8 databases nữa)
│
├── mongodb.tar.gz
├── redis_dump.rdb
└── rabbitmq_definitions.json
```

---

## 🔄 Restore Mapping Flow

### Step 1: Backup Script Reads Container Info

```bash
# backup-databases.sh
SQL_DATABASES=(
    "bookingcare_sqlserver_discount:MABS_Discount:${PASSWORD}"
    "bookingcare_sqlserver_user:MABS_User:${PASSWORD}"
    "bookingcare_sqlserver_doctor:MABS_Doctor:${PASSWORD}"
    # ...
)

# For each entry:
for db_info in "${SQL_DATABASES[@]}"; do
    IFS=':' read -r container db_name password <<< "${db_info}"
    
    # Extract from SPECIFIC container
    docker exec "${container}" find /var/opt/mssql/data/ -name "${db_name}*.mdf"
    
    # Save as: ${db_name}_datafiles.tar.gz
done
```

### Step 2: Restore Script Uses Same Mapping

```bash
# restore-databases.sh
SQL_DATABASES=(
    "bookingcare_sqlserver_discount:MABS_Discount:${PASSWORD}"  ← Same mapping!
    "bookingcare_sqlserver_user:MABS_User:${PASSWORD}"
    "bookingcare_sqlserver_doctor:MABS_Doctor:${PASSWORD}"
    # ...
)

# For each entry:
for db_info in "${SQL_DATABASES[@]}"; do
    IFS=':' read -r container db_name password <<< "${db_info}"
    
    # Restore TO SPECIFIC container
    docker stop "${container}"
    docker cp "${db_name}_datafiles/*" "${container}:/var/opt/mssql/data/"
    docker start "${container}"
done
```

---

## ✅ Tại Sao Restore Đúng 100%

### 1. **Hard-coded Mapping**
```bash
# backup-databases.sh và restore-databases.sh dùng CÙNG array:
SQL_DATABASES=(
    "bookingcare_sqlserver_discount:MABS_Discount:${PASSWORD}"
    "bookingcare_sqlserver_user:MABS_User:${PASSWORD}"
    # ...
)

# → MABS_Discount LUÔN đi với bookingcare_sqlserver_discount
# → MABS_User LUÔN đi với bookingcare_sqlserver_user
# → Không thể nhầm lẫn!
```

### 2. **Container Isolation**
```
bookingcare_sqlserver_discount
└── /var/opt/mssql/data/
    ├── MABS_Discount.mdf          ← Chỉ có database này
    └── MABS_Discount_log.ldf      ← Không có database khác

bookingcare_sqlserver_user
└── /var/opt/mssql/data/
    ├── MABS_User.mdf              ← Chỉ có database này
    └── MABS_User_log.ldf          ← Không có database khác
```

### 3. **File Name Convention**
```
Backup file:     MABS_Discount_datafiles.tar.gz
Restore target:  bookingcare_sqlserver_discount
Mapping key:     "bookingcare_sqlserver_discount:MABS_Discount"

→ MABS_Discount_datafiles.tar.gz chỉ được restore vào container discount
→ Không thể nhầm vào container khác!
```

---

## 🔍 Verification: Restore Đúng Container

### Cách 1: Check Container Logs

```bash
# Check container nào được restart
docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep sqlserver

# Kỳ vọng thấy:
# bookingcare_sqlserver_discount   Up 2 minutes
# bookingcare_sqlserver_user       Up 2 minutes
# ... (tất cả đều Up vài phút, tức vừa restart)
```

### Cách 2: Check Database Files Trong Container

```bash
# Check MABS_Discount chỉ có trong discount container
docker exec bookingcare_sqlserver_discount ls -lh /var/opt/mssql/data/ | grep MABS_Discount
# → Phải thấy MABS_Discount.mdf và MABS_Discount_log.ldf

# Check KHÔNG có trong user container
docker exec bookingcare_sqlserver_user ls -lh /var/opt/mssql/data/ | grep MABS_Discount
# → Không thấy gì (database không tồn tại trong container này)
```

### Cách 3: Check Service Connection

```bash
# Discount Service kết nối đến port 1434 (discount container)
docker logs bookingcare_discount_service 2>&1 | grep -i "server=.*1434"

# User Service kết nối đến port 1445 (user container)
docker logs bookingcare_user_service 2>&1 | grep -i "server=.*1445"

# → Mỗi service connect đúng database của nó
```

---

## 📊 Complete Mapping Table

| Service | Container | Host Port | Database | Data Files | Backup File |
|---------|-----------|-----------|----------|------------|-------------|
| Discount | `bookingcare_sqlserver_discount` | 1434:1433 | MABS_Discount | MABS_Discount.mdf/.ldf | MABS_Discount_datafiles.tar.gz |
| Saga | `bookingcare_sqlserver_saga` | 1400:1433 | MABS_Saga | MABS_Saga.mdf/.ldf | MABS_Saga_datafiles.tar.gz |
| User | `bookingcare_sqlserver_user` | 1445:1433 | MABS_User | MABS_User.mdf/.ldf | MABS_User_datafiles.tar.gz |
| Doctor | `bookingcare_sqlserver_doctor` | 1446:1433 | MABS_Doctor | MABS_Doctor.mdf/.ldf | MABS_Doctor_datafiles.tar.gz |
| Auth | `bookingcare_sqlserver_auth` | 1447:1433 | MABS_Auth | MABS_Auth.mdf/.ldf | MABS_Auth_datafiles.tar.gz |
| Appointment | `bookingcare_sqlserver_appointment` | 1448:1433 | MABS_Appointment | MABS_Appointment.mdf/.ldf | MABS_Appointment_datafiles.tar.gz |
| Hospital | `bookingcare_sqlserver_hospital` | 1449:1433 | MABS_Hospital | MABS_Hospital.mdf/.ldf | MABS_Hospital_datafiles.tar.gz |
| Schedule | `bookingcare_sqlserver_schedule` | 1450:1433 | MABS_Schedule | MABS_Schedule.mdf/.ldf | MABS_Schedule_datafiles.tar.gz |
| Payment | `bookingcare_sqlserver_payment` | 1451:1433 | MABS_Payment | MABS_Payment.mdf/.ldf | MABS_Payment_datafiles.tar.gz |
| ServiceMedical | `bookingcare_sqlserver_servicemedical` | 1452:1433 | MABS_ServiceMedical | MABS_ServiceMedical.mdf/.ldf | MABS_ServiceMedical_datafiles.tar.gz |
| AI | `bookingcare_sqlserver_ai` | 1453:1433 | MABS_AI | MABS_AI.mdf/.ldf | MABS_AI_datafiles.tar.gz |

---

## 🎯 Kết Luận

### ✅ Restore Sẽ Đúng Vì:

1. **Mapping cứng trong code** - Mỗi database có container cố định
2. **Container isolation** - Mỗi container độc lập hoàn toàn
3. **File name convention** - Backup file tên theo database, không thể nhầm
4. **Sequential restore** - Restore từng database một, stop container → copy files → start
5. **Volume separation** - Mỗi container có volume riêng, không share data

### ⚠️ Điều Kiện Để Restore Thành Công:

1. ✅ Tất cả containers phải tồn tại (docker-compose up -d)
2. ✅ Container names phải đúng (bookingcare_sqlserver_*)
3. ✅ Backup files phải đúng format (*_datafiles.tar.gz)
4. ✅ .env file phải có đầy đủ passwords

### 🚫 Không Thể Xảy Ra:

- ❌ MABS_Discount restore vào user container (mapping cứng ngăn chặn)
- ❌ Data files conflict giữa containers (volume separation)
- ❌ Port conflict (mỗi container có port riêng)
- ❌ Database overwrite nhầm (mỗi container chỉ có 1 database)

---

## 💡 Pro Tips

### Verify Restore Success

```bash
# After restore, check mỗi service connect đúng database:
for service in discount user doctor; do
    echo "=== ${service} service ==="
    docker logs bookingcare_${service}_service 2>&1 | grep -i "database.*connected\|migration.*applied" | tail -3
done
```

### If Restore Fails

```bash
# Fallback: Dùng EF Core migrations
cd ~/booking-care-integration
docker-compose down -v  # Remove all volumes
docker-compose up -d    # Services will auto-create databases via migrations
```

---

**Last Updated**: December 13, 2025  
**Status**: ✅ Architecture verified, restore mapping confirmed correct
