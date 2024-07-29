#!/bin/bash

# 脚本路径
SCRIPT_PATH="/usr/local/bin/fd"

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以 root 用户身份运行。"
   exit 1
fi

# 菜单函数
show_menu() {
    echo "选择操作："
    echo "1) 重启 firewalld"
    echo "2) 显示全部区域情况"
    echo "3) 增加端口"
    echo "4) 允许/禁止 ping"
    echo "5) 添加/删除接口到 trust 区域"
    echo "6) 允许/阻止 SSH"
    echo "7) 列出/管理阻止的 IP 或网段"
    echo "8) 保存配置并完整重启防火墙"
    echo "9) 安装 firewalld"
    echo "0) 退出"
}

# 处理用户选择
handle_selection() {
    local choice
    read -p "请输入选项: " choice
    case $choice in
        1)
            echo "重启 firewalld..."
            systemctl restart firewalld
            ;;
        2)
            echo "显示全部区域情况..."
            firewall-cmd --list-all-zones --permanent
            ;;
        3)
            echo "增加端口..."
            read -p "请输入要增加的端口（用空格隔开多个端口）: " ports
            firewall-cmd --zone=public --list-ports
            for port in $ports; do
                firewall-cmd --zone=public --add-port=$port/tcp --permanent
            done
            firewall-cmd --reload
            firewall-cmd --zone=public --list-ports
            ;;
        4)
            echo "设置 ping 状态..."
            read -p "输入 0 关闭 ping，输入 1 允许 ping: " ping_status
            if [[ $ping_status -eq 0 ]]; then
                firewall-cmd --zone=public --remove-icmp-block=echo-request --permanent
            elif [[ $ping_status -eq 1 ]]; then
                firewall-cmd --zone=public --add-icmp-block=echo-request --permanent
            else
                echo "无效的输入。"
                exit 1
            fi
            firewall-cmd --reload
            firewall-cmd --info-zone=public
            ;;
        5)
            echo "添加/删除接口到 trust 区域..."
            read -p "输入接口名（例如 eth0）: " iface
            read -p "输入 1 添加接口到 trust 区域，输入 0 从 trust 区域移除接口: " action
            if [[ $action -eq 1 ]]; then
                firewall-cmd --zone=trusted --add-interface=$iface --permanent
            elif [[ $action -eq 0 ]]; then
                firewall-cmd --zone=trusted --remove-interface=$iface --permanent
            else
                echo "无效的输入。"
                exit 1
            fi
            firewall-cmd --reload
            firewall-cmd --zone=trusted --list-interfaces
            ;;
        6)
            echo "允许/阻止 SSH..."
            read -p "输入 1 允许 SSH，输入 0 阻止 SSH: " ssh_status
            if [[ $ssh_status -eq 1 ]]; then
                firewall-cmd --permanent --add-service=ssh
            elif [[ $ssh_status -eq 0 ]]; then
                firewall-cmd --permanent --remove-service=ssh
            else
                echo "无效的输入。"
                exit 1
            fi
            firewall-cmd --reload
            firewall-cmd --list-services
            ;;
        7)
            echo "管理阻止的 IP 或网段..."
            echo "1) 列出阻止的 IP 或网段"
            echo "2) 添加阻止 IP 或网段"
            echo "3) 删除阻止 IP 或网段"
            read -p "请输入选项: " manage_choice
            case $manage_choice in
                1)
                    echo "列出阻止的 IP 或网段..."
                    firewall-cmd --get-rich-rules
                    ;;
                2)
                    read -p "输入要阻止的 IP 或网段: " block_ip
                    firewall-cmd --add-rich-rule="rule family='ipv4' source address='$block_ip' drop" --permanent
                    firewall-cmd --reload
                    ;;
                3)
                    read -p "输入要删除的阻止 IP 或网段: " unblock_ip
                    firewall-cmd --remove-rich-rule="rule family='ipv4' source address='$unblock_ip' drop" --permanent
                    firewall-cmd --reload
                    ;;
                *)
                    echo "无效的输入。"
                    exit 1
                    ;;
            esac
            ;;
        8)
            echo "保存配置并完整重启防火墙..."
            firewall-cmd --runtime-to-permanent
            firewall-cmd --reload
            firewall-cmd --complete-reload
            firewall-cmd --list-all-zones
            ;;
        9)
            echo "安装 firewalld..."
            yum install -y epel-release firewalld
            systemctl enable firewalld
            systemctl restart firewalld
            firewall-cmd --reload
            ;;
        0)
            echo "退出..."
            exit 0
            ;;
        *)
            echo "无效的选项。"
            ;;
    esac
}

# 创建脚本文件并写入内容
echo "#!/bin/bash" > $SCRIPT_PATH
cat << 'EOF' >> $SCRIPT_PATH
show_menu
while true; do
    handle_selection
    show_menu
done
EOF

# 赋予脚本执行权限
chmod +x $SCRIPT_PATH

echo "脚本已安装到 $SCRIPT_PATH。"
