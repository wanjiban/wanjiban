# fd
firewall-cmd 快捷执行一些命令

使用方法：

安装&更新：

`wget -q https://raw.githubusercontent.com/wanjiban/fd/main/fd.sh -O /bin/fd && chmod +x /bin/fd`

删除：

`rm -rf /bin/fd`

使用：输入 fd 即可弹出菜单供选择。


# check_services.sh
服务快捷检查重启一些命令

安装方法：
安装：`wget https://raw.githubusercontent.com/wanjiban/fd/main/check_services.sh -O /root/check_services.sh && sudo chmod +x /root/check_services.sh && (sudo crontab -l; echo "*/5 * * * * /root/check_services.sh") | sudo crontab -`


删除：`rm -rf /root/check_services.sh && (crontab -l | grep -v '/root/check_services.sh') | sudo crontab -`



# check_services.sh

超级 GitHub 下载 ：可一次性下载某个项目生成的全部 release 文件。

使用方法：
`yum install -y wget jq`

`wget https://raw.githubusercontent.com/wanjiban/fd/main/github_download.sh -O /root/github_download.sh && sudo chmod +x /root/github_download.sh`

`./github_download.sh wanjiban/wanjiban`
