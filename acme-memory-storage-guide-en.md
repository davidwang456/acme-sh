# ACME In-Memory Challenge Controller User Guide

## Overview

This guide explains how to use the in-memory storage based ACME HTTP-01 challenge controller, implemented with Spring Boot, which supports dynamic challenge response management without file system storage.

## Features

- ✅ **In-Memory Storage**: Uses ConcurrentHashMap for high-performance challenge response storage
- ✅ **Auto Expiry**: Supports automatic challenge response cleanup (default 5 minutes)
- ✅ **Batch Operations**: Supports batch addition and deletion of challenge responses
- ✅ **Real-time Monitoring**: Provides statistics and debugging interfaces
- ✅ **Health Checks**: Built-in health check endpoints
- ✅ **Logging**: Complete operation logging

## Quick Start

### 1. Start the Application

```bash
# Start with Maven
mvn spring-boot:run

# Or use Docker
docker-compose up -d
```

### 2. Verify Service Status

```bash
curl http://localhost:80/.well-known/acme-challenge/health
```

Expected response:
```json
{
  "status": "UP",
  "service": "ACME Challenge Controller",
  "timestamp": 1703123456789,
  "activeChallenges": 0
}
```

## API Endpoints

### 1. Add Challenge Response

**POST** `/.well-known/acme-challenge/{token}`

```bash
curl -X POST \
  -H "Content-Type: text/plain" \
  -d "token.test-response" \
  http://localhost:80/.well-known/acme-challenge/your-token-here
```

### 2. Get Challenge Response

**GET** `/.well-known/acme-challenge/{token}`

```bash
curl http://localhost:80/.well-known/acme-challenge/your-token-here
```

### 3. Delete Challenge Response

**DELETE** `/.well-known/acme-challenge/{token}`

```bash
curl -X DELETE http://localhost:80/.well-known/acme-challenge/your-token-here
```

### 4. Batch Add Challenge Responses

**POST** `/.well-known/acme-challenge/batch`

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "token1": "token1.response1",
    "token2": "token2.response2"
  }' \
  http://localhost:80/.well-known/acme-challenge/batch
```

### 5. Clear All Challenge Responses

**DELETE** `/.well-known/acme-challenge/clear`

```bash
curl -X DELETE http://localhost:80/.well-known/acme-challenge/clear
```

### 6. Get Statistics

**GET** `/.well-known/acme-challenge/debug/stats`

```bash
curl http://localhost:80/.well-known/acme-challenge/debug/stats
```

### 7. Get All Challenge Responses

**GET** `/.well-known/acme-challenge/debug/all`

```bash
curl http://localhost:80/.well-known/acme-challenge/debug/all
```

## Configuration Options

Configure in `application.yml`:

```yaml
acme:
  challenge:
    expiry: 300000  # Challenge response expiry time (milliseconds), default 5 minutes
```

## Integration with acme.sh

### 1. Configure acme.sh for HTTP-01 Validation

```bash
# Set HTTP-01 validation mode
export ACME_CHALLENGE_MODE="http01"

# Configure webroot path (required even with in-memory storage)
export ACME_WEBROOT="/tmp/webroot"
```

### 2. Create Custom Deployment Script

Create `deploy/memory_storage.sh`:

```bash
#!/bin/bash

# In-memory storage deployment script
# For acme.sh HTTP-01 validation

# Get parameters
domain="$1"
token="$2"
response="$3"

# Server address
SERVER_URL="http://localhost:80"

# Add challenge response to memory
curl -s -X POST \
  -H "Content-Type: text/plain" \
  -d "$response" \
  "${SERVER_URL}/.well-known/acme-challenge/${token}"

echo "Challenge response added to memory storage for domain: $domain, token: $token"
```

### 3. Use Custom Deployment Script

```bash
# Apply for certificate using custom deployment script
acme.sh --issue -d example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh
```

## Test Script

Use the provided test script to verify functionality:

```bash
# Run complete test
./test-acme-memory.sh

# Check service status
./test-acme-memory.sh --health

# Simulate ACME challenge flow
./test-acme-memory.sh --simulate

# Get statistics
./test-acme-memory.sh --stats
```

## Monitoring and Debugging

### 1. View Logs

```bash
# View application logs
tail -f logs/application.log

# Or use Docker
docker-compose logs -f acme-challenge-server
```

### 2. Monitor Challenge Responses

```bash
# Real-time monitoring of challenge response count
watch -n 1 'curl -s http://localhost:80/.well-known/acme-challenge/debug/stats | jq .'
```

### 3. Performance Monitoring

```bash
# Check memory usage
curl -s http://localhost:80/.well-known/acme-challenge/debug/stats | jq '.activeChallenges'
```

## Troubleshooting

### 1. Service Won't Start

**Issue**: Port is occupied
```bash
# Check port usage
netstat -tlnp | grep :80

# Or use lsof
lsof -i :80
```

**Solution**: Modify port configuration in `application.yml`

### 2. Challenge Response Not Found

**Issue**: Challenge response expired or deleted
```bash
# Check challenge response status
curl http://localhost:80/.well-known/acme-challenge/debug/all
```

**Solution**: Re-add challenge response

### 3. High Memory Usage

**Issue**: Challenge responses not cleaned up in time
```bash
# Manually clear expired responses
curl -X DELETE http://localhost:80/.well-known/acme-challenge/clear
```

**Solution**: Adjust expiry time configuration

## Best Practices

### 1. Security

- Use HTTPS in production environments
- Restrict access by source IP
- Regularly clean up expired challenge responses

### 2. Performance Optimization

- Set reasonable challenge response expiry time
- Monitor memory usage
- Use load balancer for high concurrency

### 3. Monitoring and Alerting

- Monitor service health status
- Set up challenge response count alerts
- Monitor response times

### 4. Backup and Recovery

- Regularly backup configurations
- Implement challenge response persistence (if needed)
- Prepare disaster recovery plans

## Example Scenarios

### Scenario 1: Single Domain Certificate Application

```bash
# 1. Start service
mvn spring-boot:run

# 2. Apply for certificate
acme.sh --issue -d example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh

# 3. Verify challenge response
curl http://localhost:80/.well-known/acme-challenge/your-token
```

### Scenario 2: Multi-Domain Certificate Application

```bash
# 1. Batch add challenge responses
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "token1": "response1",
    "token2": "response2"
  }' \
  http://localhost:80/.well-known/acme-challenge/batch

# 2. Apply for multi-domain certificate
acme.sh --issue -d example.com -d www.example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh
```

### Scenario 3: Automated Deployment

```bash
#!/bin/bash
# Automated deployment script

# Start service
docker-compose up -d

# Wait for service to start
sleep 10

# Apply for certificate
acme.sh --issue -d example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh

# Verify certificate
acme.sh --list
```

## Summary

The in-memory ACME challenge controller provides a high-performance, easy-to-manage HTTP-01 validation solution. With proper configuration and monitoring, it ensures smooth certificate application processes.

Key advantages:
- 🚀 High-performance in-memory storage
- 🔄 Automatic expiry management
- 📊 Real-time monitoring and statistics
- 🛠️ Rich management interfaces
- 📝 Complete logging

Suitable for scenarios requiring fast, reliable ACME validation, especially containerized deployments and automated certificate management. 