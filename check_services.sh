#!/bin/bash

# 日志文件路径
LOGFILE="/var/log/service_status_check.log"

# 函数：记录带时间戳的消息
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOGFILE
}

# 检查脚本是否以 root 用户身份运行
if [[ $EUID -ne 0 ]]; then
   log_message "此脚本必须以 root 用户身份运行。"
   exit 1
fi

log_message "开始服务状态检查。"

# 检查 NGINX 状态
log_message "检查 NGINX 状态..."
STATUS_OUTPUT=$(service nginx status 2>&1)
log_message "NGINX 状态输出: $STATUS_OUTPUT"
if echo "$STATUS_OUTPUT" | grep -q "is running"; then
    log_message "NGINX 正在运行。"
else
    log_message "NGINX 未运行。正在重启..."
    RESTART_OUTPUT=$(service nginx restart 2>&1)
    log_message "NGINX 重启输出: $RESTART_OUTPUT"
    if service nginx status | grep -q "is running"; then
        log_message "NGINX 成功重启。"
    else
        log_message "NGINX 重启失败。"
    fi
fi

# 检查 x-ui 状态
log_message "检查 x-ui 状态..."
XUI_STATUS_OUTPUT=$(service x-ui status 2>&1)
log_message "x-ui 状态输出: $XUI_STATUS_OUTPUT"
if echo "$XUI_STATUS_OUTPUT" | grep -q "active (running)"; then
    log_message "x-ui 正在运行。"
else
    log_message "x-ui 未运行。正在重启..."
    XUI_RESTART_OUTPUT=$(service x-ui restart 2>&1)
    log_message "x-ui 重启输出: $XUI_RESTART_OUTPUT"
    if service x-ui status | grep -q "active (running)"; then
        log_message "x-ui 成功重启。"
    else
        log_message "x-ui 重启失败。"
    fi
fi

# 检查 firewalld 状态
log_message "检查 firewalld 状态..."
FIREWALLD_STATUS_OUTPUT=$(service firewalld status 2>&1)
log_message "firewalld 状态输出: $FIREWALLD_STATUS_OUTPUT"
if echo "$FIREWALLD_STATUS_OUTPUT" | grep -q "active (running)"; then
    log_message "firewalld 正在运行。"
else
    log_message "firewalld 未运行。正在重启..."
    FIREWALLD_RESTART_OUTPUT=$(service firewalld restart 2>&1)
    log_message "firewalld 重启输出: $FIREWALLD_RESTART_OUTPUT"
    if service firewalld status | grep -q "active (running)"; then
        log_message "firewalld 成功重启。"
    else
        log_message "firewalld 重启失败。"
    fi
fi

log_message "服务状态检查完成。"
