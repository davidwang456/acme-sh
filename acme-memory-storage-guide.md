# ACME 内存存储挑战控制器使用指南

## 概述

本指南介绍如何使用基于内存存储的 ACME HTTP-01 挑战控制器，该控制器使用 Spring Boot 实现，支持动态管理挑战响应，无需文件系统存储。

## 特性

- ✅ **内存存储**: 使用 ConcurrentHashMap 存储挑战响应，高性能
- ✅ **自动过期**: 支持挑战响应自动过期清理（默认5分钟）
- ✅ **批量操作**: 支持批量添加和删除挑战响应
- ✅ **实时监控**: 提供统计信息和调试接口
- ✅ **健康检查**: 内置健康检查端点
- ✅ **日志记录**: 完整的操作日志记录

## 快速开始

### 1. 启动应用

```bash
# 使用 Maven 启动
mvn spring-boot:run

# 或使用 Docker
docker-compose up -d
```

### 2. 验证服务状态

```bash
curl http://localhost:80/.well-known/acme-challenge/health
```

预期响应：
```json
{
  "status": "UP",
  "service": "ACME Challenge Controller",
  "timestamp": 1703123456789,
  "activeChallenges": 0
}
```

## API 接口

### 1. 添加挑战响应

**POST** `/.well-known/acme-challenge/{token}`

```bash
curl -X POST \
  -H "Content-Type: text/plain" \
  -d "token.test-response" \
  http://localhost:80/.well-known/acme-challenge/your-token-here
```

### 2. 获取挑战响应

**GET** `/.well-known/acme-challenge/{token}`

```bash
curl http://localhost:80/.well-known/acme-challenge/your-token-here
```

### 3. 删除挑战响应

**DELETE** `/.well-known/acme-challenge/{token}`

```bash
curl -X DELETE http://localhost:80/.well-known/acme-challenge/your-token-here
```

### 4. 批量添加挑战响应

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

### 5. 清空所有挑战响应

**DELETE** `/.well-known/acme-challenge/clear`

```bash
curl -X DELETE http://localhost:80/.well-known/acme-challenge/clear
```

### 6. 获取统计信息

**GET** `/.well-known/acme-challenge/debug/stats`

```bash
curl http://localhost:80/.well-known/acme-challenge/debug/stats
```

### 7. 获取所有挑战响应

**GET** `/.well-known/acme-challenge/debug/all`

```bash
curl http://localhost:80/.well-known/acme-challenge/debug/all
```

## 配置选项

在 `application.yml` 中配置：

```yaml
acme:
  challenge:
    expiry: 300000  # 挑战响应过期时间（毫秒），默认5分钟
```

## 与 acme.sh 集成

### 1. 配置 acme.sh 使用 HTTP-01 验证

```bash
# 设置 HTTP-01 验证方式
export ACME_CHALLENGE_MODE="http01"

# 配置 webroot 路径（虽然使用内存存储，但仍需要配置）
export ACME_WEBROOT="/tmp/webroot"
```

### 2. 创建自定义部署脚本

创建 `deploy/memory_storage.sh`：

```bash
#!/bin/bash

# 内存存储部署脚本
# 用于 acme.sh 的 HTTP-01 验证

# 获取参数
domain="$1"
token="$2"
response="$3"

# 服务器地址
SERVER_URL="http://localhost:80"

# 添加挑战响应到内存
curl -s -X POST \
  -H "Content-Type: text/plain" \
  -d "$response" \
  "${SERVER_URL}/.well-known/acme-challenge/${token}"

echo "Challenge response added to memory storage for domain: $domain, token: $token"
```

### 3. 使用自定义部署脚本

```bash
# 申请证书时使用自定义部署脚本
acme.sh --issue -d example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh
```

## 测试脚本

使用提供的测试脚本验证功能：

```bash
# 运行完整测试
./test-acme-memory.sh

# 检查服务状态
./test-acme-memory.sh --health

# 模拟 ACME 挑战流程
./test-acme-memory.sh --simulate

# 获取统计信息
./test-acme-memory.sh --stats
```

## 监控和调试

### 1. 查看日志

```bash
# 查看应用日志
tail -f logs/application.log

# 或使用 Docker
docker-compose logs -f acme-challenge-server
```

### 2. 监控挑战响应

```bash
# 实时监控挑战响应数量
watch -n 1 'curl -s http://localhost:80/.well-known/acme-challenge/debug/stats | jq .'
```

### 3. 性能监控

```bash
# 查看内存使用情况
curl -s http://localhost:80/.well-known/acme-challenge/debug/stats | jq '.activeChallenges'
```

## 故障排除

### 1. 服务无法启动

**问题**: 端口被占用
```bash
# 检查端口占用
netstat -tlnp | grep :80

# 或使用 lsof
lsof -i :80
```

**解决方案**: 修改 `application.yml` 中的端口配置

### 2. 挑战响应未找到

**问题**: 挑战响应已过期或被删除
```bash
# 检查挑战响应状态
curl http://localhost:80/.well-known/acme-challenge/debug/all
```

**解决方案**: 重新添加挑战响应

### 3. 内存使用过高

**问题**: 挑战响应未及时清理
```bash
# 手动清理过期响应
curl -X DELETE http://localhost:80/.well-known/acme-challenge/clear
```

**解决方案**: 调整过期时间配置

## 最佳实践

### 1. 安全性

- 在生产环境中使用 HTTPS
- 限制访问来源 IP
- 定期清理过期的挑战响应

### 2. 性能优化

- 合理设置挑战响应过期时间
- 监控内存使用情况
- 使用负载均衡器处理高并发

### 3. 监控告警

- 监控服务健康状态
- 设置挑战响应数量告警
- 监控响应时间

### 4. 备份和恢复

- 定期备份配置
- 实现挑战响应的持久化（如需要）
- 准备故障恢复方案

## 示例场景

### 场景1: 单域名证书申请

```bash
# 1. 启动服务
mvn spring-boot:run

# 2. 申请证书
acme.sh --issue -d example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh

# 3. 验证挑战响应
curl http://localhost:80/.well-known/acme-challenge/your-token
```

### 场景2: 多域名证书申请

```bash
# 1. 批量添加挑战响应
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "token1": "response1",
    "token2": "response2"
  }' \
  http://localhost:80/.well-known/acme-challenge/batch

# 2. 申请多域名证书
acme.sh --issue -d example.com -d www.example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh
```

### 场景3: 自动化部署

```bash
#!/bin/bash
# 自动化部署脚本

# 启动服务
docker-compose up -d

# 等待服务启动
sleep 10

# 申请证书
acme.sh --issue -d example.com --webroot /tmp/webroot --deploy-hook ./deploy/memory_storage.sh

# 验证证书
acme.sh --list
```

## 总结

内存存储的 ACME 挑战控制器提供了高性能、易管理的 HTTP-01 验证解决方案。通过合理配置和监控，可以确保证书申请过程的顺利进行。

主要优势：
- 🚀 高性能内存存储
- 🔄 自动过期管理
- 📊 实时监控统计
- 🛠️ 丰富的管理接口
- 📝 完整的日志记录

适用于需要快速、可靠 ACME 验证的场景，特别是容器化部署和自动化证书管理。 