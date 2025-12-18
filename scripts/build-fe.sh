# File: build-and-push.sh
#!/bin/bash

echo "Building Admin UI..."
cd booking-care-system-ui-admin
docker buildx build --platform linux/amd64 \
    --build-arg VITE_API_URL=$VITE_API_URL \
    --build-arg VITE_RECAPTCHA_SITE_KEY=$VITE_RECAPTCHA_SITE_KEY \
    --build-arg VITE_GOOGLE_CLIENT_ID=$VITE_GOOGLE_CLIENT_ID \
    --build-arg VITE_FACEBOOK_APP_ID=$VITE_FACEBOOK_APP_ID \
    --build-arg MABS_APP_NAME="BookingCare Admin" \
    -t hiumx/bookingcare-frontend-admin:latest \
    --push .

echo "Building Patient UI..."
cd ../booking-care-system-ui
docker buildx build --platform linux/amd64 \
    --build-arg VITE_API_URL=$VITE_API_URL \
    --build-arg VITE_RECAPTCHA_SITE_KEY=$VITE_RECAPTCHA_SITE_KEY \
    --build-arg VITE_GOOGLE_CLIENT_ID=$VITE_GOOGLE_CLIENT_ID \
    --build-arg VITE_FACEBOOK_APP_ID=$VITE_FACEBOOK_APP_ID \
    --build-arg VITE_DEVICE_ID=web-production \
    -t hiumx/bookingcare-frontend:latest \
    --push .

echo "Done! Images pushed to Docker Hub"

cd /home/ubuntu/projects/booking-care-integration

# Pull latest images
docker-compose pull ui-user ui-admin

# Recreate containers
docker-compose up -d --force-recreate doctor-service

# Verify
docker ps | grep ui

docker build --platform linux/amd64 -t hiumx/bookingcare-api-gateway:latest -f src/ApiGateway/BookingCare.ApiGateway.Ocelot/Dockerfile . && docker push hiumx/bookingcare-api-gateway:latest   

docker build --platform linux/amd64 -t hiumx/bookingcare-hospital-service:latest -f src/Services/BookingCare.Services.Hospital/Dockerfile . && docker push hiumx/bookingcare-hospital-service:latest   

docker build --platform linux/amd64 -t hiumx/bookingcare-service-medical-service:latest -f src/Services/BookingCare.Services.ServiceMedical/Dockerfile . && docker push hiumx/bookingcare-service-medical-service:latest   

docker build --platform linux/amd64 -t hiumx/bookingcare-ai-service:latest -f src/Services/BookingCare.Services.AI/Dockerfile . && docker push hiumx/bookingcare-ai-service:latest

docker build --platform linux/amd64 -t hiumx/bookingcare-schedule-service:latest -f src/Services/BookingCare.Services.Schedule/Dockerfile . && docker push hiumx/bookingcare-schedule-service:latest

docker build --platform linux/amd64 -t hiumx/bookingcare-doctor-service:latest -f src/Services/BookingCare.Services.Doctor/Dockerfile . && docker push hiumx/bookingcare-doctor-service:latest   

docker build --platform linux/amd64 -t hiumx/bookingcare-servicemedical-service:latest -f src/Services/BookingCare.Services.ServiceMedical/Dockerfile . && docker push hiumx/bookingcare-servicemedical-service:latest
    
docker build --platform linux/amd64 -t hiumx/bookingcare-servicemedical-service:latest -f src/Services/BookingCare.Services.ServiceMedical/Dockerfile . && docker push hiumx/bookingcare-servicemedical-service:latest
docker build --platform linux/amd64 -t hiumx/bookingcare-payment-service:latest -f src/Services/BookingCare.Services.Payment/Dockerfile . && docker push hiumx/bookingcare-payment-service:latest


docker build --platform linux/amd64 -t hiumx/bookingcare-saga-service:latest -f src/Services/BookingCare.Services.Saga/Dockerfile . && docker push hiumx/bookingcare-saga-service:latest  