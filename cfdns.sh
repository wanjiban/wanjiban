#!/bin/bash

# CloudFlare API Token
CF_TOKEN="CloudFlare API Token"

# CloudFlare Zone ID
CF_ZONE_ID="CloudFlare Zone ID"

# CloudFlare API URL
CF_API_URL="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records"

# 检查是否安装了 curl 和 jq
if ! command -v curl &> /dev/null; then
    echo "curl 命令未找到。请安装 curl。"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq 命令未找到。请安装 jq。"
    exit 1
fi

# 列出 DNS 记录
list_dns_records() {
    echo "获取 DNS 记录中..."
    curl -s -X GET "$CF_API_URL" \
         -H "Authorization: Bearer $CF_TOKEN" \
         -H "Content-Type: application/json" | jq '.result[] | {id, name, type, content, ttl}'
}

# 更新或创建 DNS 记录
update_dns_record() {
    local domain="$1"   # 域名
    local new_ip="$2"   # 新的 IP 地址
    local record_type="$3"  # 记录类型（A、CNAME、AAAA）
    
    # 默认 TTL 值
    local ttl="1"

    # 查询指定域名的记录 ID
    record_id=$(curl -s -X GET "$CF_API_URL?name=$domain" \
                  -H "Authorization: Bearer $CF_TOKEN" \
                  -H "Content-Type: application/json" | \
                  jq -r '.result[] | select(.name=="'$domain'" and .type=="'$record_type'") | .id')

    if [ -z "$record_id" ]; then
        echo "未找到 $domain 的 DNS 记录。正在创建新记录..."
        # 创建新的 DNS 记录
        curl -s -X POST "$CF_API_URL" \
             -H "Authorization: Bearer $CF_TOKEN" \
             -H "Content-Type: application/json" \
             --data "{\"type\":\"$record_type\",\"name\":\"$domain\",\"content\":\"$new_ip\",\"ttl\":$ttl}" \
             | jq '.'
        echo "DNS 记录 $domain 创建成功，IP 地址为 $new_ip。"
    else
        # 获取之前的 IP 地址
        previous_ip=$(curl -s -X GET "$CF_API_URL/$record_id" \
                        -H "Authorization: Bearer $CF_TOKEN" \
                        -H "Content-Type: application/json" | \
                        jq -r '.result.content')
                        
        echo "更新 $domain 的 DNS 记录，之前的 IP 地址为 $previous_ip，新的 IP 地址为 $new_ip..."
        # 更新现有 DNS 记录
        curl -s -X PUT "$CF_API_URL/$record_id" \
             -H "Authorization: Bearer $CF_TOKEN" \
             -H "Content-Type: application/json" \
             --data "{\"type\":\"$record_type\",\"name\":\"$domain\",\"content\":\"$new_ip\",\"ttl\":$ttl}" \
             | jq '.'
        echo "DNS 记录 $domain 更新成功，从 $previous_ip 改为 $new_ip。"
    fi
}

# 删除 DNS 记录
delete_dns_record() {
    local domain="$1"   # 域名
    
    # 查询指定域名的记录 ID 和详细信息
    record_info=$(curl -s -X GET "$CF_API_URL?name=$domain" \
                    -H "Authorization: Bearer $CF_TOKEN" \
                    -H "Content-Type: application/json")
    
    record_id=$(echo "$record_info" | jq -r '.result[] | select(.name=="'$domain'") | .id')
    record_content=$(echo "$record_info" | jq -r '.result[] | select(.name=="'$domain'") | .content')
    record_type=$(echo "$record_info" | jq -r '.result[] | select(.name=="'$domain'") | .type')
    
    if [ -z "$record_id" ]; then
        echo "未找到 $domain 的 DNS 记录。"
        exit 1
    fi

    echo "删除记录前信息："
    echo "域名: $domain"
    echo "记录类型: $record_type"
    echo "记录内容: $record_content"

    echo "正在删除 $domain 的 DNS 记录..."
    # 删除 DNS 记录
    curl -s -X DELETE "$CF_API_URL/$record_id" \
         -H "Authorization: Bearer $CF_TOKEN" \
         -H "Content-Type: application/json" \
         | jq '.'
    echo "DNS 记录 $domain 删除成功。"
}

# 主脚本逻辑
case "$1" in
    list)
        list_dns_records
        ;;
    update)
        if [ "$#" -ne 4 ]; then
            echo "用法: $0 update <域名> <IP> <记录类型>"
            exit 1
        fi
        update_dns_record "$2" "$3" "$4"
        ;;
    delete)
        if [ "$#" -ne 2 ]; then
            echo "用法: $0 delete <域名>"
            exit 1
        fi
        delete_dns_record "$2"
        ;;
    *)
        echo "用法: $0 {list|update <域名> <IP> <记录类型>|delete <域名>}"
        exit 1
        ;;
esac
