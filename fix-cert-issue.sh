#!/bin/bash

echo "=== 解决 acme.sh 证书验证问题 ==="

# 检查 step-ca 容器是否运行
if ! docker ps | grep -q stepca; then
    echo "❌ step-ca 容器未运行，请先启动 step-ca"
    exit 1
fi

echo "1. 获取 step-ca 根证书..."
docker exec stepca cat /home/step/certs/root_ca.crt > stepca-root.crt

if [ ! -f stepca-root.crt ]; then
    echo "❌ 无法获取 step-ca 根证书"
    exit 1
fi

echo "✅ 根证书已保存到 stepca-root.crt"

echo "2. 验证证书有效性..."
if openssl verify -CAfile stepca-root.crt stepca-root.crt >/dev/null 2>&1; then
    echo "✅ 证书验证通过"
else
    echo "⚠️  证书验证失败，但继续执行"
fi

echo "3. 测试 HTTPS 连接..."
if curl --cacert stepca-root.crt -s https://localhost:9000/acme/acme/directory | grep -q "newNonce"; then
    echo "✅ HTTPS 连接正常"
else
    echo "⚠️  HTTPS 连接失败，将使用 --insecure 模式"
fi

echo "4. 选择解决方案："
echo "A) 使用 --insecure 模式（快速测试）"
echo "B) 添加根证书到容器（推荐）"
echo "C) 使用 CA_PATH 环境变量"
echo "D) 创建自定义镜像"

read -p "请选择方案 (A/B/C/D): " choice

case $choice in
    A|a)
        echo "使用 --insecure 模式..."
        docker run --rm -it \
          -v acme-data:/acme.sh \
          -e HTTPS_INSECURE=1 \
          neilpang/acme.sh:latest \
          --issue \
          --server https://localhost:9000/acme/acme/directory \
          -d example.com \
          -w /tmp/webroot
        ;;
    B|b)
        echo "添加根证书到容器..."
        docker run --rm -it \
          -v acme-data:/acme.sh \
          -v $(pwd)/stepca-root.crt:/stepca-root.crt \
          neilpang/acme.sh:latest \
          sh -c "cp /stepca-root.crt /usr/local/share/ca-certificates/ && update-ca-certificates && acme.sh --issue --server https://localhost:9000/acme/acme/directory -d example.com -w /tmp/webroot"
        ;;
    C|c)
        echo "使用 CA_PATH 环境变量..."
        docker run --rm -it \
          -v acme-data:/acme.sh \
          -v $(pwd)/stepca-root.crt:/stepca-root.crt \
          -e CA_PATH=/stepca-root.crt \
          neilpang/acme.sh:latest \
          --issue \
          --server https://localhost:9000/acme/acme/directory \
          -d example.com \
          -w /tmp/webroot
        ;;
    D|d)
        echo "创建自定义镜像..."
        cat > Dockerfile.acmesh << 'EOF'
FROM neilpang/acme.sh:latest
COPY stepca-root.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
EOF
        docker build -f Dockerfile.acmesh -t acmesh-with-ca .
        docker run --rm -it \
          -v acme-data:/acme.sh \
          acmesh-with-ca \
          --issue \
          --server https://localhost:9000/acme/acme/directory \
          -d example.com \
          -w /tmp/webroot
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo "=== 完成 ===" 