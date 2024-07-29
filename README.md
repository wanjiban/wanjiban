# fd
firewall-cmd 快捷执行一些命令

使用方法：
安装：'wget https://raw.githubusercontent.com/wanjiban/fd/main/fd.sh -O  /bin/fd && sudo chmod +x /bin/fd'

删除：rm -rf /bin/fd

使用：输入fd即可弹出菜单供选择。


# check_services.sh
服务快捷检查重启一些命令

使用方法：
安装：wget https://raw.githubusercontent.com/wanjiban/fd/main/check_services.sh -O /root/check_services.sh && sudo chmod +x /root/check_services.sh && (sudo crontab -l; echo "*/5 * * * * /root/check_services.sh") | sudo crontab -


删除：rm -rf /root/check_services.sh && (crontab -l | grep -v '/root/check_services.sh') | sudo crontab -

使用：输入fd即可弹出菜单供选择。
