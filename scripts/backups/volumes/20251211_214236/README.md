# BookingCare Volume Backup

**Backup Date:** Thu Dec 11 21:43:14 +07 2025  
**Timestamp:** 20251211_214236

## Backup Summary

- **Total Volumes:** 14
- **Successfully Backed Up:** 14
- **Failed:** 0

## Contents

This backup contains the following volume data:

- `bookingcaresystembackend_rabbitmq_data.tar.gz` (8.0K)
- `bookingcaresystembackend_redis_data.tar.gz` (4.0K)
- `bookingcaresystembackend_mongodb_data.tar.gz` (8.0M)
- `bookingcaresystembackend_sqlserver_discount_data.tar.gz` (7.1M)
- `bookingcaresystembackend_sqlserver_saga_data.tar.gz` (7.7M)
- `bookingcaresystembackend_sqlserver_user_data.tar.gz` (6.9M)
- `bookingcaresystembackend_sqlserver_doctor_data.tar.gz` (7.3M)
- `bookingcaresystembackend_sqlserver_auth_data.tar.gz` (7.3M)
- `bookingcaresystembackend_sqlserver_appointment_data.tar.gz` (7.6M)
- `bookingcaresystembackend_sqlserver_hospital_data.tar.gz` (7.8M)
- `bookingcaresystembackend_sqlserver_schedule_data.tar.gz` (6.9M)
- `bookingcaresystembackend_sqlserver_payment_data.tar.gz` (7.7M)
- `bookingcaresystembackend_sqlserver_servicemedical_data.tar.gz` (7.7M)
- `bookingcaresystembackend_sqlserver_ai_data.tar.gz` (7.2M)

## Restore Instructions

To restore these volumes on a new server:

1. Transfer this backup directory to the target server
2. Run the restore script:
   ```bash
   ./restore-volumes.sh ./backups/volumes/20251211_214236
   ```

3. Start your services:
   ```bash
   docker-compose up -d
   ```

## Notes

- Volumes are stored as compressed tar archives
- Each volume maintains its original directory structure
- Ensure Docker is installed on the target system before restoring
