#!/bin/bash

# 检查是否提供了用户名参数
if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube Username>"
    exit 1
fi

# 设置变量
USERNAME=$1
YT_DLP="./yt-dlp"
BASE_DIR="./${USERNAME}"

# 对用户名进行 URL 编码
ENCODED_USERNAME=$(printf '%s' "$USERNAME" | jq -sRr @uri)

# 创建用户目录
mkdir -p "$BASE_DIR"

# 获取用户播放列表
PLAYLISTS=$(curl -s "https://www.youtube.com/user/${ENCODED_USERNAME}/playlists" | grep -oP '"playlistId":"\K[^"]+')

if [ -z "$PLAYLISTS" ]; then
    echo "无法获取播放列表，请检查用户名是否正确或网络连接。"
    exit 1
fi

# 处理每个播放列表
for PLAYLIST_ID in $PLAYLISTS; do
    # 获取播放列表的标题
    PLAYLIST_TITLE=$(curl -s "https://www.youtube.com/playlist?list=${PLAYLIST_ID}" | grep -oP '<title>\K[^<]+' | sed 's/[^a-zA-Z0-9]/_/g')

    if [ -z "$PLAYLIST_TITLE" ]; then
        PLAYLIST_TITLE="Playlist_${PLAYLIST_ID}"
    fi

    # 创建播放列表目录
    PLAYLIST_DIR="${BASE_DIR}/${PLAYLIST_TITLE}"
    mkdir -p "$PLAYLIST_DIR"

    echo "处理播放列表: $PLAYLIST_TITLE"

    # 下载播放列表中的所有内容
    $YT_DLP -f best -o "${PLAYLIST_DIR}/%(title)s.%(ext)s" "https://www.youtube.com/playlist?list=${PLAYLIST_ID}"

    # 遍历下载的文件，生成和检查 MD5
    for FILE in "${PLAYLIST_DIR}"/*; do
        if [ -f "$FILE" ]; then
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
