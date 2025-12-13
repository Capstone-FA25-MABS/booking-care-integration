#!/bin/bash
# SQL Server 2022 Database Initialization Script
# This script waits for SQL Server to be ready and then executes the initialization SQL file

set -e

DB_NAME=$1
SQL_FILE=$2
SA_PASSWORD=$3

echo "=========================================="
echo "Starting database initialization for: $DB_NAME"
echo "SQL File: $SQL_FILE"
echo "=========================================="

# Find sqlcmd path (different in SQL Server 2022 vs Edge)
SQLCMD_PATH=""
if [ -f "/opt/mssql-tools18/bin/sqlcmd" ]; then
    SQLCMD_PATH="/opt/mssql-tools18/bin/sqlcmd"
    SQLCMD_OPTS="-C" # Trust server certificate for SQL Server 2022
elif [ -f "/opt/mssql-tools/bin/sqlcmd" ]; then
    SQLCMD_PATH="/opt/mssql-tools/bin/sqlcmd"
    SQLCMD_OPTS=""
else
    echo "✗ sqlcmd not found in /opt/mssql-tools18/bin or /opt/mssql-tools/bin"
    exit 1
fi

echo "Using sqlcmd at: $SQLCMD_PATH"

# Wait for SQL Server to start (max 90 seconds)
echo "Waiting for SQL Server to be ready..."
for i in {1..90}; do
    if $SQLCMD_PATH $SQLCMD_OPTS -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null; then
        echo "✓ SQL Server is ready!"
        break
    fi
    if [ $i -eq 90 ]; then
        echo "✗ SQL Server failed to start within 90 seconds"
        exit 1
    fi
    echo "Waiting for SQL Server... ($i/90)"
    sleep 1
done

# Check if database already exists
echo "Checking if database '$DB_NAME' exists..."
DB_EXISTS=$($SQLCMD_PATH $SQLCMD_OPTS -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT name FROM sys.databases WHERE name = '$DB_NAME'" -h -1 -W 2>/dev/null | grep -w "$DB_NAME" || true)

if [ -z "$DB_EXISTS" ]; then
    echo "Database $DB_NAME does not exist. Creating and initializing..."
    
    # Create database
    echo "Creating database [$DB_NAME]..."
    $SQLCMD_PATH $SQLCMD_OPTS -S localhost -U sa -P "$SA_PASSWORD" -Q "CREATE DATABASE [$DB_NAME]" &> /dev/null
    echo "✓ Database $DB_NAME created successfully!"
    
    # Run initialization script if it exists
    if [ -f "$SQL_FILE" ]; then
        echo "Running initialization script: $SQL_FILE"
        echo "This may take a few minutes..."
        
        # Execute SQL file with better error handling
        if $SQLCMD_PATH $SQLCMD_OPTS -S localhost -U sa -P "$SA_PASSWORD" -d "$DB_NAME" -i "$SQL_FILE" -b 2>&1 | tee /tmp/sql_init_${DB_NAME}.log; then
            echo "✓ Initialization script executed successfully!"
        else
            echo "✗ Error executing initialization script"
            cat /tmp/sql_init_${DB_NAME}.log
            exit 1
        fi
    else
        echo "✗ Warning: SQL file $SQL_FILE not found!"
        ls -la /tmp/*.sql || echo "No SQL files found in /tmp"
        exit 1
    fi
else
    echo "✓ Database $DB_NAME already exists. Skipping initialization."
fi

echo "=========================================="
echo "✓ Database $DB_NAME is ready!"
echo "=========================================="
