#!/bin/bash

# 检查是否提供了仓库路径作为参数
if [ -z "$1" ]; then
    echo "Usage: $0 REPO [del/null]"
    echo "Example: $0 wanjiban/wanjiban"
    echo "Example: $0 wanjiban/wanjiban del"
    echo "Example: $0 wanjiban/wanjiban null"
    exit 1
fi

# 设置 GitHub 仓库路径
REPO=$1

# 检查是否启用 del 或 null 模式
DEL_MODE=false
NULL_MODE=false
if [ "$2" == "del" ]; then
    DEL_MODE=true
elif [ "$2" == "null" ]; then
    NULL_MODE=true
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

# 创建一个目录来存放所有 Releases（如果未启用 del 或 null 模式）
if [ "$DEL_MODE" = false ] && [ "$NULL_MODE" = false ]; then
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

    if [ "$DEL_MODE" = false ] && [ "$NULL_MODE" = false ]; then
        RELEASE_DIR="$RELEASE_NAME"
        mkdir -p "$RELEASE_DIR"
        cd "$RELEASE_DIR" || exit
    fi

    COUNT=0
    MD5_FILE="md5sums.txt"

    echo "$DOWNLOAD_URLS" | while read -r URL; do
        FILE_NAME=$(basename "$URL")
        if [ "$DEL_MODE" = false ] && [ "$NULL_MODE" = false ]; then
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
                echo "Downloading file $COUNT from $RELEASE_NAME: $FILE_NAME"
                wget --progress=bar -q "$URL"
                NEW_MD5=$(md5sum "$FILE_NAME" | awk '{print $1}')
                grep -v "$FILE_NAME" "$MD5_FILE" > "$MD5_FILE.tmp" && mv "$MD5_FILE.tmp" "$MD5_FILE"
                echo "$NEW_MD5  $FILE_NAME" >> "$MD5_FILE"
            else
                echo "$FILE_NAME already exists and matches the MD5 checksum. Skipping download."
            fi
        elif [ "$DEL_MODE" = true ]; then
            ((COUNT++))
            echo "Downloading and deleting file $COUNT from $RELEASE_NAME: $FILE_NAME"
            wget --progress=bar -q "$URL"
            rm -f "$FILE_NAME"
        elif [ "$NULL_MODE" = true ]; then
            ((COUNT++))
            echo "Downloading file $COUNT from $RELEASE_NAME to /dev/null: $FILE_NAME"
            wget --progress=bar -q "$URL" -O /dev/null
        fi
    done

    if [ "$DEL_MODE" = false ] && [ "$NULL_MODE" = false ]; then
        cd ..
        echo "All files from release $RELEASE_NAME have been downloaded to directory $RELEASE_DIR"
    fi
done

# 提示完成
if [ "$DEL_MODE" = false ] && [ "$NULL_MODE" = false ]; then
    echo "All files have been downloaded to directory $MAIN_DOWNLOAD_DIR"
elif [ "$DEL_MODE" = true ]; then
    echo "In del mode, all downloaded files were deleted after download."
else
    echo "In null mode, all files were downloaded directly to /dev/null."
fi
