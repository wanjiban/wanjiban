#!/bin/bash

# 定义变量
FIREWALL_ZONE="public"
TRUST_ZONE="trusted"
ICMP_BLOCK="echo-request" # 默认ping设置

# 函数：显示菜单
show_menu() {
    echo "请选择操作选项:"
    echo "1: 显示关键区域情况"
    echo "2: 重启firewall-cmd"
    echo "3: 增加或删除端口"
    echo "4: 设置ping"
    echo "5: 将接口添加到trust区域"
    echo "6: 防火墙允许或阻止SSH"
    echo "7: 管理阻止的IP或网段"
    echo "8: 保存配置并重启防火墙"
    echo "9: 安装firewalld"
    echo "q: 退出"
}

# 函数：重启firewall-cmd
restart_firewalld() {
    echo "重启firewalld..."
    systemctl restart firewalld
}

# 函数：显示关键区域情况
list_all_zones() {
    echo "显示trust区域情况..."
    firewall-cmd --zone=trusted --list-all
    echo "显示public区域情况..."
    firewall-cmd --zone=public --list-all
}

# 函数：增加端口
add_ports() {
    echo "输入要增加的端口 (多个端口用空格隔开): "
    read -a ports
    echo "当前已开放的端口:"
    firewall-cmd --zone=$FIREWALL_ZONE --list-ports
    for port in "${ports[@]}"; do
        firewall-cmd --zone=$FIREWALL_ZONE --add-port=${port}/tcp --permanent
    done
    firewall-cmd --reload
    echo "新增端口:"
    firewall-cmd --zone=$FIREWALL_ZONE --list-ports
}

# 函数：删除端口
remove_ports() {
    echo "输入要删除的端口 (多个端口用空格隔开): "
    read -a ports
    echo "当前已开放的端口:"
    firewall-cmd --zone=$FIREWALL_ZONE --list-ports
    for port in "${ports[@]}"; do
        firewall-cmd --zone=$FIREWALL_ZONE --remove-port=${port}/tcp --permanent
    done
    firewall-cmd --reload
    echo "删除后的端口:"
    firewall-cmd --zone=$FIREWALL_ZONE --list-ports
}

# 函数：设置ping
set_ping() {
    echo "输入0关闭ping，1允许ping: "
    read ping_option
    if [ "$ping_option" -eq 0 ]; then
        firewall-cmd --add-icmp-block=$ICMP_BLOCK --permanent
    elif [ "$ping_option" -eq 1 ]; then
        firewall-cmd --remove-icmp-block=$ICMP_BLOCK --permanent
    else
        echo "无效的选项"
        return
    fi
    firewall-cmd --reload
    echo "ping开启情况:"
    firewall-cmd --list-icmp-blocks
}

# 函数：将接口添加到trust区域
manage_trust_zone() {
    echo "输入接口名 (例如: eth0) 和操作 (add 或 remove): "
    read -p "接口名: " iface
    read -p "操作 (add 或 remove): " action
    if [ "$action" == "add" ]; then
        firewall-cmd --zone=$TRUST_ZONE --add-interface=$iface --permanent
    elif [ "$action" == "remove" ]; then
        firewall-cmd --zone=$TRUST_ZONE --remove-interface=$iface --permanent
    else
        echo "无效的操作"
        return
    fi
    firewall-cmd --reload
    echo "trust区域接口情况:"
    firewall-cmd --zone=$TRUST_ZONE --list-interfaces
}

# 函数：防火墙允许或阻止SSH
manage_ssh() {
    echo "输入0阻止SSH，1允许SSH: "
    read ssh_option
    if [ "$ssh_option" -eq 0 ]; then
        firewall-cmd --permanent --remove-service=ssh
    elif [ "$ssh_option" -eq 1 ]; then
        firewall-cmd --permanent --add-service=ssh
    else
        echo "无效的选项"
        return
    fi
    firewall-cmd --reload
    echo "SSH状态:"
    firewall-cmd --list-services
}

# 函数：管理阻止的IP或网段
manage_blocked_ips() {
    echo "输入1查看阻止的IP或网段，2添加IP或网段，3删除IP或网段: "
    read manage_option
    case $manage_option in
        1)
            echo "当前阻止的IP或网段:"
            firewall-cmd --list-rich-rules | grep 'reject'
            ;;
        2)
            echo "输入要添加的IP或网段 (例如: 192.168.1.100/32): "
            read ip_to_add
            firewall-cmd --add-rich-rule="rule family='ipv4' source address='$ip_to_add' reject" --permanent
            firewall-cmd --reload
            ;;
        3)
            echo "输入要删除的IP或网段 (例如: 192.168.1.100/32): "
            read ip_to_remove
            firewall-cmd --remove-rich-rule="rule family='ipv4' source address='$ip_to_remove' reject" --permanent
            firewall-cmd --reload
            ;;
        *)
            echo "无效的选项"
            ;;
    esac
}

# 函数：保存配置并重启防火墙
save_and_reload() {
    echo "保存当前配置并重启防火墙..."
    firewall-cmd --runtime-to-permanent
    firewall-cmd --reload
    firewall-cmd --complete-reload
    echo "当前防火墙配置:"
    firewall-cmd --list-all-zones
}

# 函数：安装firewalld
install_firewalld() {
    echo "安装firewalld..."
    yum install -y epel-release firewalld
    systemctl enable firewalld
    systemctl restart firewalld
    firewall-cmd --reload
}

# 函数：根据参数执行操作
execute_command() {
    case $1 in
        restart)
            restart_firewalld
            ;;
        list)
            list_all_zones
            ;;
        add_ports)
            add_ports
            ;;
        remove_ports)
            remove_ports
            ;;
        set_ping)
            set_ping
            ;;
        manage_trust)
            manage_trust_zone
            ;;
        manage_ssh)
            manage_ssh
            ;;
        manage_blocked_ips)
            manage_blocked_ips
            ;;
        save_and_reload)
            save_and_reload
            ;;
        install)
            install_firewalld
            ;;
        *)
            echo "无效的命令"
            echo "有效命令: restart, list, add_ports, remove_ports, set_ping, manage_trust, manage_ssh, manage_blocked_ips, save_and_reload, install"
            ;;
    esac
}

# 主程序逻辑
if [ $# -eq 0 ]; then
    echo "没有提供命令行参数，进入交互模式..."
    while true; do
        show_menu
        read -p "请输入选项 (1-9): " option

        if [ -z "$option" ]; then
            echo "退出..."
            exit 0
        fi

        case $option in
            1)
                list_all_zones
                ;;
            2)
                restart_firewalld
                ;;
            3)
                echo "输入操作 (a)dd 或 (r)emove: "
                read operation
                if [ "$operation" == "a" || "$operation" == "add" ]; then
                    add_ports
                elif [ "$operation" == "r" || "$operation" == "remove"]; then
                    remove_ports
                else
                    echo "无效的操作"
                fi
                ;;
            4)
                set_ping
                ;;
            5)
                manage_trust_zone
                ;;
            6)
                manage_ssh
                ;;
            7)
                manage_blocked_ips
                ;;
            8)
                save_and_reload
                ;;
            9)
                install_firewalld
                ;;
            *)
                echo "无效的选项"
                ;;
        esac
    done
else
    execute_command "$1"
fi
