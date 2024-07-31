#!/bin/bash

# 检查是否提供了用户名参数
if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube Username>"
    exit 1
fi

# 设置变量
USERNAME=$1
YT_DLP_DIR="./yt-dlp_linux"
CONFIG_FILE="$YT_DLP_DIR/yt-dlp.conf"
YT_DLP="$YT_DLP_DIR/yt-dlp --config-locations $YT_DLP_DIR"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件 $CONFIG_FILE 不存在。"
    exit 1
fi

# 从配置文件中获取下载目录 (-P 参数)
DOWNLOAD_DIR=$(grep -E '^-P ' "$CONFIG_FILE" | awk '{print $2}' | sed 's/\/$//')

# 如果找不到 -P 参数，使用默认下载目录
if [ -z "$DOWNLOAD_DIR" ]; then
    echo "未在配置文件中找到 -P 参数，使用默认下载目录。"
    DOWNLOAD_DIR=$YT_DLP_DIR
fi

# 替换非法字符
SANITIZED_USERNAME=$(echo "$USERNAME" | sed 's/\@//g')
USER_DIR="${DOWNLOAD_DIR}/${SANITIZED_USERNAME}"

# 创建用户目录
mkdir -p "$USER_DIR"

# 获取频道播放列表信息
PLAYLISTS=$($YT_DLP --flat-playlist -J "https://www.youtube.com/${USERNAME}/playlists" | jq -r '.entries[].id' | grep '^PL')

if [ -z "$PLAYLISTS" ]; then
    echo "无法获取播放列表，请检查用户名是否正确或网络连接。"
    exit 1
fi

# 处理每个播放列表
for PLAYLIST_ID in $PLAYLISTS; do
    # 获取播放列表的标题
    PLAYLIST_TITLE=$($YT_DLP --flat-playlist -J "https://www.youtube.com/playlist?list=${PLAYLIST_ID}" | jq -r '.title')

    if [ -z "$PLAYLIST_TITLE" ]; then
        PLAYLIST_TITLE="Playlist_${PLAYLIST_ID}"
    fi

    # 创建播放列表目录
    PLAYLIST_DIR="${USER_DIR}/${PLAYLIST_TITLE}"
    mkdir -p "$PLAYLIST_DIR"

    # 下载播放列表中的所有内容
    $YT_DLP -o "${PLAYLIST_DIR}/%(playlist_index)s - %(title)s.%(ext)s" "https://www.youtube.com/playlist?list=${PLAYLIST_ID}"

    # 遍历下载的文件，生成和检查 MD5
    for FILE in "${PLAYLIST_DIR}"/*; do
        if [[ -f "$FILE" && "${FILE}" != *.md5 ]]; then
            MD5_FILE="${FILE}.md5"

            # 计算当前文件的 MD5
            CURRENT_MD5=$(md5sum "$FILE" | awk '{print $1}')

            # 检查是否已经存在 MD5 文件
            if [ -f "$MD5_FILE" ]; then
                SAVED_MD5=$(cat "$MD5_FILE")
                if [ "$CURRENT_MD5" = "$SAVED_MD5" ]; then
                    echo "文件 $FILE 已经存在且 MD5 校验和匹配，跳过下载。"
                    continue
                else
                    echo "文件 $FILE 的 MD5 校验和不匹配，重新下载。"
                fi
            fi

            # 保存新的 MD5
            echo "$CURRENT_MD5" > "$MD5_FILE"
        fi
    done

    echo "播放列表 $PLAYLIST_TITLE 的所有内容已下载到目录 ${PLAYLIST_DIR}"
done

echo "所有下载任务完成。"
