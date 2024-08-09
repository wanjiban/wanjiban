#!/bin/bash

# 1. 安装 node_exporter
echo "Downloading and installing node_exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
tar xvf node_exporter-1.6.0.linux-amd64.tar.gz
sudo mv node_exporter-1.6.0.linux-amd64/node_exporter /usr/local/bin/

# 2. 创建 Systemd 服务文件
echo "Creating node_exporter service file..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# 3. 启动并启用 node_exporter
echo "Starting and enabling node_exporter service..."
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# 4. 检查 node_exporter 服务状态
echo "Checking node_exporter service status..."
sudo systemctl status node_exporter

# 5. 检查 node_exporter 是否在监听端口 9100
echo "Checking node_exporter on port 9100..."
curl -s http://localhost:9100/metrics | head -n 10

# 6. 查看 node_exporter 日志
echo "Displaying node_exporter logs..."
sudo journalctl -u node_exporter --since "1 hour ago"

# 7. 确保 Prometheus 已配置 node_exporter
echo "Checking Prometheus scrape configuration..."
sudo grep -A 3 'job_name: '\''node_exporter'\''' /etc/prometheus/prometheus.yml || {
    echo "node_exporter scrape configuration not found, adding it..."
    sudo tee -a /etc/prometheus/prometheus.yml > /dev/null <<EOF

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
    echo "Reloading Prometheus configuration..."
    sudo systemctl reload prometheus
}

# 8. 检查 Prometheus 是否能抓取 node_exporter 的数据
echo "Checking Prometheus for node_exporter metrics..."
curl -s "http://localhost:9090/api/v1/query?query=node_cpu_seconds_total" | jq .

# 9. 检查 Prometheus Targets 页面
echo "Checking Prometheus targets..."
curl -s "http://localhost:9090/api/v1/targets" | jq .

echo "Installation and checks completed."
