# 📚 Documentation Index

## Quick Navigation

### 🚀 Deployment Guides

#### [EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md)
**Mục đích**: Hướng dẫn deploy toàn bộ hệ thống lên EC2 từ đầu đến cuối

**Phù hợp khi**:
- Lần đầu deploy lên EC2
- Cần overview toàn bộ quy trình
- Sử dụng Docker volume backup method

**Nội dung chính**:
- Terraform setup
- EC2 environment configuration
- Docker installation
- Volume backup/restore
- Services deployment
- Verification steps

---

#### [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) ⭐ **RECOMMENDED**
**Mục đích**: Chi tiết cụ thể về restore databases từ backup lên EC2

**Phù hợp khi**:
- Đã có backup từ local
- Muốn transfer mock data lên EC2
- Sử dụng database native backup (~5MB)
- Cần troubleshooting restore issues

**Nội dung chính**:
- Transfer backup to EC2 (SCP/rsync)
- Extract and restore databases
- MongoDB, Redis, RabbitMQ, SQL Server restore
- Data verification
- Troubleshooting common issues
- Alternative: EF Core migrations approach

**Thời gian**: ~10-15 phút

---

### 💾 Backup & Restore

#### [DATABASE_BACKUP_RESTORE_GUIDE.md](DATABASE_BACKUP_RESTORE_GUIDE.md)
**Mục đích**: Workflow hoàn chỉnh backup/restore databases

**Phù hợp khi**:
- Muốn hiểu backup process
- Cần document cho team
- Setup scheduled backups

**Nội dung chính**:
- Local backup procedures
- Transfer methods
- Restore workflows
- Best practices
- Backup scheduling

---

#### [BACKUP_RESTORE_GUIDE.md](BACKUP_RESTORE_GUIDE.md)
**Mục đích**: Volume backup/restore guide

**Phù hợp khi**:
- Backup toàn bộ Docker volumes
- Production data migration
- Need exact copy of all data

---

### ✅ Verification & Testing

#### [BACKUP_VERIFICATION_REPORT.md](BACKUP_VERIFICATION_REPORT.md)
**Mục đích**: Test results và verification của backup script

**Phù hợp khi**:
- Muốn xem backup script đã được test
- Check SQL Server backup method changes
- Understand backup file structure

**Highlights**:
- ✅ 14 databases backed up successfully
- ✅ 0 failed backups
- ✅ Archive size: 4.9MB
- SQL Server uses data files method (not .bak)

---

### 📋 Checklists

#### [EC2_DEPLOYMENT_CHECKLIST.md](EC2_DEPLOYMENT_CHECKLIST.md)
**Mục đích**: Quick checklist cho EC2 deployment

**Phù hợp khi**:
- Cần quick reference
- Follow deployment steps
- Verify completion

---

## 🎯 Quick Start Workflows

### Workflow 1: Deploy to EC2 with Mock Data (Fastest)

```bash
# 1. Local: Create backup
cd booking-care-integration/scripts
./backup-databases.sh
# Result: backups/databases/YYYYMMDD_HHMMSS_databases.tar.gz (~5MB)

# 2. Transfer to EC2
scp -i key.pem backups/databases/*.tar.gz ubuntu@EC2_IP:~/backup.tar.gz

# 3. EC2: Restore
ssh -i key.pem ubuntu@EC2_IP
cd ~/booking-care-integration/scripts
./restore-databases.sh ~/backup-folder/YYYYMMDD_HHMMSS

# 4. Start services
cd ~/booking-care-integration
docker-compose up -d
```

**📖 Detailed Guide**: [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md)

---

### Workflow 2: Deploy with EF Core Migrations (Recommended for Production)

```bash
# 1. EC2: Clone project
git clone https://github.com/your-repo/booking-care-integration.git
cd booking-care-integration

# 2. Setup environment
cp .env.example .env
# Edit .env with EC2 configurations

# 3. Start services
docker-compose up -d

# 4. Migrations auto-run, databases auto-created
docker logs bookingcare_user_service | grep migration
```

**📖 Detailed Guide**: [EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md)

---

### Workflow 3: Full Volume Backup/Restore (Large Data)

```bash
# 1. Local: Backup volumes
cd booking-care-integration/scripts
./backup-volumes.sh
# Result: backups/volumes/YYYYMMDD_HHMMSS/ (~500MB-1GB)

# 2. Transfer to EC2
rsync -avz -e "ssh -i key.pem" backups/volumes/YYYYMMDD_HHMMSS/ ubuntu@EC2_IP:~/volumes-backup/

# 3. EC2: Restore volumes
cd ~/booking-care-integration/scripts
./restore-volumes.sh ~/volumes-backup/YYYYMMDD_HHMMSS

# 4. Start services
docker-compose up -d
```

**📖 Detailed Guide**: [EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md) - Bước 6

---

## 📊 Comparison Table

| Method | Backup Size | Transfer Time | Complexity | Best For |
|--------|-------------|---------------|------------|----------|
| **Database Native** | ~5MB | ~30 sec | Medium | Mock data, staging |
| **EF Migrations** | 0 (no backup) | 0 | Low | Production, fresh deploys |
| **Docker Volumes** | ~500MB-1GB | ~5-10 min | Low | Production data migration |

---

## 🔍 Troubleshooting Quick Links

### SQL Server Issues
- **Backup Method**: [BACKUP_VERIFICATION_REPORT.md](BACKUP_VERIFICATION_REPORT.md) - SQL Server section
- **Restore Issues**: [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) - Troubleshooting section
- **Alternative**: Use EF Core migrations instead

### MongoDB Authentication
- **Fix**: [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) - Troubleshooting "Vấn Đề 2"

### Container Not Running
- **Fix**: [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) - Troubleshooting "Vấn Đề 3"
- **Docker Permissions**: [EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md) - Troubleshooting section

### Disk Space Issues
- **Fix**: [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) - Troubleshooting "Vấn Đề 4"

---

## 📝 Scripts Reference

### Backup Scripts
- `backup-databases.sh` - Native database backup (MongoDB, Redis, RabbitMQ, SQL Server data files)
- `backup-volumes.sh` - Docker volume backup

### Restore Scripts
- `restore-databases.sh` - Restore from database backup
- `restore-volumes.sh` - Restore from volume backup

### Utility Scripts
- `create-volumes.sh` - Create all required Docker volumes
- `quick-backup.sh` - Quick backup helper

---

## 🎓 Learning Path

### Beginner
1. Read [EC2_DEPLOYMENT_GUIDE.md](EC2_DEPLOYMENT_GUIDE.md) - Overview
2. Follow [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) - Step by step
3. Check [BACKUP_VERIFICATION_REPORT.md](BACKUP_VERIFICATION_REPORT.md) - Understand what was tested

### Intermediate
1. Understand backup methods comparison
2. Practice both database and volume backup/restore
3. Setup scheduled backups

### Advanced
1. Implement automated backup pipeline
2. Setup monitoring for backup jobs
3. Create custom restore procedures for specific scenarios
4. Implement blue-green deployment with backups

---

## 🆘 Need Help?

### Common Questions

**Q: Nên dùng backup method nào?**
- Mock data / Staging: Database native backup (5MB, fast)
- Production: EF Core migrations + seed scripts
- Full data migration: Docker volumes (complete but large)

**Q: SQL Server restore bị lỗi?**
- Check [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) Troubleshooting
- Alternative: Use EF Core migrations
- SQL Server restore từ data files phức tạp, migrations đơn giản hơn

**Q: Làm sao verify data đã restore đúng?**
- Follow verification steps trong [EC2_RESTORE_GUIDE.md](EC2_RESTORE_GUIDE.md) - Bước 6
- Check MongoDB document counts
- Check container logs
- Test API endpoints

**Q: Backup có thể automated không?**
- Có, xem [DATABASE_BACKUP_RESTORE_GUIDE.md](DATABASE_BACKUP_RESTORE_GUIDE.md) - Scheduled Backups section
- Setup cron jobs trên EC2

---

## 📅 Last Updated
December 13, 2025

## ✅ Status
- ✅ Backup script tested and working
- ✅ Restore script updated for data files
- ✅ EC2 restore guide completed
- ✅ Verification procedures documented
- ⏳ Production deployment testing pending
