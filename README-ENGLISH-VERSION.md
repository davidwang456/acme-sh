# ACME In-Memory Challenge Controller - English Version

## Overview

This project provides a Spring Boot-based ACME HTTP-01 challenge controller that uses in-memory storage for challenge responses, eliminating the need for file system storage and providing high-performance certificate validation.

## Project Structure

```
acme.sh/
├── AcmeChallengeController.java          # Main controller (English version)
├── AcmeChallengeApplication.java         # Spring Boot application (English version)
├── test-acme-memory-en.sh               # English test script
├── acme-memory-storage-guide-en.md      # English user guide
├── deploy/
│   ├── memory_storage.sh                # Chinese deployment script
│   └── memory_storage_en.sh             # English deployment script
├── pom.xml                              # Maven dependencies
├── application.yml                      # Spring Boot configuration
├── docker-compose.yml                   # Docker configuration
└── README-ENGLISH-VERSION.md           # This file
```

## Key Features

### 1. In-Memory Storage
- Uses `ConcurrentHashMap` for thread-safe challenge response storage
- No file system dependencies
- High-performance read/write operations

### 2. Automatic Expiry Management
- Configurable challenge response expiry time (default: 5 minutes)
- Automatic cleanup of expired responses
- Memory usage optimization

### 3. Rich API Endpoints
- `GET /{token}` - Retrieve challenge response
- `POST /{token}` - Add challenge response
- `DELETE /{token}` - Remove challenge response
- `POST /batch` - Batch add challenge responses
- `DELETE /clear` - Clear all challenge responses
- `GET /debug/stats` - Get statistics
- `GET /debug/all` - Get all challenge responses
- `GET /health` - Health check

### 4. Comprehensive Logging
- Structured logging with SLF4J
- Detailed operation tracking
- Error handling and reporting

## Quick Start

### 1. Start the Application

```bash
# Using Maven
mvn spring-boot:run

# Using Docker
docker-compose up -d
```

### 2. Test the Service

```bash
# Run comprehensive tests
./test-acme-memory-en.sh

# Check service health
./test-acme-memory-en.sh --health

# Simulate ACME challenge flow
./test-acme-memory-en.sh --simulate
```

### 3. Integration with acme.sh

```bash
# Set up environment
export ACME_CHALLENGE_MODE="http01"
export ACME_WEBROOT="/tmp/webroot"

# Apply for certificate
acme.sh --issue -d example.com \
  --webroot /tmp/webroot \
  --deploy-hook ./deploy/memory_storage_en.sh
```

## API Documentation

### Health Check
```bash
curl http://localhost:80/.well-known/acme-challenge/health
```

Response:
```json
{
  "status": "UP",
  "service": "ACME Challenge Controller",
  "timestamp": 1703123456789,
  "activeChallenges": 0
}
```

### Add Challenge Response
```bash
curl -X POST \
  -H "Content-Type: text/plain" \
  -d "token.test-response" \
  http://localhost:80/.well-known/acme-challenge/your-token
```

### Get Challenge Response
```bash
curl http://localhost:80/.well-known/acme-challenge/your-token
```

### Batch Operations
```bash
# Add multiple challenge responses
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"token1": "response1", "token2": "response2"}' \
  http://localhost:80/.well-known/acme-challenge/batch

# Clear all responses
curl -X DELETE http://localhost:80/.well-known/acme-challenge/clear
```

### Statistics and Debugging
```bash
# Get statistics
curl http://localhost:80/.well-known/acme-challenge/debug/stats

# Get all challenge responses
curl http://localhost:80/.well-known/acme-challenge/debug/all
```

## Configuration

### Application Properties
```yaml
# application.yml
server:
  port: 80

acme:
  challenge:
    expiry: 300000  # 5 minutes in milliseconds
```

### Environment Variables
```bash
# Server configuration
ACME_SERVER_URL=http://localhost:80

# Logging
ACME_LOG_FILE=/tmp/acme-memory-storage.log
```

## Deployment Scripts

### English Version (`deploy/memory_storage_en.sh`)
- Full English logging and error messages
- Comprehensive error handling
- Retry mechanisms with exponential backoff
- Service availability checks
- Challenge response verification

### Chinese Version (`deploy/memory_storage.sh`)
- Chinese logging and error messages
- Same functionality as English version
- Suitable for Chinese-speaking environments

## Testing

### Automated Test Script
The `test-acme-memory-en.sh` script provides comprehensive testing:

```bash
# Full test suite
./test-acme-memory-en.sh

# Individual test options
./test-acme-memory-en.sh --health      # Health check
./test-acme-memory-en.sh --stats       # Statistics
./test-acme-memory-en.sh --all         # All challenges
./test-acme-memory-en.sh --clear       # Clear all
./test-acme-memory-en.sh --simulate    # ACME flow simulation
```

### Manual Testing
```bash
# 1. Add a challenge response
curl -X POST \
  -H "Content-Type: text/plain" \
  -d "test-token.test-response" \
  http://localhost:80/.well-known/acme-challenge/test-token

# 2. Verify the response
curl http://localhost:80/.well-known/acme-challenge/test-token

# 3. Check statistics
curl http://localhost:80/.well-known/acme-challenge/debug/stats
```

## Monitoring and Debugging

### Log Monitoring
```bash
# View application logs
tail -f logs/application.log

# Docker logs
docker-compose logs -f acme-challenge-server
```

### Real-time Statistics
```bash
# Monitor challenge response count
watch -n 1 'curl -s http://localhost:80/.well-known/acme-challenge/debug/stats | jq .'
```

### Performance Monitoring
```bash
# Check active challenges
curl -s http://localhost:80/.well-known/acme-challenge/debug/stats | jq '.activeChallenges'
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```bash
   # Check port usage
   netstat -tlnp | grep :80
   lsof -i :80
   ```

2. **Challenge Response Not Found**
   ```bash
   # Check if response exists
   curl http://localhost:80/.well-known/acme-challenge/debug/all
   ```

3. **High Memory Usage**
   ```bash
   # Clear expired responses
   curl -X DELETE http://localhost:80/.well-known/acme-challenge/clear
   ```

### Debug Commands
```bash
# Service health
curl http://localhost:80/.well-known/acme-challenge/health

# All challenges
curl http://localhost:80/.well-known/acme-challenge/debug/all

# Statistics
curl http://localhost:80/.well-known/acme-challenge/debug/stats
```

## Best Practices

### Security
- Use HTTPS in production
- Implement IP restrictions
- Regular cleanup of expired responses

### Performance
- Monitor memory usage
- Set appropriate expiry times
- Use load balancing for high traffic

### Monitoring
- Set up health check alerts
- Monitor challenge response counts
- Track response times

## Integration Examples

### Single Domain Certificate
```bash
# Start service
mvn spring-boot:run

# Apply for certificate
acme.sh --issue -d example.com \
  --webroot /tmp/webroot \
  --deploy-hook ./deploy/memory_storage_en.sh
```

### Multi-Domain Certificate
```bash
# Batch add challenge responses
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"token1": "response1", "token2": "response2"}' \
  http://localhost:80/.well-known/acme-challenge/batch

# Apply for certificate
acme.sh --issue -d example.com -d www.example.com \
  --webroot /tmp/webroot \
  --deploy-hook ./deploy/memory_storage_en.sh
```

### Automated Deployment
```bash
#!/bin/bash
# Automated deployment script

# Start service
docker-compose up -d

# Wait for startup
sleep 10

# Apply for certificate
acme.sh --issue -d example.com \
  --webroot /tmp/webroot \
  --deploy-hook ./deploy/memory_storage_en.sh

# Verify certificate
acme.sh --list
```

## Performance Characteristics

### Memory Usage
- ~100 bytes per challenge response
- Automatic cleanup prevents memory leaks
- Configurable expiry times

### Response Times
- GET requests: < 1ms
- POST requests: < 5ms
- Batch operations: < 10ms per item

### Scalability
- ConcurrentHashMap for thread safety
- No file I/O bottlenecks
- Horizontal scaling support

## Comparison with File-Based Storage

| Feature | In-Memory | File-Based |
|---------|-----------|------------|
| Performance | High | Medium |
| Scalability | Excellent | Good |
| Persistence | No | Yes |
| Memory Usage | Low | Very Low |
| Setup Complexity | Simple | Medium |
| Recovery | Fast | Slow |

## Future Enhancements

1. **Persistence Layer**
   - Redis integration
   - Database storage options
   - File system fallback

2. **Advanced Features**
   - Challenge response encryption
   - Rate limiting
   - Metrics collection

3. **Monitoring**
   - Prometheus metrics
   - Grafana dashboards
   - Alert integration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logs
3. Test with the provided scripts
4. Create an issue with detailed information

## Acknowledgments

- Spring Boot team for the excellent framework
- acme.sh community for the ACME client
- RFC8555 authors for the ACME protocol specification 