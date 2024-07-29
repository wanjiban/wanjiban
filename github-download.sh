#!/bin/bash

# 检查是否提供了仓库路径作为参数
if [ -z "$1" ]; then
    echo "Usage: $0 +REPO"
    echo "Example: $0 elseif/MikroTikPatch"
    exit 1
fi

# 设置 GitHub 仓库路径
REPO=$1

# 获取所有 Releases 页面中所有 Assets 的下载链接
RELEASES_URL="https://api.github.com/repos/$REPO/releases"

# 使用 curl 获取 JSON 数据，并用 jq 解析出所有的下载链接
ASSET_URLS=$(curl -s $RELEASES_URL | jq -r '.[].assets[].browser_download_url')

# 创建一个目录来存放下载的文件
DOWNLOAD_DIR="${REPO//\//-}-all-releases"
mkdir -p $DOWNLOAD_DIR

# 进入下载目录
cd $DOWNLOAD_DIR

# 使用 wget 下载所有 Assets
for URL in $ASSET_URLS; do
    wget $URL
done

# 提示完成
echo "所有文件已下载到目录 $DOWNLOAD_DIR"
