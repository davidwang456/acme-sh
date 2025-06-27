#!/bin/bash

echo "=== ACME 证书申请测试环境启动脚本 ==="

# 检查 Docker 是否运行
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker"
    exit 1
fi

# 检查 Docker Compose 是否可用
if ! docker-compose --version >/dev/null 2>&1; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

echo "1. 启动 step-ca 服务器..."
docker-compose up -d stepca

echo "2. 等待 step-ca 启动..."
sleep 10

echo "3. 配置 step-ca ACME provisioner..."
docker exec stepca bash -c "echo test >test"
docker exec stepca step ca provisioner add acme --type ACME --admin-subject step --admin-password-file=/home/step/test
docker exec stepca kill -1 1

echo "4. 获取 step-ca 根证书..."
docker exec stepca cat /home/step/certs/root_ca.crt > stepca-root.crt

echo "5. 启动 Spring Boot ACME 挑战服务器..."
docker-compose up -d acme-challenge-server

echo "6. 等待 Spring Boot 应用启动..."
sleep 15

echo "7. 验证服务状态..."

# 检查 step-ca
if curl -k -s https://localhost:9000/acme/acme/directory | grep -q "newNonce"; then
    echo "✅ step-ca 服务器运行正常"
else
    echo "❌ step-ca 服务器异常"
    exit 1
fi

# 检查 Spring Boot 应用
if curl -s http://localhost:80/test | grep -q "success"; then
    echo "✅ Spring Boot ACME 挑战服务器运行正常"
else
    echo "❌ Spring Boot 应用异常"
    exit 1
fi

# 检查 ACME 挑战端点
if curl -s http://localhost:80/.well-known/acme-challenge/health | grep -q "running"; then
    echo "✅ ACME 挑战端点正常"
else
    echo "❌ ACME 挑战端点异常"
    exit 1
fi

echo "8. 启动 acme.sh 客户端..."
docker-compose up -d acmesh

echo "9. 等待所有服务就绪..."
sleep 5

echo "=== 环境启动完成 ==="
echo ""
echo "🌐 服务地址："
echo "   - step-ca: https://localhost:9000"
echo "   - ACME 挑战服务器: http://localhost:80"
echo "   - 测试端点: http://localhost:80/test"
echo ""
echo "📋 下一步操作："
echo "   1. 测试 ACME 挑战: curl http://localhost:80/.well-known/acme-challenge/test-token"
echo "   2. 申请证书: docker exec acmesh acme.sh --issue --server https://stepca:9000/acme/acme/directory -d example.com -w /tmp/webroot"
echo "   3. 查看日志: docker-compose logs -f"
echo ""
echo "🔧 管理命令："
echo "   - 停止服务: docker-compose down"
echo "   - 查看状态: docker-compose ps"
echo "   - 查看日志: docker-compose logs [service-name]" 