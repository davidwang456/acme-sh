#!/bin/bash

# ACME 内存存储挑战控制器测试脚本
# 测试 Spring Boot 应用的 HTTP-01 挑战验证功能

set -e

# 配置
SERVER_URL="http://localhost:80"
CHALLENGE_PATH="/.well-known/acme-challenge"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查服务是否运行
check_service() {
    log_info "检查 ACME 挑战服务状态..."
    
    if curl -s -f "${SERVER_URL}${CHALLENGE_PATH}/health" > /dev/null; then
        log_success "服务运行正常"
        return 0
    else
        log_error "服务未运行或无法访问"
        return 1
    fi
}

# 获取服务健康状态
get_health_status() {
    log_info "获取服务健康状态..."
    
    response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/health")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# 添加挑战响应
add_challenge() {
    local token="$1"
    local response="$2"
    
    log_info "添加挑战响应: token=$token"
    
    curl -s -X POST \
        -H "Content-Type: text/plain" \
        -d "$response" \
        "${SERVER_URL}${CHALLENGE_PATH}/${token}"
    
    echo
}

# 验证挑战响应
verify_challenge() {
    local token="$1"
    local expected_response="$2"
    
    log_info "验证挑战响应: token=$token"
    
    actual_response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/${token}")
    
    if [ "$actual_response" = "$expected_response" ]; then
        log_success "挑战验证成功"
        echo "期望: $expected_response"
        echo "实际: $actual_response"
    else
        log_error "挑战验证失败"
        echo "期望: $expected_response"
        echo "实际: $actual_response"
        return 1
    fi
}

# 批量添加挑战响应
add_batch_challenges() {
    log_info "批量添加挑战响应..."
    
    # 创建测试数据
    cat > /tmp/challenges.json << EOF
{
    "test-token-1": "test-token-1.test-response-1",
    "test-token-2": "test-token-2.test-response-2",
    "test-token-3": "test-token-3.test-response-3"
}
EOF
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/challenges.json \
        "${SERVER_URL}${CHALLENGE_PATH}/batch"
    
    echo
}

# 获取统计信息
get_stats() {
    log_info "获取挑战响应统计信息..."
    
    response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/debug/stats")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# 获取所有挑战响应
get_all_challenges() {
    log_info "获取所有挑战响应..."
    
    response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/debug/all")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# 删除挑战响应
delete_challenge() {
    local token="$1"
    
    log_info "删除挑战响应: token=$token"
    
    curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/${token}"
    echo
}

# 清空所有挑战响应
clear_all_challenges() {
    log_info "清空所有挑战响应..."
    
    curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/clear"
    echo
}

# 模拟真实的 ACME 挑战流程
simulate_acme_flow() {
    log_info "模拟真实的 ACME 挑战流程..."
    
    # 1. 生成测试 token 和 response
    local token="acme-challenge-$(date +%s)"
    local response="${token}.test-response-$(date +%s)"
    
    log_info "生成测试数据:"
    echo "  Token: $token"
    echo "  Response: $response"
    
    # 2. 添加挑战响应
    add_challenge "$token" "$response"
    
    # 3. 验证挑战响应
    verify_challenge "$token" "$response"
    
    # 4. 等待一段时间（模拟验证过程）
    log_info "等待 2 秒模拟验证过程..."
    sleep 2
    
    # 5. 再次验证（确保响应仍然可用）
    verify_challenge "$token" "$response"
    
    # 6. 删除挑战响应（模拟验证完成后的清理）
    delete_challenge "$token"
    
    log_success "ACME 挑战流程模拟完成"
}

# 主测试流程
main() {
    echo "=========================================="
    echo "ACME 内存存储挑战控制器测试"
    echo "=========================================="
    
    # 检查服务状态
    if ! check_service; then
        log_error "请先启动 Spring Boot 应用"
        exit 1
    fi
    
    echo
    
    # 获取健康状态
    get_health_status
    echo
    
    # 清空现有挑战响应
    clear_all_challenges
    echo
    
    # 测试单个挑战响应
    log_info "=== 测试单个挑战响应 ==="
    add_challenge "test-token-001" "test-token-001.test-response-001"
    verify_challenge "test-token-001" "test-token-001.test-response-001"
    echo
    
    # 测试批量添加
    log_info "=== 测试批量添加挑战响应 ==="
    add_batch_challenges
    echo
    
    # 验证批量添加的结果
    verify_challenge "test-token-1" "test-token-1.test-response-1"
    verify_challenge "test-token-2" "test-token-2.test-response-2"
    verify_challenge "test-token-3" "test-token-3.test-response-3"
    echo
    
    # 获取统计信息
    log_info "=== 获取统计信息 ==="
    get_stats
    echo
    
    # 获取所有挑战响应
    log_info "=== 获取所有挑战响应 ==="
    get_all_challenges
    echo
    
    # 模拟真实 ACME 流程
    log_info "=== 模拟真实 ACME 挑战流程 ==="
    simulate_acme_flow
    echo
    
    # 最终统计
    log_info "=== 最终统计 ==="
    get_stats
    echo
    
    log_success "所有测试完成！"
}

# 帮助信息
show_help() {
    echo "ACME 内存存储挑战控制器测试脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  --health       检查服务健康状态"
    echo "  --stats        获取统计信息"
    echo "  --all          获取所有挑战响应"
    echo "  --clear        清空所有挑战响应"
    echo "  --simulate     模拟 ACME 挑战流程"
    echo
    echo "示例:"
    echo "  $0             运行完整测试"
    echo "  $0 --health    检查服务状态"
    echo "  $0 --simulate  模拟挑战流程"
}

# 解析命令行参数
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --health)
        check_service && get_health_status
        exit 0
        ;;
    --stats)
        check_service && get_stats
        exit 0
        ;;
    --all)
        check_service && get_all_challenges
        exit 0
        ;;
    --clear)
        check_service && clear_all_challenges
        exit 0
        ;;
    --simulate)
        check_service && simulate_acme_flow
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac 