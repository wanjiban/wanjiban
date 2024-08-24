#!/bin/bash

# 检查是否提供了仓库路径作为参数
if [ -z "$1" ]; then
    echo "Usage: $0 REPO [null]"
    echo "Example: $0 wanjiban/wanjiban"
    echo "Example: $0 wanjiban/wanjiban null"
    exit 1
fi

# 设置 GitHub 仓库路径
REPO=$1

# 检查是否启用 null 模式
DRY_RUN=false
if [ "$2" == "null" ]; then
    DRY_RUN=true
fi

# 获取所有 Releases 页面中所有 Releases 的信息
RELEASES_URL="https://api.github.com/repos/$REPO/releases"

# 使用 curl 获取 JSON 数据
RELEASES_JSON=$(curl -s $RELEASES_URL)

# 检查是否成功获取到 JSON 数据
if [ -z "$RELEASES_JSON" ]; then
    echo "无法获取 Releases 信息，请检查仓库路径和网络连接。"
    exit 1
fi

# 创建一个目录来存放所有 Releases（如果未启用 null 模式）
if [ "$DRY_RUN" = false ]; then
    MAIN_DOWNLOAD_DIR=$(echo "$REPO" | awk -F'/' '{print $2}')
    mkdir -p "$MAIN_DOWNLOAD_DIR"
    cd "$MAIN_DOWNLOAD_DIR" || exit
fi

# 使用 jq 解析每个 Release 的名称和下载链接，并下载文件
echo "$RELEASES_JSON" | jq -c '.[]' | while read -r release; do
    RELEASE_NAME=$(echo "$release" | jq -r '.tag_name')
    DOWNLOAD_URLS=$(echo "$release" | jq -r '.assets[].browser_download_url')

    if [ -z "$DOWNLOAD_URLS" ]; then
        echo "Release $RELEASE_NAME 没有找到下载链接。"
        continue
    fi

    if [ "$DRY_RUN" = false ]; then
        RELEASE_DIR="$RELEASE_NAME"
        mkdir -p "$RELEASE_DIR"
        cd "$RELEASE_DIR" || exit
    fi

    COUNT=0
    MD5_FILE="md5sums.txt"

    echo "$DOWNLOAD_URLS" | while read -r URL; do
        FILE_NAME=$(basename "$URL")
        if [ "$DRY_RUN" = false ]; then
            if [ -f "$MD5_FILE" ]; then
                SAVED_MD5=$(grep "$FILE_NAME" "$MD5_FILE" | awk '{print $1}')
            else
                SAVED_MD5=""
            fi

            if [ -f "$FILE_NAME" ]; then
                CURRENT_MD5=$(md5sum "$FILE_NAME" | awk '{print $1}')
            else
                CURRENT_MD5=""
            fi

            if [ -z "$SAVED_MD5" ] || [ "$CURRENT_MD5" != "$SAVED_MD5" ]; then
                ((COUNT++))
                echo "正在下载 $RELEASE_NAME 中的文件 $COUNT: $FILE_NAME"
                wget --progress=bar -q "$URL"
                NEW_MD5=$(md5sum "$FILE_NAME" | awk '{print $1}')
                grep -v "$FILE_NAME" "$MD5_FILE" > "$MD5_FILE.tmp" && mv "$MD5_FILE.tmp" "$MD5_FILE"
                echo "$NEW_MD5  $FILE_NAME" >> "$MD5_FILE"
            else
                echo "$FILE_NAME 已经存在且 MD5 校验和匹配，跳过下载。"
            fi
        else
            ((COUNT++))
            echo "模拟下载 $RELEASE_NAME 中的文件 $COUNT: $FILE_NAME"
            wget --progress=bar -q "$URL" -O /dev/null
        fi
    done

    if [ "$DRY_RUN" = false ]; then
        cd ..
        echo "$RELEASE_NAME 的所有文件已下载到目录 $RELEASE_DIR"
    fi
done

# 提示完成
if [ "$DRY_RUN" = false ]; then
    echo "所有文件已下载到目录 $MAIN_DOWNLOAD_DIR"
else
    echo "null 模式下，所有文件均未保存。"
fi
