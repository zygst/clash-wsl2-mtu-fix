#!/usr/bin/env bash
# 一键安装 clash-wsl2-mtu-fix
# 用法: curl -fsSL https://raw.githubusercontent.com/zygst/clash-wsl2-mtu-fix/main/install.sh | sudo bash

set -euo pipefail

REPO="zygst/clash-wsl2-mtu-fix"
BINARY_NAME="clash-wsl2-mtu-fix"
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="clash-wsl2-mtu-fix"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# 必须 root
if [[ $EUID -ne 0 ]]; then
    error "请使用 root 权限运行（推荐用 curl ... | sudo bash）"
fi

# 检查依赖
command -v curl >/dev/null 2>&1 || error "需要 curl，请先安装：apt update && apt install -y curl"
command -v systemctl >/dev/null 2>&1 || error "需要 systemd"

info "正在获取最新 Release..."

LATEST_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest") || error "无法获取 Release 信息，请检查网络"

TAG=$(echo "$LATEST_JSON" | grep -o '"tag_name": *"[^"]*"' | head -n1 | cut -d'"' -f4)
DOWNLOAD_URL=$(echo "$LATEST_JSON" | grep -o '"browser_download_url": *"[^"]*clash-wsl2-mtu-fix"' | head -n1 | cut -d'"' -f4)

[[ -n "$TAG" && -n "$DOWNLOAD_URL" ]] || error "解析 Release 信息失败"

info "最新版本: ${TAG}"
info "下载地址: ${DOWNLOAD_URL}"

TMP_BIN=$(mktemp)
trap 'rm -f "$TMP_BIN"' EXIT

info "正在下载二进制文件..."
curl -fsSL -o "$TMP_BIN" "$DOWNLOAD_URL" || error "下载失败"
chmod +x "$TMP_BIN"

info "安装到 ${INSTALL_DIR}/${BINARY_NAME}"
install -m 755 "$TMP_BIN" "${INSTALL_DIR}/${BINARY_NAME}"
ok "二进制安装完成"

info "正在写入 systemd 服务文件..."
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Clash WSL2 MTU Fix
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/${BINARY_NAME}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

ok "服务已安装并启动"
echo
info "服务状态："
systemctl --no-pager status "$SERVICE_NAME" || true
echo
ok "安装完成！"
echo
echo "常用命令："
echo "  手动执行一次:  systemctl start ${SERVICE_NAME}"
echo "  查看状态:      systemctl status ${SERVICE_NAME}"
echo "  卸载:          systemctl disable --now ${SERVICE_NAME} && rm -f ${SERVICE_PATH} ${INSTALL_DIR}/${BINARY_NAME} && systemctl daemon-reload"
