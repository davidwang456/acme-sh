# acme.sh Docker 镜像测试 step-ca ACME 服务器用户手册

## 目录
1. [证书流程详解](#证书流程详解)
2. [概述](#概述)
3. [前置要求](#前置要求)
4. [快速开始](#快速开始)
5. [详细配置](#详细配置)
6. [常用命令](#常用命令)
7. [故障排除](#故障排除)
8. [高级用法](#高级用法)

## 证书流程详解

在开始使用之前，让我们先理解证书的完整流程：

### 证书申请流程

```
1. 用户请求证书
   acme.sh --issue -d example.com
   ↓
2. acme.sh 向 step-ca 服务器发送申请
   POST /acme/acme/directory
   ↓
3. step-ca 返回挑战信息
   HTTP-01: 需要验证文件
   DNS-01: 需要验证 DNS 记录
   TLS-ALPN-01: 需要验证 TLS 握手
   ↓
4. acme.sh 完成域名验证
   放置验证文件或设置 DNS 记录
   ↓
5. step-ca 验证域名所有权
   访问验证文件或查询 DNS 记录
   ↓
6. step-ca 签发证书
   生成 SSL/TLS 证书
   ↓
7. acme.sh 下载并保存证书
   证书文件保存到本地
```

### 证书文件位置和用途

当证书申请成功后，acme.sh 会在容器内的 `/acme.sh` 目录下创建以下文件：

```
/acme.sh/
├── example.com/                    # 域名目录
│   ├── example.com.cer            # 证书文件
│   ├── example.com.key            # 私钥文件
│   ├── ca.cer                     # CA 证书
│   ├── fullchain.cer              # 完整证书链
│   └── example.com.conf           # 域名配置
├── account.conf                   # 账户配置
└── ca/                           # CA 相关文件
    └── localhost_9000/
        └── acme/
            ├── account.key        # 账户私钥
            └── account.json       # 账户信息
```

### 证书部署流程

```
1. 证书申请完成
   /acme.sh/example.com/example.com.cer
   ↓
2. 部署到 Web 服务器
   --deploy-hook nginx/apache
   ↓
3. Web 服务器使用证书
   Nginx/Apache 配置 SSL
   ↓
4. 客户端访问 HTTPS
   浏览器验证证书有效性
```

### 实际使用场景示例

#### 场景1：为网站申请 SSL 证书

```bash
# 1. 申请证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v /var/www/html:/tmp/webroot \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot

# 2. 证书文件位置
# 容器内：/acme.sh/example.com/example.com.cer
# 宿主机：通过数据卷 acme-data 访问

# 3. 部署到 Nginx
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v /etc/nginx:/etc/nginx \
  neilpang/acme.sh:latest \
  --install-cert \
  -d example.com \
  --key-file /etc/nginx/ssl/example.com.key \
  --fullchain-file /etc/nginx/ssl/example.com.crt \
  --reloadcmd "nginx -s reload"
```

#### 场景2：证书续期流程

```bash
# 1. 自动续期（每天检查）
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --renew-all

# 2. 续期后的文件更新
# - 新证书替换旧证书
# - 自动重新部署（如果配置了 --reloadcmd）
# - 日志记录续期结果
```

### 证书文件说明

| 文件 | 用途 | 位置 |
|------|------|------|
| `example.com.cer` | 域名证书 | `/acme.sh/example.com/` |
| `example.com.key` | 私钥文件 | `/acme.sh/example.com/` |
| `ca.cer` | CA 证书 | `/acme.sh/example.com/` |
| `fullchain.cer` | 完整证书链 | `/acme.sh/example.com/` |

### 数据流向图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   step-ca       │    │   acme.sh       │    │   Web Server    │
│   (CA 服务器)    │    │   (客户端)       │    │   (Nginx/Apache) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. 证书申请           │                       │
         │<──────────────────────│                       │
         │                       │                       │
         │ 2. 返回挑战           │                       │
         │──────────────────────>│                       │
         │                       │                       │
         │ 3. 域名验证           │                       │
         │<──────────────────────│                       │
         │                       │                       │
         │ 4. 签发证书           │                       │
         │──────────────────────>│                       │
         │                       │                       │
         │                       │ 5. 保存证书           │
         │                       │ /acme.sh/example.com/ │
         │                       │                       │
         │                       │ 6. 部署证书           │
         │                       │──────────────────────>│
         │                       │                       │
         │                       │ 7. 配置 SSL           │
         │                       │ /etc/nginx/ssl/       │
```

### 关键要点

1. **证书来源**：证书由 step-ca 服务器签发
2. **证书存储**：证书保存在 acme.sh 容器的 `/acme.sh` 目录
3. **证书使用**：通过数据卷挂载或部署钩子将证书提供给 Web 服务器
4. **证书续期**：acme.sh 自动检查并续期即将过期的证书
5. **证书验证**：浏览器通过 CA 证书验证网站证书的有效性

## 概述

本手册将指导您如何使用 acme.sh Docker 镜像来测试 step-ca ACME 服务器。acme.sh 是一个纯 Shell 脚本实现的 ACME 协议客户端，支持多种证书颁发机构（CA），包括自定义的 step-ca 服务器。

### 主要特性
- 支持 RFC8555 标准的 ACME 协议
- 支持 ECDSA 和 RSA 证书
- 支持通配符证书和 SAN 证书
- 支持多种验证方式（HTTP-01、DNS-01、TLS-ALPN-01）
- Docker 容器化部署
- 自动证书续期

## 前置要求

### 系统要求
- Docker 20.10 或更高版本
- Docker Compose（可选，用于复杂部署）
- 至少 512MB 可用内存
- 至少 1GB 可用磁盘空间

### 网络要求
- 能够访问 step-ca 服务器
- 如果使用 HTTP-01 验证，需要确保 80 端口可访问
- 如果使用 DNS-01 验证，需要配置相应的 DNS API

## 快速开始

### 1. 启动 step-ca 服务器

首先，您需要启动一个 step-ca 服务器用于测试。可以使用以下命令快速启动：

```bash
# 启动 step-ca 服务器
docker run --rm -d \
  -p 9000:9000 \
  -e "DOCKER_STEPCA_INIT_NAME=Smallstep" \
  -e "DOCKER_STEPCA_INIT_DNS_NAMES=localhost,$(hostname -f)" \
  -e "DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT=true" \
  -e "DOCKER_STEPCA_INIT_PASSWORD=test" \
  --name stepca \
  smallstep/step-ca:latest

# 等待服务器启动
sleep 5

# 添加 ACME provisioner
docker exec stepca bash -c "echo test >test" \
  && docker exec stepca step ca provisioner add acme --type ACME --admin-subject step --admin-password-file=/home/step/test \
  && docker exec stepca kill -1 1

# 获取 CA 根证书并添加到系统信任
docker exec stepca cat /home/step/certs/root_ca.crt | sudo bash -c "cat - >>/etc/ssl/certs/ca-certificates.crt"
```

### 2. 使用 acme.sh Docker 镜像

#### 基本用法

```bash
# 拉取 acme.sh Docker 镜像
docker pull neilpang/acme.sh:latest

# 创建数据卷用于持久化配置
docker volume create acme-data

# 运行 acme.sh 容器
docker run --rm -it \
  -v acme-data:/acme.sh \
  --network host \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot
```

#### 使用 Docker Compose（推荐）

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  stepca:
    image: smallstep/step-ca:latest
    container_name: stepca
    ports:
      - "9000:9000"
    environment:
      - DOCKER_STEPCA_INIT_NAME=Smallstep
      - DOCKER_STEPCA_INIT_DNS_NAMES=localhost,stepca.local
      - DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT=true
      - DOCKER_STEPCA_INIT_PASSWORD=test
    volumes:
      - stepca-data:/home/step
    restart: unless-stopped

  acmesh:
    image: neilpang/acme.sh:latest
    container_name: acmesh
    volumes:
      - acme-data:/acme.sh
      - ./webroot:/tmp/webroot
    depends_on:
      - stepca
    environment:
      - ACME_DIRECTORY=https://stepca:9000/acme/acme/directory
    restart: unless-stopped

volumes:
  stepca-data:
  acme-data:
```

启动服务：

```bash
docker-compose up -d
```

## 详细配置

### 1. 配置 step-ca 服务器

#### 创建 step-ca 配置文件

创建 `step-ca.json` 配置文件：

```json
{
  "address": ":9000",
  "root": "/home/step/certs/root_ca.crt",
  "crt": "/home/step/certs/intermediate_ca.crt",
  "key": "/home/step/certs/intermediate_ca_key",
  "dnsNames": ["localhost", "stepca.local"],
  "logger": {
    "format": "text"
  },
  "db": {
    "type": "badgerV2",
    "dataSource": "/home/step/db"
  },
  "authority": {
    "provisioners": [
      {
        "type": "ACME",
        "name": "acme",
        "forceCN": false
      }
    ]
  }
}
```

#### 初始化 step-ca

```bash
# 初始化 step-ca
docker run --rm -it \
  -v stepca-data:/home/step \
  smallstep/step-ca:latest \
  step ca init \
  --name "Smallstep" \
  --dns "localhost,stepca.local" \
  --address ":9000" \
  --provisioner "acme@smallstep.com"

# 启动 step-ca
docker run --rm -d \
  -v stepca-data:/home/step \
  -p 9000:9000 \
  --name stepca \
  smallstep/step-ca:latest
```

### 2. 配置 acme.sh

#### 设置默认 CA 服务器

```bash
# 设置默认 CA 服务器为 step-ca
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --set-default-ca \
  --server https://localhost:9000/acme/acme/directory
```

#### 配置账户信息

```bash
# 注册账户（如果需要）
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --register-account \
  --server https://localhost:9000/acme/acme/directory \
  --accountemail your-email@example.com
```

### 3. 验证方式配置

#### HTTP-01 验证

```bash
# 使用 HTTP-01 验证
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v ./webroot:/tmp/webroot \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot
```

#### DNS-01 验证

```bash
# 使用 DNS-01 验证（以 Cloudflare 为例）
docker run --rm -it \
  -v acme-data:/acme.sh \
  -e CF_Key="your-cloudflare-api-key" \
  -e CF_Email="your-email@example.com" \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  --dns dns_cf
```

#### TLS-ALPN-01 验证

```bash
# 使用 TLS-ALPN-01 验证
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  --tls-alpn-01
```

## 常用命令

### 证书管理

```bash
# 申请证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot

# 续期证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --renew \
  -d example.com

# 续期所有证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --renew-all

# 撤销证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --revoke \
  -d example.com

# 删除证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --remove \
  -d example.com
```

### 证书信息查看

```bash
# 查看证书列表
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --list

# 查看证书详细信息
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --info \
  -d example.com

# 查看证书内容
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --showcsr \
  -d example.com
```

### 配置管理

```bash
# 查看帮助
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --help

# 查看版本
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --version

# 查看配置信息
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --info
```

## 故障排除

### 常见问题

#### 1. 连接 step-ca 服务器失败

**错误信息：**
```
Cannot init API for https://localhost:9000/acme/acme/directory
```

**解决方案：**
```bash
# 检查 step-ca 服务器是否运行
docker ps | grep stepca

# 检查端口是否开放
curl -k https://localhost:9000/acme/acme/directory

# 重启 step-ca 服务器
docker restart stepca
```

#### 1.1. 证书验证问题（重要）

**问题原因：**
acme.sh 无法验证 step-ca 的自签名证书，导致 HTTPS 连接失败。

**解决方案：**

##### 方案A：使用 --insecure 参数（临时解决）
```bash
# 设置环境变量跳过证书验证
docker run --rm -it \
  -v acme-data:/acme.sh \
  -e HTTPS_INSECURE=1 \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot
```

##### 方案B：添加 step-ca 根证书（推荐）
```bash
# 1. 获取 step-ca 的根证书
docker exec stepca cat /home/step/certs/root_ca.crt > stepca-root.crt

# 2. 将根证书添加到 acme.sh 容器
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v $(pwd)/stepca-root.crt:/stepca-root.crt \
  neilpang/acme.sh:latest \
  sh -c "cp /stepca-root.crt /usr/local/share/ca-certificates/ && update-ca-certificates && acme.sh --issue --server https://localhost:9000/acme/acme/directory -d example.com -w /tmp/webroot"
```

##### 方案C：使用 CA_PATH 环境变量
```bash
# 使用自定义 CA 路径
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v $(pwd)/stepca-root.crt:/stepca-root.crt \
  -e CA_PATH=/stepca-root.crt \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot
```

##### 方案D：创建自定义镜像
```bash
# 1. 创建 Dockerfile
cat > Dockerfile.acmesh << 'EOF'
FROM neilpang/acme.sh:latest
COPY stepca-root.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
EOF

# 2. 构建镜像
docker build -f Dockerfile.acmesh -t acmesh-with-ca .

# 3. 使用自定义镜像
docker run --rm -it \
  -v acme-data:/acme.sh \
  acmesh-with-ca \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot
```

##### 验证证书配置
```bash
# 检查 step-ca 证书
docker exec stepca step certificate inspect /home/step/certs/root_ca.crt

# 验证证书链
openssl verify -CAfile stepca-root.crt stepca-root.crt

# 测试 HTTPS 连接（不使用 -k）
curl --cacert stepca-root.crt https://localhost:9000/acme/acme/directory
```

#### 2. 证书验证失败

**错误信息：**
```
Verification failed
```

**解决方案：**
```bash
# 检查域名解析
nslookup example.com

# 检查 webroot 目录权限
ls -la /tmp/webroot/.well-known/acme-challenge/

# 检查防火墙设置
sudo ufw status
```

#### 3. 权限问题

**错误信息：**
```
Permission denied
```

**解决方案：**
```bash
# 检查数据卷权限
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  chown -R 1000:1000 /acme.sh
```

### 调试模式

启用调试模式获取详细信息：

```bash
# 启用调试模式
docker run --rm -it \
  -v acme-data:/acme.sh \
  -e DEBUG=1 \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot
```

### 日志查看

```bash
# 查看 acme.sh 日志
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  cat /acme.sh/acme.sh.log

# 查看 step-ca 日志
docker logs stepca
```

## 高级用法

### 1. 自动续期

设置定时任务自动续期证书：

```bash
# 创建续期脚本
cat > renew-certs.sh << 'EOF'
#!/bin/bash
docker run --rm \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --renew-all
EOF

chmod +x renew-certs.sh

# 添加到 crontab
echo "0 0 * * * /path/to/renew-certs.sh" | crontab -
```

### 2. 证书部署

#### 部署到 Nginx

```bash
# 申请证书并部署到 Nginx
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v /etc/nginx:/etc/nginx \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot \
  --deploy-hook nginx
```

#### 部署到 Apache

```bash
# 申请证书并部署到 Apache
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v /etc/apache2:/etc/apache2 \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot \
  --deploy-hook apache
```

### 3. 通配符证书

```bash
# 申请通配符证书（需要 DNS-01 验证）
docker run --rm -it \
  -v acme-data:/acme.sh \
  -e CF_Key="your-cloudflare-api-key" \
  -e CF_Email="your-email@example.com" \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d "*.example.com" \
  --dns dns_cf
```

### 4. ECC 证书

```bash
# 申请 ECC 证书
docker run --rm -it \
  -v acme-data:/acme.sh \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot \
  --keylength ec-256
```

### 5. 自定义钩子

创建自定义部署钩子：

```bash
# 创建自定义钩子脚本
cat > custom-deploy.sh << 'EOF'
#!/bin/bash
# 自定义部署脚本
echo "Deploying certificate for domain: $1"
# 在这里添加您的部署逻辑
EOF

chmod +x custom-deploy.sh

# 使用自定义钩子
docker run --rm -it \
  -v acme-data:/acme.sh \
  -v $(pwd)/custom-deploy.sh:/custom-deploy.sh \
  neilpang/acme.sh:latest \
  --issue \
  --server https://localhost:9000/acme/acme/directory \
  -d example.com \
  -w /tmp/webroot \
  --deploy-hook /custom-deploy.sh
```

## 总结

本手册涵盖了使用 acme.sh Docker 镜像测试 step-ca ACME 服务器的完整流程。通过遵循这些步骤，您可以：

1. 快速搭建测试环境
2. 申请和管理 SSL 证书
3. 配置自动续期
4. 部署证书到各种服务
5. 解决常见问题

如果您在使用过程中遇到问题，请参考故障排除部分或查看官方文档获取更多帮助。

## 相关链接

- [acme.sh 官方文档](https://github.com/acmesh-official/acme.sh/wiki)
- [step-ca 官方文档](https://smallstep.com/docs/step-ca/)
- [ACME 协议规范](https://tools.ietf.org/html/rfc8555)
- [Docker 官方文档](https://docs.docker.com/)

---

## 附录：代码分析

### _initAPI() 函数分析

`_initAPI()` 函数是 acme.sh 中用于初始化 ACME API 连接的核心函数，位于 `acme.sh` 文件的第 2760-2820 行。

#### 函数签名
```bash
_initAPI() {
  _api_server="${1:-$ACME_DIRECTORY}"
```

#### 核心功能
1. **重试机制**：最多重试 10 次，每次间隔 10 秒
2. **API 端点获取**：从 ACME 服务器获取必需的端点
3. **协议兼容性**：同时支持 ACME v1 和 v2 协议

#### 详细流程

##### 1. 重试循环
```bash
MAX_API_RETRY_TIMES=10
_sleep_retry_sec=10
_request_retry_times=0
while [ -z "$ACME_NEW_ACCOUNT" ] && [ "${_request_retry_times}" -lt "$MAX_API_RETRY_TIMES" ]; do
```

##### 2. HTTP 请求
```bash
response=$(_get "$_api_server" "" 10)
if [ "$?" != "0" ]; then
  _debug2 "response" "$response"
  _info "Cannot init API for: $_api_server."
  _info "Sleeping for $_sleep_retry_sec seconds and retrying."
  _sleep "$_sleep_retry_sec"
  continue
fi
```

##### 3. JSON 解析
```bash
response=$(echo "$response" | _json_decode)
```

##### 4. 端点提取
函数从响应中提取以下 ACME 协议端点：

| 端点 | 变量名 | 用途 |
|------|--------|------|
| `keyChange` | `ACME_KEY_CHANGE` | 账户密钥变更 |
| `newAuthz` | `ACME_NEW_AUTHZ` | 新授权（ACME v1） |
| `newOrder` | `ACME_NEW_ORDER` | 新订单（ACME v2） |
| `newAccount` | `ACME_NEW_ACCOUNT` | 新账户 |
| `revokeCert` | `ACME_REVOKE_CERT` | 证书撤销 |
| `newNonce` | `ACME_NEW_NONCE` | 新 Nonce |
| `termsOfService` | `ACME_AGREEMENT` | 服务条款 |

##### 5. 成功条件
```bash
if [ "$ACME_NEW_ACCOUNT" ] && [ "$ACME_NEW_ORDER" ]; then
  return 0
fi
```

必须同时获取到 `ACME_NEW_ACCOUNT` 和 `ACME_NEW_ORDER` 端点才认为成功。

### _get() 函数分析

`_get()` 函数是 acme.sh 中的 HTTP GET 请求实现，位于 `acme.sh` 文件的第 2069-2150 行。

#### 函数签名
```bash
_get() {
  _debug GET
  url="$1"
  onlyheader="$2"
  t="$3"
```

#### 参数说明
- `$1`: URL 地址
- `$2`: 是否只获取响应头（"onlyheader"）
- `$3`: 超时时间（秒）

#### 核心实现

##### 1. HTTP 客户端选择
函数优先使用 curl，如果没有则使用 wget：

```bash
if [ "$_ACME_CURL" ] && [ "${ACME_USE_WGET:-0}" = "0" ]; then
  # 使用 curl
elif [ "$_ACME_WGET" ]; then
  # 使用 wget
else
  _err "Neither curl nor wget have been found, cannot make GET request."
fi
```

##### 2. Curl 实现
```bash
_CURL="$_ACME_CURL"
if [ "$HTTPS_INSECURE" ]; then
  _CURL="$_CURL --insecure  "
fi
if [ "$t" ]; then
  _CURL="$_CURL --connect-timeout $t"
fi

if [ "$onlyheader" ]; then
  $_CURL -I --user-agent "$USER_AGENT" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$url"
else
  $_CURL --user-agent "$USER_AGENT" -H "$_H1" -H "$_H2" -H "$_H3" -H "$_H4" -H "$_H5" "$url"
fi
```

##### 3. Wget 实现
```bash
_WGET="$_ACME_WGET"
if [ "$HTTPS_INSECURE" ]; then
  _WGET="$_WGET --no-check-certificate "
fi
if [ "$t" ]; then
  _WGET="$_WGET --timeout=$t"
fi

if [ "$onlyheader" ]; then
  _wget_out="$($_WGET --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" -S -O /dev/null "$url" 2>&1)"
else
  $_WGET --user-agent="$USER_AGENT" --header "$_H5" --header "$_H4" --header "$_H3" --header "$_H2" --header "$_H1" -S -O - "$url" 2>"$HTTP_HEADER"
fi
```

#### 错误处理

##### Curl 错误
```bash
if [ "$ret" != "0" ]; then
  _err "Please refer to https://curl.haxx.se/libcurl/c/libcurl-errors.html for error code: $ret"
  if [ "$DEBUG" ] && [ "$DEBUG" -ge "2" ]; then
    _err "Here is the curl dump log:"
    _err "$(cat "$_CURL_DUMP")"
  fi
fi
```

##### Wget 错误
```bash
if [ "$ret" = "8" ]; then
  ret=0
  _debug "wget returned 8 as the server returned a 'Bad Request' response. Let's process the response later."
fi
if [ "$ret" != "0" ]; then
  _err "Please refer to https://www.gnu.org/software/wget/manual/html_node/Exit-Status.html for error code: $ret"
fi
```

### 问题诊断

#### 常见错误原因

1. **网络连接问题**
   - DNS 解析失败
   - 防火墙阻止连接
   - 代理配置问题

2. **服务器配置问题**
   - step-ca 未正确配置 ACME provisioner
   - 缺少必需的 ACME 端点
   - 证书验证失败

3. **协议兼容性问题**
   - ACME 版本不匹配
   - 响应格式不符合 RFC8555 标准

#### 调试方法

##### 1. 启用详细调试
```bash
docker run --rm -it \
  -v acme-data:/acme.sh \
  -e DEBUG=3 \
  neilpang/acme.sh:latest \
  --info \
  --server https://localhost:9000/acme/acme/directory
```

##### 2. 检查网络连接
```bash
# 测试基本连接
curl -k -v https://localhost:9000/acme/acme/directory

# 检查 DNS 解析
nslookup localhost

# 检查端口开放
netstat -tlnp | grep 9000
```

##### 3. 验证 ACME 目录
```bash
# 检查响应格式
curl -k https://localhost:9000/acme/acme/directory | jq .

# 验证必需字段
curl -k https://localhost:9000/acme/acme/directory | jq -r '.newAccount, .newOrder'
```

#### 解决方案

##### 1. 重新配置 step-ca
```bash
# 停止现有容器
docker stop stepca
docker rm stepca

# 重新启动并配置
docker run --rm -d \
  -p 9000:9000 \
  -e "DOCKER_STEPCA_INIT_NAME=Smallstep" \
  -e "DOCKER_STEPCA_INIT_DNS_NAMES=localhost,$(hostname -f)" \
  -e "DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT=true" \
  -e "DOCKER_STEPCA_INIT_PASSWORD=test" \
  --name stepca \
  smallstep/step-ca:latest

# 添加 ACME provisioner
sleep 10
docker exec stepca bash -c "echo test >test"
docker exec stepca step ca provisioner add acme --type ACME --admin-subject step --admin-password-file=/home/step/test
docker exec stepca kill -1 1
```

##### 2. 使用持久化配置
```bash
# 创建数据卷
docker volume create stepca-data

# 初始化配置
docker run --rm -it \
  -v stepca-data:/home/step \
  smallstep/step-ca:latest \
  step ca init \
  --name "Smallstep" \
  --dns "localhost,stepca.local" \
  --address ":9000" \
  --provisioner "acme@smallstep.com"

# 启动服务器
docker run --rm -d \
  -v stepca-data:/home/step \
  -p 9000:9000 \
  --name stepca \
  smallstep/step-ca:latest
```

### 总结

`_initAPI()` 和 `_get()` 函数是 acme.sh 与 ACME 服务器通信的基础。理解这些函数的实现有助于：

1. **问题诊断**：快速定位连接和配置问题
2. **调试优化**：使用正确的调试参数
3. **协议理解**：了解 ACME 协议的工作机制
4. **故障排除**：根据错误信息采取相应的解决措施

当遇到 "can not init api" 错误时，应该：
1. 检查网络连接
2. 验证 ACME 目录响应
3. 确认 step-ca 配置
4. 使用调试模式获取详细信息

## 相关链接

- [acme.sh 官方文档](https://github.com/acmesh-official/acme.sh/wiki)
- [step-ca 官方文档](https://smallstep.com/docs/step-ca/)
- [ACME 协议规范](https://tools.ietf.org/html/rfc8555)
- [Docker 官方文档](https://docs.docker.com/) 