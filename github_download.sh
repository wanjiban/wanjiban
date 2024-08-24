#!/bin/bash

# 检查是否提供了仓库路径作为参数
if [ -z "$1" ]; then
    echo "Usage: $0 REPO"
    echo "Example: $0 wanjiban/wanjiban"
    exit 1
fi

# 设置 GitHub 仓库路径
REPO=$1

# 获取所有 Releases 页面中所有 Releases 的信息
RELEASES_URL="https://api.github.com/repos/$REPO/releases"

# 使用 curl 获取 JSON 数据
RELEASES_JSON=$(curl -s $RELEASES_URL)

# 检查是否成功获取到 JSON 数据
if [ -z "$RELEASES_JSON" ]; then
    echo "Failed to retrieve releases information. Please check the repository path and network connection."
    exit 1
fi

# 创建一个目录来存放所有 Releases
MAIN_DOWNLOAD_DIR=$(echo "$REPO" | awk -F'/' '{print $2}')
mkdir -p "$MAIN_DOWNLOAD_DIR"

# 进入主下载目录
cd "$MAIN_DOWNLOAD_DIR" || exit

# 使用 jq 解析每个 Release 的名称和下载链接，并下载文件
echo "$RELEASES_JSON" | jq -c '.[]' | while read -r release; do
    # 解析 Release 的名称
    RELEASE_NAME=$(echo "$release" | jq -r '.tag_name')
    
    # 解析下载链接
    DOWNLOAD_URLS=$(echo "$release" | jq -r '.assets[].browser_download_url')

    # 检查是否有下载链接
    if [ -z "$DOWNLOAD_URLS" ]; then
        echo "No download links found for release $RELEASE_NAME."
        continue
    fi

    # 创建单个 Release 的下载目录
    RELEASE_DIR="$RELEASE_NAME"
    mkdir -p "$RELEASE_DIR"

    # 进入 Release 下载目录
    cd "$RELEASE_DIR" || exit

    # 计数器
    COUNT=0

    # MD5 文件
    MD5_FILE="md5sums.txt"

    # 使用 jq 解析每个 Asset 的下载链接，并下载文件
    echo "$DOWNLOAD_URLS" | while read -r URL; do
        # 获取文件名
        FILE_NAME=$(basename "$URL")

        # 检查 MD5 文件是否存在
        if [ -f "$MD5_FILE" ]; then
            # 从 MD5 文件中获取已保存的 MD5 校验和
            SAVED_MD5=$(grep "$FILE_NAME" "$MD5_FILE" | awk '{print $1}')
        else
            SAVED_MD5=""
        fi

        # 计算当前文件的 MD5 校验和
        if [ -f "$FILE_NAME" ]; then
            CURRENT_MD5=$(md5sum "$FILE_NAME" | awk '{print $1}')
        else
            CURRENT_MD5=""
        fi

        # 下载文件并计算 MD5 校验和
        if [ -z "$SAVED_MD5" ] || [ "$CURRENT_MD5" != "$SAVED_MD5" ]; then
            ((COUNT++))
            echo "Downloading file $COUNT: $FILE_NAME from release $RELEASE_NAME"
            wget -q --output-document=/dev/null "$URL"
            # 计算下载文件的 MD5 校验和
            NEW_MD5=$(md5sum "$FILE_NAME" | awk '{print $1}')
            # 更新 MD5 文件
            grep -v "$FILE_NAME" "$MD5_FILE" > "$MD5_FILE.tmp" && mv "$MD5_FILE.tmp" "$MD5_FILE"
            echo "$NEW_MD5  $FILE_NAME" >> "$MD5_FILE"
        else
            echo "$FILE_NAME already exists and matches the MD5 checksum. Skipping download."
        fi
    done

    # 返回主下载目录
    cd ..

    echo "All files from release $RELEASE_NAME have been downloaded to directory $RELEASE_DIR"
done

# 计算并显示下载的所有文件大小总计
TOTAL_SIZE=$(du -sh . | awk '{print $1}')
echo "Total size of downloaded files: $TOTAL_SIZE"

# 提示完成
echo "All files have been downloaded to directory $MAIN_DOWNLOAD_DIR"
