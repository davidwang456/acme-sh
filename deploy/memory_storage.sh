#!/bin/bash

# ACME 内存存储部署脚本
# 用于 acme.sh 的 HTTP-1 验证
# 
# 参数:
#   $1: 域名
#   $2: 挑战令牌
#   $3: 挑战响应内容

set -e

# 配置
SERVER_URL="${ACME_SERVER_URL:-http://localhost:80}"
CHALLENGE_PATH="/.well-known/acme-challenge"
LOG_FILE="${ACME_LOG_FILE:-/tmp/acme-memory-storage.log}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 获取参数
domain="$1"
token="$2"
response="$3"

# 验证参数
if [ -z "$domain" ]; then
    log_error "域名参数缺失"
    exit 1
fi

if [ -z "$token" ]; then
    log_error "挑战令牌参数缺失"
    exit 1
fi

if [ -z "$response" ]; then
    log_error "挑战响应参数缺失"
    exit 1
fi

# 记录开始时间
start_time=$(date +%s)
log_info "开始处理 ACME 挑战: domain=$domain, token=$token"

# 检查服务是否可用
check_service() {
    if ! curl -s -f "${SERVER_URL}${CHALLENGE_PATH}/health" > /dev/null; then
        log_error "ACME 挑战服务不可用: ${SERVER_URL}"
        return 1
    fi
    return 0
}

# 添加挑战响应到内存
add_challenge_response() {
    local retry_count=0
    local max_retries=3
    local retry_delay=2
    
    while [ $retry_count -lt $max_retries ]; do
        log_info "尝试添加挑战响应 (尝试 $((retry_count + 1))/$max_retries)"
        
        # 发送 POST 请求添加挑战响应
        http_response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: text/plain" \
            -d "$response" \
            "${SERVER_URL}${CHALLENGE_PATH}/${token}")
        
        # 分离响应体和状态码
        http_body=$(echo "$http_response" | head -n -1)
        http_status=$(echo "$http_response" | tail -n 1)
        
        if [ "$http_status" = "200" ]; then
            log_success "挑战响应添加成功"
            return 0
        else
            log_warning "添加挑战响应失败，状态码: $http_status, 响应: $http_body"
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                log_info "等待 ${retry_delay} 秒后重试..."
                sleep $retry_delay
                retry_delay=$((retry_delay * 2))
            fi
        fi
    done
    
    log_error "添加挑战响应失败，已达到最大重试次数"
    return 1
}

# 验证挑战响应是否已添加
verify_challenge_response() {
    local retry_count=0
    local max_retries=5
    local retry_delay=1
    
    log_info "验证挑战响应是否已正确添加..."
    
    while [ $retry_count -lt $max_retries ]; do
        # 获取挑战响应
        actual_response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/${token}")
        
        if [ "$actual_response" = "$response" ]; then
            log_success "挑战响应验证成功"
            return 0
        else
            log_warning "挑战响应验证失败 (尝试 $((retry_count + 1))/$max_retries)"
            log_warning "期望: $response"
            log_warning "实际: $actual_response"
            
            retry_count=$((retry_count + 1))
            
            if [ $retry_count -lt $max_retries ]; then
                log_info "等待 ${retry_delay} 秒后重试验证..."
                sleep $retry_delay
            fi
        fi
    done
    
    log_error "挑战响应验证失败，已达到最大重试次数"
    return 1
}

# 获取挑战响应统计信息
get_challenge_stats() {
    log_info "获取挑战响应统计信息..."
    
    stats_response=$(curl -s "${SERVER_URL}${CHALLENGE_PATH}/debug/stats")
    
    if [ $? -eq 0 ]; then
        log_info "统计信息: $stats_response"
    else
        log_warning "无法获取统计信息"
    fi
}

# 主执行流程
main() {
    # 检查服务可用性
    if ! check_service; then
        exit 1
    fi
    
    # 添加挑战响应
    if ! add_challenge_response; then
        exit 1
    fi
    
    # 验证挑战响应
    if ! verify_challenge_response; then
        # 如果验证失败，尝试删除并重新添加
        log_warning "验证失败，尝试重新添加挑战响应..."
        curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/${token}" > /dev/null
        
        if ! add_challenge_response; then
            exit 1
        fi
        
        if ! verify_challenge_response; then
            exit 1
        fi
    fi
    
    # 获取统计信息
    get_challenge_stats
    
    # 计算执行时间
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log_success "ACME 挑战处理完成，耗时: ${duration} 秒"
    log_info "挑战响应已添加到内存存储: domain=$domain, token=$token"
    
    # 输出成功信息给 acme.sh
    echo "Challenge response added to memory storage for domain: $domain, token: $token"
}

# 清理函数
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "脚本执行失败，退出码: $exit_code"
        
        # 尝试清理可能部分添加的挑战响应
        log_info "尝试清理挑战响应..."
        curl -s -X DELETE "${SERVER_URL}${CHALLENGE_PATH}/${token}" > /dev/null
    fi
    
    exit $exit_code
}

# 设置信号处理
trap cleanup EXIT

# 执行主流程
main "$@" 