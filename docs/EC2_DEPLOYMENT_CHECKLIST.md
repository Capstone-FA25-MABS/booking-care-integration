# EC2 Deployment Checklist

Checklist đầy đủ để deploy BookingCare System lên AWS EC2.

## ✅ Pre-Deployment Checklist

### 1. EC2 Instance Setup
- [ ] Launch EC2 instance (recommended: t3.large or higher)
- [ ] Configure Security Groups:
  - [ ] SSH (22) - Your IP only
  - [ ] HTTP (80) - 0.0.0.0/0
  - [ ] HTTPS (443) - 0.0.0.0/0
  - [ ] Custom TCP (5000) - API Gateway
  - [ ] Custom TCP (5173) - User UI
  - [ ] Custom TCP (5174) - Admin UI
  - [ ] Custom TCP (6379) - Redis (optional, for debugging)
  - [ ] Custom TCP (15672) - RabbitMQ Management (optional)
  - [ ] Custom TCP (27017) - MongoDB (optional)
- [ ] Allocate Elastic IP
- [ ] Create and download SSH key pair (.pem file)

### 2. Local Setup
- [ ] Có file `.env` với đầy đủ credentials
- [ ] Docker và Docker Compose đã cài đặt
- [ ] Test containers chạy thành công trên local
- [ ] Có data để backup

### 3. SSH Configuration
```bash
# Add to ~/.ssh/config
Host bookingcare-ec2
    HostName <your-elastic-ip>
    User ec2-user
    IdentityFile ~/.ssh/bookingcare-key.pem
```
- [ ] SSH config đã được thiết lập
- [ ] Test SSH connection: `ssh bookingcare-ec2`

---

## 🚀 Deployment Steps

### Method 1: Automatic Deployment (Recommended)

```bash
# 1. Backup local data
cd booking-care-integration/scripts
./backup-databases.sh

# 2. Deploy to EC2 (one command)
./deploy-to-ec2.sh ec2-user@<your-elastic-ip> database

# 3. Done! ✓
```

**Checklist:**
- [ ] Backup completed successfully
- [ ] Transfer to EC2 completed
- [ ] Docker installed on EC2
- [ ] Volumes created
- [ ] Infrastructure services started
- [ ] Data restored
- [ ] Application services started

---

### Method 2: Manual Deployment

#### Step 1: Backup Local Data
```bash
cd booking-care-integration/scripts
./backup-databases.sh
```
**Checklist:**
- [ ] Backup file created: `backups/databases/YYYYMMDD_HHMMSS_databases.tar.gz`
- [ ] Verify backup size: `ls -lh backups/databases/*.tar.gz`

#### Step 2: Transfer to EC2
```bash
# Transfer backup
scp backups/databases/20241211_120000_databases.tar.gz \
    ec2-user@<your-elastic-ip>:/home/ec2-user/backups/

# Transfer project files
rsync -avz --exclude 'node_modules' --exclude '.git' \
    ./ ec2-user@<your-elastic-ip>:/home/ec2-user/booking-care-integration/
```
**Checklist:**
- [ ] Backup file transferred
- [ ] Project files transferred
- [ ] `.env` file copied to EC2

#### Step 3: Install Docker on EC2
```bash
ssh ec2-user@<your-elastic-ip>

# Install Docker
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify
docker --version
docker-compose --version

# Logout and login again for group changes
exit
ssh ec2-user@<your-elastic-ip>
```
**Checklist:**
- [ ] Docker installed
- [ ] Docker Compose installed
- [ ] User added to docker group
- [ ] Can run `docker ps` without sudo

#### Step 4: Create Volumes
```bash
cd /home/ec2-user/booking-care-integration
chmod +x scripts/*.sh
./scripts/create-volumes.sh
```
**Checklist:**
- [ ] All 14 volumes created
- [ ] Verify: `docker volume ls | grep bookingcaresystembackend`

#### Step 5: Start Infrastructure Services
```bash
cd /home/ec2-user/booking-care-integration

# Start infrastructure
docker-compose up -d rabbitmq redis mongodb \
    sqlserver-discount sqlserver-saga sqlserver-user \
    sqlserver-doctor sqlserver-auth sqlserver-appointment \
    sqlserver-hospital sqlserver-schedule sqlserver-payment \
    sqlserver-servicemedical sqlserver-ai

# Wait for services to be healthy (3-5 minutes)
watch docker-compose ps
```
**Checklist:**
- [ ] All infrastructure containers running
- [ ] Health status: healthy (wait ~3-5 minutes)
- [ ] No containers in "restarting" state
- [ ] Check logs: `docker-compose logs -f`

#### Step 6: Restore Data
```bash
cd /home/ec2-user/booking-care-integration/scripts
./restore-databases.sh /home/ec2-user/backups/20241211_120000
```
**Checklist:**
- [ ] MongoDB restored
- [ ] Redis restored
- [ ] RabbitMQ definitions imported
- [ ] All 11 SQL Server databases restored
- [ ] No errors in restore output

#### Step 7: Start Application Services
```bash
cd /home/ec2-user/booking-care-integration
docker-compose up -d

# Monitor startup
docker-compose logs -f
```
**Checklist:**
- [ ] All services started
- [ ] API Gateway running on port 5000
- [ ] User UI running on port 5173
- [ ] Admin UI running on port 5174
- [ ] No error logs
- [ ] Services can communicate (check logs)

---

## 🔍 Post-Deployment Verification

### 1. Service Health Check
```bash
# Check all services
docker-compose ps

# Expected: All services in "Up" state
```
**Checklist:**
- [ ] All services status: Up
- [ ] No services in Exit state
- [ ] No continuous restarts

### 2. Container Logs
```bash
# Check for errors
docker-compose logs | grep -i error
docker-compose logs | grep -i exception

# Check specific services
docker-compose logs api-gateway
docker-compose logs auth-service
docker-compose logs user-service
```
**Checklist:**
- [ ] No critical errors in logs
- [ ] Services initialized successfully
- [ ] Database connections successful
- [ ] RabbitMQ connections established

### 3. Database Verification
```bash
# MongoDB
docker exec bookingcare_mongodb mongosh \
    -u admin -p password --authenticationDatabase admin \
    --eval "db.adminCommand('listDatabases')"

# Redis
docker exec bookingcare_redis redis-cli DBSIZE

# SQL Server - User Service
docker exec bookingcare_sqlserver_user /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U SA -P 'BookingCare@123' \
    -Q "SELECT name FROM sys.databases"
```
**Checklist:**
- [ ] MongoDB: databases exist with data
- [ ] Redis: keys > 0
- [ ] SQL Server: all 11 databases exist
- [ ] No connection errors

### 4. API Testing
```bash
# Get EC2 public IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Test API Gateway
curl http://$EC2_IP:5000/health
curl http://$EC2_IP:5000/api/v1/auth/health

# Test User UI
curl -I http://$EC2_IP:5173

# Test Admin UI
curl -I http://$EC2_IP:5174
```
**Checklist:**
- [ ] API Gateway responds (200 OK)
- [ ] Health endpoints working
- [ ] User UI accessible
- [ ] Admin UI accessible

### 5. Frontend Testing
**User UI:** `http://<your-elastic-ip>:5173`
- [ ] Homepage loads
- [ ] Can view doctors/hospitals
- [ ] Login page works
- [ ] Registration works
- [ ] No console errors

**Admin UI:** `http://<your-elastic-ip>:5174`
- [ ] Admin login page loads
- [ ] Can login with admin credentials
- [ ] Dashboard loads
- [ ] Navigation works
- [ ] No console errors

### 6. System Resources
```bash
# Check system resources
docker stats --no-stream

# Check disk usage
docker system df
df -h

# Check memory
free -h
```
**Checklist:**
- [ ] CPU usage < 80%
- [ ] Memory usage < 80%
- [ ] Disk space sufficient (> 10GB free)
- [ ] No out-of-memory errors

---

## 🔧 Configuration Updates

### Update API URL in Frontend
```bash
# SSH to EC2
ssh ec2-user@<your-elastic-ip>

# Get public IP
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Update .env
cd /home/ec2-user/booking-care-integration
nano .env

# Update this line:
VITE_API_URL=http://$EC2_PUBLIC_IP:5000

# Restart UI services
docker-compose restart ui-user ui-admin
```
**Checklist:**
- [ ] VITE_API_URL updated with EC2 public IP
- [ ] UI services restarted
- [ ] Frontend can connect to backend

### Setup Domain (Optional)
If you have a domain:
```bash
# Update .env
VITE_API_URL=https://api.yourdomain.com

# Setup Nginx reverse proxy
# Setup SSL with Let's Encrypt
```
**Checklist:**
- [ ] Domain DNS configured
- [ ] Nginx installed and configured
- [ ] SSL certificate obtained
- [ ] HTTPS working

---

## 📊 Monitoring & Maintenance

### Daily Checks
- [ ] Check container status: `docker-compose ps`
- [ ] Check logs for errors: `docker-compose logs --tail=100 | grep -i error`
- [ ] Check disk space: `df -h`
- [ ] Check system resources: `docker stats --no-stream`

### Weekly Tasks
- [ ] Review application logs
- [ ] Check backup status
- [ ] Update Docker images if needed
- [ ] Clean up old containers/images: `docker system prune -a`

### Monthly Tasks
- [ ] Test backup/restore process
- [ ] Review security group rules
- [ ] Update system packages: `sudo yum update -y`
- [ ] Review application metrics

---

## 🚨 Troubleshooting

### Services Not Starting
```bash
# Check logs
docker-compose logs <service-name>

# Restart specific service
docker-compose restart <service-name>

# Remove and recreate
docker-compose stop <service-name>
docker-compose rm <service-name>
docker-compose up -d <service-name>
```

### Database Connection Issues
```bash
# Check database container
docker logs <db-container-name>

# Test connection
docker exec <container-name> <connection-test-command>

# Restart database
docker-compose restart <db-service-name>
```

### Frontend Can't Connect to Backend
```bash
# Check VITE_API_URL in .env
cat .env | grep VITE_API_URL

# Verify EC2 Security Group allows port 5000
# Check API Gateway is running
curl http://localhost:5000/health
```

### Out of Memory
```bash
# Check memory usage
free -h
docker stats

# Stop some services if needed
docker-compose stop <non-critical-service>

# Consider upgrading EC2 instance type
```

### Out of Disk Space
```bash
# Check disk usage
df -h
docker system df

# Clean up
docker system prune -a -f
docker volume prune -f

# Remove old backups
find /home/ec2-user/backups -mtime +30 -delete
```

---

## 📞 Emergency Contacts & Resources

- **Documentation:** `/docs/BACKUP_RESTORE_GUIDE.md`
- **Scripts Location:** `/scripts/`
- **Logs Location:** `docker-compose logs`
- **AWS Console:** https://console.aws.amazon.com

---

## ✅ Final Verification Checklist

Before marking deployment as complete:

- [ ] All services running (docker-compose ps)
- [ ] No errors in logs
- [ ] All databases accessible
- [ ] User UI accessible from browser
- [ ] Admin UI accessible from browser
- [ ] API endpoints responding
- [ ] Can create/login user account
- [ ] Can view doctors/hospitals
- [ ] Payment gateways configured (if applicable)
- [ ] Backup/restore tested
- [ ] System resources within limits
- [ ] Monitoring set up
- [ ] Documentation updated
- [ ] Team notified of deployment

---

**Deployment Date:** ___________  
**Deployed By:** ___________  
**EC2 Instance ID:** ___________  
**Elastic IP:** ___________  
**Status:** ☐ Success ☐ Failed ☐ Partial

**Notes:**
_________________________________________
_________________________________________
_________________________________________
