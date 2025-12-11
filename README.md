# 🚀 BookingCare Complete Integration

Complete Docker Compose setup for running the entire BookingCare system with Backend microservices, Frontend User Portal, and Frontend Admin Portal.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Service URLs](#service-urls)
- [Troubleshooting](#troubleshooting)
- [Useful Commands](#useful-commands)

## 🎯 Overview

This repository contains a complete Docker Compose configuration that orchestrates:

- **Infrastructure**: RabbitMQ, Redis, MongoDB, 11 SQL Server instances
- **Backend**: 19 microservices (API Gateway + 18 domain services)
- **Frontend User Portal**: Patient-facing application
- **Frontend Admin Portal**: Admin dashboard

All services run in a shared Docker network (`bookingcare-network`) enabling seamless communication.

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND LAYER                           │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │   User Portal    │         │  Admin Portal    │         │
│  │   Port: 3000     │         │   Port: 3001     │         │
│  └──────────────────┘         └──────────────────┘         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    API GATEWAY LAYER                        │
│                     Port: 5001                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  MICROSERVICES LAYER                        │
│  Auth │ User │ Doctor │ Hospital │ Appointment │ Schedule   │
│  Payment │ Review │ Notification │ Analytics │ AI │ ...    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 INFRASTRUCTURE LAYER                        │
│  RabbitMQ │ Redis │ MongoDB │ 11x SQL Server               │
└─────────────────────────────────────────────────────────────┘
```

## ✅ Prerequisites

### Required Software

1. **Docker Desktop** (v20.10+)
   ```bash
   docker --version
   ```

2. **Docker Compose** (v2.0+)
   ```bash
   docker-compose --version
   ```

3. **Minimum System Requirements**
   - RAM: 16GB (32GB recommended)
   - CPU: 4 cores (8 cores recommended)
   - Disk: 50GB free space
   - OS: macOS, Linux, or Windows with WSL2

### Docker Hub Account

You need access to the Docker images. Either:

1. **Pull from Docker Hub** (if images are public)
   ```bash
   docker login
   ```

2. **Build locally** (see build instructions below)

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Navigate to integration folder
cd /Users/hieumaixuan/Documents/capstone-src/bookingcare-integration

# Copy environment file
cp .env.example .env

# Edit .env with your actual credentials
nano .env  # or use your preferred editor
```

### 2. Pull Images (Option A)

If images are available on Docker Hub:

```bash
# Pull all images
docker-compose pull
```

### 3. Build Images (Option B)

If you need to build images locally:

```bash
# Build Backend services
cd ../BookingCareSystemBackend
chmod +x scripts/build-and-tag-backend.sh
DOCKER_USERNAME=hiumx VERSION=latest ./scripts/build-and-tag-backend.sh

# Build Frontend User
cd ../booking-care-system-ui
chmod +x scripts/build-and-tag.sh
DOCKER_USERNAME=hiumx VERSION=latest ./scripts/build-and-tag.sh

# Build Frontend Admin
cd ../booking-care-system-ui-admin
chmod +x scripts/build-and-tag.sh
DOCKER_USERNAME=hiumx VERSION=latest ./scripts/build-and-tag.sh

# Return to integration folder
cd ../bookingcare-integration
```

### 4. Start All Services

```bash
# Start all services (infrastructure first, then services)
docker-compose up -d

# View logs
docker-compose logs -f

# Check service health
docker-compose ps
```

## 📚 Detailed Setup

### Step 1: Environment Configuration

Edit `.env` file with your credentials:

```env
# Docker Configuration
DOCKER_USERNAME=hiumx
VERSION=latest

# Database Passwords (CHANGE THESE!)
SQLSERVER_AUTH_PASSWORD=YourSecurePassword123!
SQLSERVER_USER_PASSWORD=YourSecurePassword123!
# ... (update all passwords)

# RabbitMQ
RABBITMQ_DEFAULT_USER=bookingcare
RABBITMQ_DEFAULT_PASS=YourRabbitMQPassword123!

# MongoDB
MONGO_INITDB_ROOT_PASSWORD=YourMongoPassword123!

# AWS S3 (if using)
S3_ACCESS_KEY=your_access_key
S3_SECRET_KEY=your_secret_key
```

### Step 2: Network Setup

The Docker network is automatically created, but you can create it manually:

```bash
docker network create bookingcare-network
```

### Step 3: Start Infrastructure First

```bash
# Start only infrastructure services
docker-compose up -d rabbitmq redis mongodb \
  sqlserver-discount sqlserver-saga sqlserver-user \
  sqlserver-doctor sqlserver-auth sqlserver-appointment \
  sqlserver-hospital sqlserver-schedule sqlserver-payment \
  sqlserver-servicemedical sqlserver-ai

# Wait for health checks (30-60 seconds)
docker-compose ps

# Check logs
docker-compose logs -f rabbitmq redis mongodb
```

### Step 4: Start Backend Services

```bash
# Start API Gateway and all microservices
docker-compose up -d \
  api-gateway \
  auth-service user-service doctor-service hospital-service \
  appointment-service schedule-service payment-service \
  notification-service review-service servicemedical-service \
  discount-service saga-service communication-service \
  content-service analytics-service ai-service \
  favorites-service blog-service
```

### Step 5: Start Frontend Services

```bash
# Start both frontend portals
docker-compose up -d ui-user ui-admin
```

### Step 6: Verify All Services

```bash
# Check all containers are running
docker-compose ps

# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## 🌐 Service URLs

### Frontend Applications

| Service | URL | Description |
|---------|-----|-------------|
| **User Portal** | http://localhost:3000 | Patient-facing application |
| **Admin Portal** | http://localhost:3001 | Admin dashboard |

### Backend Services

| Service | HTTP Port | gRPC Port | Description |
|---------|-----------|-----------|-------------|
| **API Gateway** | 5001 | - | Main entry point |
| **Auth Service** | 6003 | 6103 | Authentication |
| **User Service** | 6016 | 6116 | User management |
| **Doctor Service** | 6004 | 6104 | Doctor profiles |
| **Hospital Service** | 6005 | 6105 | Hospital data |
| **Appointment** | 6002 | 6102 | Booking management |
| **Schedule** | 6014 | 6114 | Doctor schedules |
| **Payment** | 6011 | 6111 | Payment processing |
| **Notification** | 6010 | 6110 | Notifications |
| **Review** | 6012 | 6112 | Reviews & ratings |

### Infrastructure

| Service | Port | UI Port | Credentials |
|---------|------|---------|-------------|
| **RabbitMQ** | 5672 | 15672 | See .env file |
| **Redis** | 6379 | - | No auth (default) |
| **MongoDB** | 27017 | - | See .env file |
| **SQL Servers** | 1400-1453 | - | sa / See .env file |

## 🔍 Troubleshooting

### Common Issues

#### 1. Services Not Starting

```bash
# Check logs
docker-compose logs [service-name]

# Example: Check auth service
docker-compose logs auth-service

# Check all service logs
docker-compose logs -f --tail=100
```

#### 2. Database Connection Issues

```bash
# Verify SQL Server is healthy
docker exec -it bookingcare_sqlserver_auth /bin/bash
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "YourPassword"

# Check connection string in .env matches password
grep SQLSERVER_AUTH_PASSWORD .env
```

#### 3. Port Conflicts

```bash
# Check what's using a port
lsof -i :5001  # macOS/Linux
netstat -ano | findstr :5001  # Windows

# Change port in docker-compose.yml if needed
```

#### 4. Memory Issues

```bash
# Check Docker resource usage
docker stats

# Increase Docker Desktop memory:
# Docker Desktop → Settings → Resources → Memory → 16GB+
```

#### 5. Image Pull Failures

```bash
# Login to Docker Hub
docker login

# Pull specific image manually
docker pull hiumx/bookingcare-api-gateway:latest

# Or build locally (see Quick Start Step 3)
```

### Health Checks

```bash
# Check all service health
docker-compose ps

# Test API Gateway
curl http://localhost:5001/health

# Test Frontend User Portal
curl http://localhost:3000/health

# Test RabbitMQ Management
open http://localhost:15672  # Username/Password from .env
```

## 🛠 Useful Commands

### Starting/Stopping Services

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d auth-service

# Stop all services
docker-compose down

# Stop and remove volumes (CAUTION: deletes data!)
docker-compose down -v
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f auth-service

# Last 100 lines
docker-compose logs --tail=100

# Multiple services
docker-compose logs -f api-gateway auth-service user-service
```

### Service Management

```bash
# Restart specific service
docker-compose restart auth-service

# Rebuild and restart
docker-compose up -d --build auth-service

# Scale a service (if stateless)
docker-compose up -d --scale user-service=3
```

### Database Operations

```bash
# Connect to SQL Server
docker exec -it bookingcare_sqlserver_auth /bin/bash
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "YourPassword"

# Connect to MongoDB
docker exec -it bookingcare_mongodb mongosh -u bookingcare -p

# Connect to Redis
docker exec -it bookingcare_redis redis-cli
```

### Cleanup

```bash
# Stop all containers
docker-compose down

# Remove all stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Complete cleanup (CAUTION!)
docker system prune -a --volumes -f
```

### Monitoring

```bash
# Real-time resource usage
docker stats

# Disk usage
docker system df

# Inspect network
docker network inspect bookingcare-network

# List all containers in network
docker network inspect bookingcare-network -f '{{range.Containers}}{{.Name}} {{end}}'
```

## 🔐 Security Best Practices

1. **Change Default Passwords**
   - Update all passwords in `.env`
   - Use strong passwords (16+ characters)
   - Never commit `.env` to version control

2. **Use Secrets Management**
   ```bash
   # For production, use Docker secrets or external vault
   docker secret create db_password /path/to/password.txt
   ```

3. **Network Isolation**
   - Keep services in isolated networks
   - Only expose necessary ports
   - Use reverse proxy for production

4. **Regular Updates**
   ```bash
   # Pull latest images
   docker-compose pull
   
   # Restart with new images
   docker-compose up -d
   ```

## 📊 Performance Tuning

### Docker Desktop Settings

- **Memory**: 16GB minimum, 32GB recommended
- **CPUs**: 4 cores minimum, 8 cores recommended
- **Disk**: 50GB minimum

### Database Optimization

```yaml
# Add to SQL Server services in docker-compose.yml
environment:
  - MSSQL_MEMORY_LIMIT_MB=2048
```

### Service Scaling

```bash
# Scale stateless services
docker-compose up -d --scale notification-service=3
```

## 📝 Notes

- **First startup** may take 5-10 minutes for all databases to initialize
- **Health checks** ensure services start in correct order
- **Logs** are essential for debugging - always check them first
- **Persistence** is achieved through Docker volumes

## 🆘 Support

If you encounter issues:

1. Check logs: `docker-compose logs -f [service]`
2. Verify environment variables in `.env`
3. Ensure sufficient system resources
4. Review this README's Troubleshooting section
5. Contact the DevOps team

## 📄 License

Capstone Project FA25 - BookingCare System

---

**Last Updated**: December 2025  
**Maintainer**: DevOps Team
