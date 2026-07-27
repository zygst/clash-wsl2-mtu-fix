# clash-wsl2-mtu-fix

修复 **WSL2 镜像网络模式（`networkingMode=mirrored`）** 与 **Clash TUN 模式** 共同使用时，因 MTU 错误导致无法正常联网的问题。

## 问题说明

在 WSL2 开启镜像网络模式后，再启用 Clash 的 TUN 模式，经常会出现以下现象：

- 能 ping 通外网 IP
- 但 HTTPS、HTTP 等大包流量无法正常访问（表现为卡住或超时）

根本原因是 Clash TUN 虚拟网卡（通常 IP 为 `198.18.0.1`）的默认 MTU 较高（常见为 9000），与镜像网络模式下的实际网络环境不兼容。

将对应接口的 MTU 调整为 `1500` 后即可恢复正常。

本项目自动完成这一操作。

---

## 一键安装（推荐）

在 Ubuntu / Debian 等支持 systemd 的系统中，直接执行以下命令即可完成安装：

    curl -fsSL https://raw.githubusercontent.com/zygst/clash-wsl2-mtu-fix/main/install.sh | sudo bash

安装过程会自动完成以下操作：

1. 从 GitHub Releases 下载最新二进制文件
2. 安装到 `/usr/local/bin/clash-wsl2-mtu-fix`
3. 创建并启用 systemd 服务 `clash-wsl2-mtu-fix`
4. 立即执行一次修复，并设置开机自动运行

---

## 手动安装

如果不想使用一键脚本，也可以手动操作：

1. 从 [Releases](https://github.com/zygst/clash-wsl2-mtu-fix/releases) 页面下载最新的二进制文件 `clash-wsl2-mtu-fix`
2. 将文件放到任意目录（推荐 `/usr/local/bin/`），并赋予执行权限：

       sudo mv clash-wsl2-mtu-fix /usr/local/bin/
       sudo chmod +x /usr/local/bin/clash-wsl2-mtu-fix

3. 下载仓库中的 `clash-wsl2-mtu-fix.service` 文件，修改其中的 `ExecStart=` 路径为你实际放置二进制的路径
4. 将修改后的 service 文件放到 `/etc/systemd/system/` 目录
5. 执行以下命令启用并启动服务：

       sudo systemctl daemon-reload
       sudo systemctl enable clash-wsl2-mtu-fix
       sudo systemctl start clash-wsl2-mtu-fix

---

## 常用命令

    # 手动执行一次修复
    sudo systemctl start clash-wsl2-mtu-fix

    # 查看服务当前状态
    systemctl status clash-wsl2-mtu-fix

    # 查看服务日志
    journalctl -u clash-wsl2-mtu-fix -e

    # 停止并禁用开机启动
    sudo systemctl disable --now clash-wsl2-mtu-fix

    # 完全卸载
    sudo systemctl disable --now clash-wsl2-mtu-fix
    sudo rm -f /etc/systemd/system/clash-wsl2-mtu-fix.service
    sudo rm -f /usr/local/bin/clash-wsl2-mtu-fix
    sudo systemctl daemon-reload

---

## 原理说明

程序启动后会执行以下逻辑：

1. 遍历系统所有网络接口
2. 查找 IP 地址为 `198.18.0.1` 的接口（这是 Clash TUN 模式常用的虚拟网卡地址）
3. 将该接口的 MTU 设置为 `1500`

对应的核心命令等价于：

    ip link set <接口名> mtu 1500

通过 systemd 的 `oneshot` 服务 + `After=network-online.target`，确保在网络就绪后自动执行一次修复。

---

## 注意事项

- 需要 root 权限才能修改网卡 MTU
- 仅在检测到 IP 为 `198.18.0.1` 的接口时才会生效（即 Clash TUN 已启动的情况下）
- 如果 Clash 尚未开启 TUN 模式，服务执行时会提示未找到对应接口，这是正常现象
- 建议在 Clash 开启 TUN 后再手动执行一次 `systemctl start clash-wsl2-mtu-fix` 以确保生效
