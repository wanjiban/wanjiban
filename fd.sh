#!/bin/bash

# 显示菜单选项函数
show_menu() {
    echo "请选择操作:"
    echo "  1. 重启 firewalld"
    echo "  2. 显示有变动的区域情况"
    echo "  3. 增加端口"
    echo "  4. 控制 ping 设置"
    echo "  5. 将接口添加或删除到 trust 区域"
    echo "  6. 允许/阻止 SSH"
    echo "  9. 安装 firewall-cmd"
    echo "  q. 退出"
}

# 重启 firewalld 函数
restart_firewalld() {
    echo "重启 firewalld..."
    systemctl restart firewalld
}

# 显示有变动的区域情况函数
show_changed_zones() {
    echo "显示有变动的区域情况:"

    # 列出所有区域的详细设置，并仅显示有变动的区域
    firewall-cmd --list-all-zones --permanent | awk '/^[\[]/ { zone=$1 } /^ / && NF==2 && $1 != $2 { print zone; next }'

    if [ $? -ne 0 ]; then
        echo "未发现有变动的区域."
    fi
}

# 增加端口函数
add_ports() {
    echo "当前开放端口："
    firewall-cmd --zone=public --list-ports

    read -p "请输入要增加的端口号（以空格分隔）: " ports

    for port in $ports; do
        firewall-cmd --zone=public --add-port=$port/tcp --permanent
    done

    firewall-cmd --reload

    echo "成功增加端口后的开放端口："
    firewall-cmd --zone=public --list-ports
}

# 控制 ping 设置函数
control_ping() {
    read -p "输入 0 关闭 ping，输入 1 允许 ping: " option

    case "$option" in
        0)
            echo "关闭 ping..."
            firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" protocol="icmp" icmp-type="echo-request" drop'
            ;;
        1)
            echo "允许 ping..."
            firewall-cmd --zone=public --remove-rich-rule='rule family="ipv4" protocol="icmp" icmp-type="echo-request" drop'
            ;;
        *)
            echo "无效的选项."
            return 1
            ;;
    esac

    firewall-cmd --reload

    # 检查 ping 开启情况
    echo "当前 ping 设置："
    firewall-cmd --zone=public --list-all | grep icmp-block
}

# 将接口添加或删除到 trust 区域函数
toggle_trust_interface() {
    read -p "输入要添加或删除的接口名 (例如 eth0): " interface
    read -p "输入 0 删除接口，输入 1 添加接口: " option

    case "$option" in
        0)
            echo "删除接口 $interface 从 trust 区域..."
            firewall-cmd --zone=trust --remove-interface=$interface --permanent
            ;;
        1)
            echo "添加接口 $interface 到 trust 区域..."
            firewall-cmd --zone=trust --add-interface=$interface --permanent
            ;;
        *)
            echo "无效的选项."
            return 1
            ;;
    esac

    firewall-cmd --reload

    echo "trust 区域接口情况："
    firewall-cmd --zone=trust --list-interfaces
}

# 允许/阻止 SSH 函数
toggle_ssh() {
    read -p "输入 0 阻止 SSH，输入 1 允许 SSH: " option

    case "$option" in
        0)
            echo "阻止 SSH..."
            firewall-cmd --permanent --remove-service=ssh
            ;;
        1)
            echo "允许 SSH..."
            firewall-cmd --permanent --add-service=ssh
            ;;
        *)
            echo "无效的选项."
            return 1
            ;;
    esac

    firewall-cmd --reload

    echo "当前 SSH 设置："
    firewall-cmd --zone=public --list-services | grep ssh
}

# 安装 firewall-cmd 函数
install_firewalld() {
    echo "安装 firewall-cmd..."
    yum install -y epel-release firewalld
    systemctl enable firewalld
    systemctl restart firewalld
    firewall-cmd --reload
}

# 主程序
echo "输入 'fd' 启动选项菜单，或输入 'q' 退出程序."

while true; do
    show_menu  # 显示菜单
    read -p "请输入选项: " choice

    case "$choice" in
        1)
            restart_firewalld  # 重启 firewalld
            ;;
        2)
            show_changed_zones  # 显示有变动的区域情况
            ;;
        3)
            add_ports  # 增加端口
            ;;
        4)
            control_ping  # 控制 ping 设置
            ;;
        5)
            toggle_trust_interface  # 将接口添加或删除到 trust 区域
            ;;
        6)
            toggle_ssh  # 允许/阻止 SSH
            ;;
        9)
            install_firewalld  # 安装 firewall-cmd
            ;;
        q)
            echo "退出程序."
            exit 0
            ;;
        *)
            echo "无效的选项."
            ;;
    esac
done
