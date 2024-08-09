#!/bin/bash

# 获取最新版本号的函数
get_latest_version() {
    local repo=$1
    curl -s https://api.github.com/repos/$repo/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")' | sed 's/^v//'
}

# 安装 Prometheus 的函数
install_prometheus() {
    echo "Fetching the latest Prometheus version..."
    latest_version=$(get_latest_version "prometheus/prometheus")

    echo "Latest Prometheus version: $latest_version"
    echo "Downloading Prometheus..."
    wget https://github.com/prometheus/prometheus/releases/download/v$latest_version/prometheus-$latest_version.linux-amd64.tar.gz

    echo "Extracting Prometheus..."
    tar xvf prometheus-$latest_version.linux-amd64.tar.gz

    echo "Moving Prometheus binaries to /usr/local/bin..."
    sudo mv prometheus-$latest_version.linux-amd64/prometheus /usr/local/bin/
    sudo mv prometheus-$latest_version.linux-amd64/promtool /usr/local/bin/

    echo "Creating Prometheus configuration and data directories..."
    sudo mkdir /etc/prometheus
    sudo mkdir /var/lib/prometheus

    echo "Moving Prometheus configuration files to /etc/prometheus..."
    sudo mv prometheus-$latest_version.linux-amd64/prometheus.yml /etc/prometheus/
    sudo mv prometheus-$latest_version.linux-amd64/consoles /etc/prometheus/
    sudo mv prometheus-$latest_version.linux-amd64/console_libraries /etc/prometheus/

    echo "Setting up Prometheus user and group..."
    sudo useradd --no-create-home --shell /bin/false prometheus
    sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

    echo "Creating Prometheus service file..."
    sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus/ \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=:9090

[Install]
WantedBy=multi-user.target
EOF

    echo "Starting and enabling Prometheus service..."
    sudo systemctl daemon-reload
    sudo systemctl start prometheus
    sudo systemctl enable prometheus

    echo "Checking Prometheus service status..."
    sudo systemctl status prometheus

    echo "Checking Prometheus Web UI..."
    curl -s http://localhost:9090 | grep -o "Prometheus Time Series Collection and Processing Server" && echo "Prometheus installed and running successfully."
}

# 安装 Node Exporter 的函数
install_node_exporter() {
    echo "Fetching the latest Node Exporter version..."
    latest_version=$(get_latest_version "prometheus/node_exporter")

    echo "Latest Node Exporter version: $latest_version"
    echo "Downloading Node Exporter..."
    wget https://github.com/prometheus/node_exporter/releases/download/v$latest_version/node_exporter-$latest_version.linux-amd64.tar.gz

    echo "Extracting Node Exporter..."
    tar xvf node_exporter-$latest_version.linux-amd64.tar.gz

    echo "Moving Node Exporter binary to /usr/local/bin..."
    sudo mv node_exporter-$latest_version.linux-amd64/node_exporter /usr/local/bin/

    echo "Setting up Node Exporter user and group..."
    sudo useradd --no-create-home --shell /bin/false node_exporter
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

    echo "Creating Node Exporter service file..."
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    echo "Starting and enabling Node Exporter service..."
    sudo systemctl daemon-reload
    sudo systemctl start node_exporter
    sudo systemctl enable node_exporter

    echo "Checking Node Exporter service status..."
    sudo systemctl status node_exporter

    echo "Checking Node Exporter metrics..."
    curl -s http://localhost:9100/metrics | grep -o "# HELP" && echo "Node Exporter installed and running successfully."
}

# 添加 Node Exporter 到 Prometheus 配置的函数
add_node_exporter_to_prometheus() {
    read -p "Enter the Node Exporter server IP address: " node_exporter_ip
    # 将 IP 地址转换为 job_name (e.g., 192.168.8.2 -> node_002)
    ip_last_octet=$(echo $node_exporter_ip | awk -F '.' '{print $4}')
    job_name="node_$(printf "%03d" $ip_last_octet)"

    sudo tee -a /etc/prometheus/prometheus.yml > /dev/null <<EOF

  - job_name: '$job_name'
    static_configs:
      - targets: ['$node_exporter_ip:9100']
EOF

    echo "Reloading Prometheus service..."
    sudo systemctl reload prometheus
    echo "Node Exporter ($node_exporter_ip) has been added to Prometheus configuration under job name '$job_name'."
}

# 主菜单
echo "Choose an option:"
echo "1) Install Prometheus"
echo "2) Install Node Exporter"
echo "3) Add Node Exporter to Prometheus configuration"
read -p "Enter your choice: " choice

case $choice in
    1)
        install_prometheus
        ;;
    2)
        install_node_exporter
        ;;
    3)
        add_node_exporter_to_prometheus
        ;;
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac
