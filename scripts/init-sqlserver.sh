#!/bin/bash
# SQL Server Database Initialization Script
# This script waits for SQL Server to be ready and then executes the initialization SQL file

set -e

DB_NAME=$1
SQL_FILE=$2
SA_PASSWORD=$3

echo "Waiting for SQL Server to be ready..."

# Wait for SQL Server to start (max 90 seconds)
for i in {1..90}; do
    if /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null; then
        echo "SQL Server is ready!"
        break
    fi
    echo "Waiting for SQL Server... ($i/90)"
    sleep 1
done

# Check if database already exists
DB_EXISTS=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT name FROM sys.databases WHERE name = '$DB_NAME'" -h -1 | grep -w "$DB_NAME" || true)

if [ -z "$DB_EXISTS" ]; then
    echo "Database $DB_NAME does not exist. Creating and initializing..."
    
    # Create database
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "CREATE DATABASE [$DB_NAME]"
    echo "Database $DB_NAME created successfully!"
    
    # Run initialization script if it exists
    if [ -f "$SQL_FILE" ]; then
        echo "Running initialization script: $SQL_FILE"
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d "$DB_NAME" -i "$SQL_FILE"
        echo "Initialization script executed successfully!"
    else
        echo "Warning: SQL file $SQL_FILE not found!"
    fi
else
    echo "Database $DB_NAME already exists. Skipping initialization."
fi

echo "Database $DB_NAME is ready!"
