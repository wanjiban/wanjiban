#!/bin/bash

# 更新系统并安装EPEL（Extra Packages for Enterprise Linux）
sudo yum update -y
sudo yum install -y epel-release

# 安装 Mosquitto Broker 和客户端
sudo yum install -y mosquitto mosquitto-clients

# 启用 Mosquitto 服务并设置为开机自启动
sudo systemctl enable mosquitto
sudo systemctl start mosquitto

# 创建 Mosquitto 配置目录
sudo mkdir -p /etc/mosquitto/conf.d

# 创建一个基本的配置文件
sudo tee /etc/mosquitto/mosquitto.conf > /dev/null <<EOF
# 禁止匿名访问
allow_anonymous false

# 使用密码文件进行认证
password_file /etc/mosquitto/passwd

# 配置监听端口
listener 1883

# 包含额外的配置文件
include_dir /etc/mosquitto/conf.d
EOF

# 添加 MQTT 用户
echo "请输入您想添加的 MQTT 用户名："
read MQTT_USER

# 创建密码文件并添加用户
sudo mosquitto_passwd -c /etc/mosquitto/passwd $MQTT_USER

# 重新启动 Mosquitto 以应用配置
sudo systemctl restart mosquitto

# 配置防火墙允许1883端口
#sudo firewall-cmd --permanent --add-port=1883/tcp
#sudo firewall-cmd --reload

# 显示 Mosquitto 服务状态
sudo systemctl status mosquitto

# 提示用户安装完成并提供基本信息
echo "Mosquitto Broker 安装和配置完成。"
echo "您可以使用以下命令测试 MQTT 连接："
echo "mosquitto_pub -h localhost -t 'test/topic' -m 'Hello MQTT' -u '$MQTT_USER' -P 'your_password'"
echo "mosquitto_sub -h localhost -t 'test/topic' -u '$MQTT_USER' -P 'your_password'"
