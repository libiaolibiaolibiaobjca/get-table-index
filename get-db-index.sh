#!/bin/bash

# 配置
NEXUS_BASE_URL="http://192.168.131.36:8088/repository/snapshots"
GROUP_ID="cn.bjca.footstone.bedrock"
ARTIFACT_ID="get-table-index"
CACHE_DIR="/tmp/${ARTIFACT_ID}-cache"

# 将 groupId 转换为路径格式（cn.bjca.footstone.bedrock -> cn/bjca/footstone/bedrock）
GROUP_PATH="${GROUP_ID//.//}"
METADATA_URL="${NEXUS_BASE_URL}/${GROUP_PATH}/${ARTIFACT_ID}/maven-metadata.xml"

# 创建缓存目录
mkdir -p "${CACHE_DIR}"

# 离线模式标志
OFFLINE_MODE=false

# 从缓存目录查找最新的 jar 文件
find_latest_cached_jar() {
    # 查找缓存目录中最新的 jar 文件（按修改时间排序）
    CACHED_JAR=$(ls -t "${CACHE_DIR}"/${ARTIFACT_ID}-*.jar 2>/dev/null | head -1)

    if [ -n "${CACHED_JAR}" ]; then
        echo "${CACHED_JAR}"
        return 0
    else
        return 1
    fi
}

# 使用缓存的 jar 执行
use_cached_jar() {
    echo "----------------------------------------"
    echo "尝试使用缓存的 JAR 文件..."
    echo "----------------------------------------"

    if CACHED_JAR=$(find_latest_cached_jar); then
        echo "找到缓存的 JAR: ${CACHED_JAR}"
        echo "----------------------------------------"
        echo "正在执行: java -jar ${CACHED_JAR} $@"
        echo "----------------------------------------"
        java -jar "${CACHED_JAR}" "$@"
        exit $?
    else
        echo "错误: 缓存目录中没有找到可用的 JAR 文件"
        echo "提示: 首次运行需要网络连接以下载 JAR 文件"
        exit 1
    fi
}

# 解析命令行参数
ARGS=()
for arg in "$@"; do
    case $arg in
        --offline|-o)
            OFFLINE_MODE=true
            shift
            ;;
        --help|-h)
            echo "用法: $0 [选项] <字符串参数>"
            echo ""
            echo "选项:"
            echo "  -o, --offline    离线模式，使用缓存的 JAR 文件"
            echo "  -h, --help       显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 34xwhoqaJlgLhtgfNJ3QVeDPlDF           # 在线模式，检查并下载最新版本"
            echo "  $0 --offline 34xwhoqaJlgLhtgfNJ3QVeDPlDF # 离线模式，使用缓存的 JAR"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# 如果是离线模式，直接使用缓存
if [ "$OFFLINE_MODE" = true ]; then
    echo "离线模式已启用"
    use_cached_jar "${ARGS[@]}"
fi

# 在线模式：尝试获取最新版本
echo "正在获取 Maven 元数据..."
# 下载 maven-metadata.xml
METADATA_FILE="${CACHE_DIR}/maven-metadata.xml"
if ! curl -f -s -o "${METADATA_FILE}" "${METADATA_URL}"; then
    echo "警告: 无法下载 maven-metadata.xml 从 ${METADATA_URL}"
    echo "网络连接失败，尝试使用缓存..."
    use_cached_jar "${ARGS[@]}"
fi

echo "正在解析版本信息..."
# 获取最新版本号（兼容 macOS 的解析方法）
# 首先尝试获取 <latest> 标签
LATEST_VERSION=$(grep '<latest>' "${METADATA_FILE}" 2>/dev/null | sed -E 's/.*<latest>([^<]+)<\/latest>.*/\1/')

# 如果没有 <latest> 标签，则获取最后一个 <version> 标签
if [ -z "${LATEST_VERSION}" ]; then
    LATEST_VERSION=$(grep '<version>' "${METADATA_FILE}" | sed -E 's/.*<version>([^<]+)<\/version>.*/\1/' | tail -1)
fi

if [ -z "${LATEST_VERSION}" ]; then
    echo "警告: 无法解析版本号"
    echo "尝试使用缓存..."
    use_cached_jar "${ARGS[@]}"
fi

echo "最新版本: ${LATEST_VERSION}"

# 下载该版本的 maven-metadata.xml 获取具体的 SNAPSHOT 信息
VERSION_METADATA_URL="${NEXUS_BASE_URL}/${GROUP_PATH}/${ARTIFACT_ID}/${LATEST_VERSION}/maven-metadata.xml"
VERSION_METADATA_FILE="${CACHE_DIR}/version-maven-metadata.xml"

echo "正在获取 SNAPSHOT 详细信息..."
if ! curl -f -s -o "${VERSION_METADATA_FILE}" "${VERSION_METADATA_URL}"; then
    echo "警告: 无法下载版本元数据从 ${VERSION_METADATA_URL}"
    echo "尝试使用缓存..."
    use_cached_jar "${ARGS[@]}"
fi

# 解析 SNAPSHOT 的时间戳和构建号（兼容 macOS 的解析方法）
TIMESTAMP=$(grep '<timestamp>' "${VERSION_METADATA_FILE}" | sed -E 's/.*<timestamp>([^<]+)<\/timestamp>.*/\1/')
BUILD_NUMBER=$(grep '<buildNumber>' "${VERSION_METADATA_FILE}" | sed -E 's/.*<buildNumber>([^<]+)<\/buildNumber>.*/\1/')

# 构建 jar 文件名
if [ -n "${TIMESTAMP}" ] && [ -n "${BUILD_NUMBER}" ]; then
    # 有时间戳版本
    BASE_VERSION=${LATEST_VERSION%-SNAPSHOT}
    JAR_VERSION="${BASE_VERSION}-${TIMESTAMP}-${BUILD_NUMBER}"
    JAR_FILE="${ARTIFACT_ID}-${JAR_VERSION}.jar"
else
    # 直接使用 SNAPSHOT 版本
    JAR_FILE="${ARTIFACT_ID}-${LATEST_VERSION}.jar"
fi

JAR_URL="${NEXUS_BASE_URL}/${GROUP_PATH}/${ARTIFACT_ID}/${LATEST_VERSION}/${JAR_FILE}"
JAR_PATH="${CACHE_DIR}/${JAR_FILE}"

echo "JAR 文件: ${JAR_FILE}"
echo "下载地址: ${JAR_URL}"

# 检查是否已缓存
if [ -f "${JAR_PATH}" ]; then
    echo "发现缓存的 JAR 文件: ${JAR_PATH}"
else
    echo "正在下载 JAR 文件..."
    if ! curl -f -o "${JAR_PATH}" "${JAR_URL}"; then
        echo "警告: 无法下载 JAR 文件从 ${JAR_URL}"
        echo "尝试使用缓存..."
        use_cached_jar "${ARGS[@]}"
    fi
    echo "下载完成: ${JAR_PATH}"
fi

# 执行 jar 文件
echo "----------------------------------------"
echo "正在执行: java -jar ${JAR_PATH} ${ARGS[@]}"
echo "----------------------------------------"
java -jar "${JAR_PATH}" "${ARGS[@]}"
