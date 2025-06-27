# step-ca ACME HTTP-01 挑战流程详解

## 概述

ACME HTTP-01 挑战是 RFC8555 标准中定义的域名所有权验证方法。当 acme.sh 向 step-ca 申请证书时，step-ca 会要求验证申请者是否真正控制该域名。

## 完整流程时序图

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   acme.sh   │    │   step-ca   │    │ Spring Boot │    │   Internet  │
│  (客户端)    │    │  (CA服务器)  │    │  (挑战服务器) │    │   (验证者)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       │ 1. 申请证书       │                   │                   │
       │ POST /new-order   │                   │                   │
       │──────────────────>│                   │                   │
       │                   │                   │                   │
       │ 2. 返回挑战       │                   │                   │
       │ 200 OK            │                   │                   │
       │<──────────────────│                   │                   │
       │                   │                   │                   │
       │ 3. 准备挑战响应   │                   │                   │
       │ 计算 token.keyAuth │                   │                   │
       │                   │                   │                   │
       │ 4. 创建验证文件   │                   │                   │
       │ 写入 /.well-known/│                   │                   │
       │ acme-challenge/   │                   │                   │
       │──────────────────────────────────────>│                   │
       │                   │                   │                   │
       │ 5. 通知 CA 准备就绪│                   │                   │
       │ POST /challenges  │                   │                   │
       │ status: pending   │                   │                   │
       │──────────────────>│                   │                   │
       │                   │                   │                   │
       │ 6. 开始验证       │                   │                   │
       │ GET /.well-known/ │                   │                   │
       │ acme-challenge/   │                   │                   │
       │──────────────────────────────────────>│                   │
       │                   │                   │                   │
       │ 7. 返回挑战响应   │                   │                   │
       │ 200 OK            │                   │                   │
       │<──────────────────────────────────────│                   │
       │                   │                   │                   │
       │ 8. 验证响应       │                   │                   │
       │ 计算并比较 keyAuth│                   │                   │
       │                   │                   │                   │
       │ 9. 通知验证结果   │                   │                   │
       │ POST /challenges  │                   │                   │
       │ status: valid     │                   │                   │
       │──────────────────>│                   │                   │
       │                   │                   │                   │
       │ 10. 签发证书      │                   │                   │
       │ POST /finalize    │                   │                   │
       │──────────────────>│                   │                   │
       │                   │                   │
       │ 11. 下载证书      │                   │
       │ GET /certificate  │                   │
       │<──────────────────│                   │
```

## 详细步骤说明

### 阶段1：证书申请和挑战创建

#### 步骤1：申请证书
```bash
# acme.sh 向 step-ca 申请证书
POST https://stepca:9000/acme/acme/new-order
Content-Type: application/jose+json

{
  "protected": "base64url(header)",
  "payload": "base64url({
    \"identifiers\": [
      {\"type\": \"dns\", \"value\": \"example.com\"}
    ]
  })",
  "signature": "base64url(signature)"
}
```

#### 步骤2：step-ca 返回挑战
```json
{
  "status": "pending",
  "expires": "2024-01-01T12:00:00Z",
  "identifiers": [
    {"type": "dns", "value": "example.com"}
  ],
  "authorizations": [
    "https://stepca:9000/acme/acme/authz/abc123"
  ],
  "finalize": "https://stepca:9000/acme/acme/order/abc123/finalize"
}
```

#### 步骤3：获取授权详情
```bash
GET https://stepca:9000/acme/acme/authz/abc123
```

响应：
```json
{
  "identifier": {"type": "dns", "value": "example.com"},
  "status": "pending",
  "expires": "2024-01-01T12:00:00Z",
  "challenges": [
    {
      "type": "http-01",
      "url": "https://stepca:9000/acme/acme/challenge/abc123/def456",
      "status": "pending",
      "token": "abc123def456"
    }
  ]
}
```

### 阶段2：挑战准备

#### 步骤4：计算挑战响应
acme.sh 计算 `keyAuth`：
```bash
# 计算账户密钥的 SHA256 指纹
accountKeyThumbprint = base64url(SHA256(accountKey))

# 构造 keyAuth
keyAuth = token + "." + accountKeyThumbprint
```

#### 步骤5：创建验证文件
acme.sh 在 webroot 目录创建文件：
```bash
# 文件路径
/tmp/webroot/.well-known/acme-challenge/abc123def456

# 文件内容
abc123def456.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImp3ayI6eyJrdHkiOiJSU0EiLCJuIjoi...（base64url编码的账户密钥指纹）
```

### 阶段3：挑战验证

#### 步骤6：通知 CA 准备就绪
```bash
POST https://stepca:9000/acme/acme/challenge/abc123/def456
Content-Type: application/jose+json

{
  "protected": "base64url(header)",
  "payload": "base64url({})",
  "signature": "base64url(signature)"
}
```

#### 步骤7：step-ca 发起验证
step-ca 向域名发起 HTTP 请求：
```bash
GET http://example.com/.well-known/acme-challenge/abc123def456
```

#### 步骤8：Spring Boot 响应挑战
```java
@GetMapping("/.well-known/acme-challenge/{token}")
public ResponseEntity<String> handleAcmeChallenge(@PathVariable String token) {
    // 从文件系统读取挑战响应
    String response = readChallengeFromFile(token);
    return ResponseEntity.ok(response);
}
```

响应内容：
```
abc123def456.eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImp3ayI6eyJrdHkiOiJSU0EiLCJuIjoi...
```

#### 步骤9：step-ca 验证响应
step-ca 验证响应内容：
1. 解析 token 和 keyAuth
2. 计算账户密钥指纹
3. 比较 keyAuth 是否匹配
4. 验证账户密钥是否与申请者匹配

#### 步骤10：更新挑战状态
```json
{
  "type": "http-01",
  "url": "https://stepca:9000/acme/acme/challenge/abc123/def456",
  "status": "valid",
  "validated": "2024-01-01T12:00:00Z"
}
```

### 阶段4：证书签发

#### 步骤11：完成订单
```bash
POST https://stepca:9000/acme/acme/order/abc123/finalize
Content-Type: application/jose+json

{
  "protected": "base64url(header)",
  "payload": "base64url({
    \"csr\": \"base64url(certificate signing request)\"
  })",
  "signature": "base64url(signature)"
}
```

#### 步骤12：下载证书
```bash
GET https://stepca:9000/acme/acme/certificate/abc123
```

## 关键技术细节

### 1. keyAuth 计算
```bash
# 伪代码
accountKeyThumbprint = base64url(SHA256(accountKey))
keyAuth = token + "." + accountKeyThumbprint
```

### 2. 文件路径规范
```
http://example.com/.well-known/acme-challenge/{token}
```

### 3. 响应格式
- Content-Type: text/plain
- 响应体：keyAuth 字符串
- 无额外的 HTTP 头

### 4. 验证超时
- 默认超时时间：10 秒
- 重试次数：通常 3-5 次
- 验证间隔：2-5 秒

## 错误处理

### 常见错误场景

#### 1. 文件不存在
```
HTTP/1.1 404 Not Found
```

#### 2. 响应格式错误
```
HTTP/1.1 200 OK
Content-Type: application/json  # 错误：应该是 text/plain

{"error": "invalid response"}
```

#### 3. 网络超时
```
HTTP/1.1 408 Request Timeout
```

#### 4. 服务器错误
```
HTTP/1.1 500 Internal Server Error
```

### 验证失败处理
```json
{
  "type": "http-01",
  "url": "https://stepca:9000/acme/acme/challenge/abc123/def456",
  "status": "invalid",
  "error": {
    "type": "urn:ietf:params:acme:error:connection",
    "detail": "Connection refused",
    "status": 400
  }
}
```

## 调试和监控

### 1. 启用详细日志
```yaml
logging:
  level:
    com.example.acme: DEBUG
    org.springframework.web: DEBUG
```

### 2. 监控挑战请求
```java
@GetMapping("/{token}")
public ResponseEntity<String> handleAcmeChallenge(@PathVariable String token) {
    log.info("ACME challenge request for token: {}", token);
    // 处理逻辑
    log.info("ACME challenge response: {}", response);
    return ResponseEntity.ok(response);
}
```

### 3. 验证文件监控
```bash
# 监控文件创建
watch -n 1 "ls -la /tmp/webroot/.well-known/acme-challenge/"

# 监控文件内容
tail -f /tmp/webroot/.well-known/acme-challenge/*
```

## 安全考虑

### 1. 文件权限
```bash
# 设置适当的文件权限
chmod 644 /tmp/webroot/.well-known/acme-challenge/*
chmod 755 /tmp/webroot/.well-known/acme-challenge/
```

### 2. 路径遍历防护
```java
// 防止路径遍历攻击
if (token.contains("..") || token.contains("/")) {
    return ResponseEntity.badRequest().build();
}
```

### 3. 内容验证
```java
// 验证响应格式
if (!response.matches("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$")) {
    return ResponseEntity.badRequest().build();
}
```

## 总结

ACME HTTP-01 挑战流程是一个精心设计的域名所有权验证机制：

1. **安全性**：通过密码学验证确保只有域名控制者能通过验证
2. **可靠性**：支持重试和超时机制
3. **标准化**：遵循 RFC8555 标准，确保互操作性
4. **自动化**：整个过程可以完全自动化

理解这个流程对于调试 ACME 证书申请问题和实现自定义挑战服务器非常重要。 