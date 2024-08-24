# fd
`firewall-cmd` 快捷执行一些 firewall-cmd 防火墙命令。

## 使用方法

- **安装 & 更新**：
  ```bash
  wget -q https://raw.githubusercontent.com/wanjiban/fd/main/fd.sh -O /bin/fd && chmod +x /bin/fd
  ```

- **删除**：
  ```bash
  rm -rf /bin/fd
  ```

- **使用**：
  输入 `fd` 即可弹出菜单供选择。

---

# check_services.sh
服务快捷检查与重启脚本

## 安装方法

- **安装**：
  ```bash
  wget https://raw.githubusercontent.com/wanjiban/fd/main/check_services.sh -O /root/check_services.sh && sudo chmod +x /root/check_services.sh && (sudo crontab -l; echo "*/5 * * * * /root/check_services.sh") | sudo crontab -
  ```

- **删除**：
  ```bash
  rm -rf /root/check_services.sh && (crontab -l | grep -v '/root/check_services.sh') | sudo crontab -
  ```

---

# github_download.sh
超级 GitHub 下载脚本：可一次性下载某个项目生成的全部 Release 文件。同时可以增加第三个参数null，模拟下载功能。

## 使用方法

- **安装所需工具**：
  ```bash
  yum install -y wget jq
  ```

- **下载脚本**：
  ```bash
  wget https://raw.githubusercontent.com/wanjiban/fd/main/github_download.sh -O /root/github_download.sh && sudo chmod +x /root/github_download.sh
  ```

- **使用**：
  ```bash
  ./github_download.sh wanjiban/wanjiban
  ./github_download.sh wanjiban/wanjiban null
  ```
