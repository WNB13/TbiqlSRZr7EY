# Shadowsocks 一键部署脚本使用手册

本项目提供一个用于服务器端快速部署 Shadowsocks 的脚本：
- `deploy_ss_oneclick.sh`

脚本目标：
- 自动安装 `shadowsocks-libev`
- 自动写入服务配置并启动
- 自动设置开机自启
- 可选处理 UFW 放行
- 输出可直接用于 Clash 的完整 YAML 配置，并自动保存到服务器家目录的 `~/vpn.yaml`
- 默认启动一个静态订阅服务，输出可直接用于 Clash 的订阅链接

## 0. 服务器一键部署（无需手动上传脚本）

SSH 登录服务器后，执行以下命令即可完成全部部署：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WNB13/TbiqlSRZr7EY/main/deploy_ss_oneclick.sh) --password '你的强密码'
```

自定义端口示例：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WNB13/TbiqlSRZr7EY/main/deploy_ss_oneclick.sh) --password '你的强密码' --port 8443
```

执行完毕后，终端会输出 SS URI、静态订阅链接和可直接导入 Clash 的完整 YAML 配置，同时会在服务器家目录保存一份配置文件：`~/vpn.yaml`。

## 0.1 免责说明

使用本项目脚本前，请先确认并接受以下事项：

1. 本项目仅用于服务器运维、网络连通性测试、远程访问、自有环境调试与其他合法合规用途。
2. 使用者应自行确认所在地法律法规、所在网络环境的管理要求、云服务商服务条款以及目标系统的访问授权范围。因不当使用导致的封禁、停机、警告、数据丢失、法律责任或其他后果，由使用者自行承担。
3. 本脚本会在目标服务器上安装软件包、修改系统服务配置、启动服务、可能调整防火墙规则，并在终端输出包含敏感信息的连接参数。使用前应确认该服务器属于你本人或已获得明确授权管理。
4. 本脚本输出的密码、SS URI、Clash YAML 和其他连接信息均属于敏感凭据。因截图、日志留存、终端录屏、聊天转发、仓库误提交或其他泄露行为造成的后果，由使用者自行承担。
5. 文档中的一键部署命令使用在线脚本直连执行方式，即通过网络实时获取远程脚本并在本机运行。该方式虽然方便，但存在供应链风险、仓库内容变更风险以及网络劫持风险。用于生产环境前，建议先下载脚本、人工审阅内容、固定版本或提交哈希后再执行。
6. 本项目按“现状”提供，不对可用性、稳定性、隐蔽性、兼容性、持续可访问性或适用于特定业务目的作任何明示或暗示担保。不同云厂商、网络环境、地域线路和客户端版本可能导致行为差异。
7. 如因系统升级、软件源变化、规则源失效、网络阻断、服务端口冲突、防火墙策略、安全组策略或客户端兼容性问题导致部署失败或连接异常，需要由使用者自行排查并承担变更影响。
8. 若你准备在团队、企业、学校、生产环境或面向他人提供服务的场景中使用本项目，请先完成内部安全评估、权限审批、配置审计与变更备案，不建议直接以默认参数上线。

## 1. 环境要求

- 服务器系统：Ubuntu / Debian（推荐 Ubuntu 22.04）
- 执行权限：root（或 sudo）
- 网络：服务器可访问 apt 源
- 云安全组：需放行你使用的端口（默认 TCP/UDP 443）

## 2. 快速开始

### 2.1 上传脚本到服务器

可用 `scp` 上传：

```bash
scp deploy_ss_oneclick.sh root@<SERVER_IP>:/root/
```

### 2.2 在服务器执行部署

```bash
sudo bash /root/deploy_ss_oneclick.sh --password '<你的强密码>'
```

部署成功后，终端会输出：
- SS URI
- Clash 订阅链接
- 完整 Clash YAML 配置
- 服务状态摘要
- 监听端口检查结果

部署成功后，服务器上还会生成：
- `~/vpn.yaml`：可直接下载到本地并导入 Clash 的完整配置文件
- `/opt/clash-subscription/<token>.yaml`：用于订阅服务的静态配置文件

如需下载到本地，可执行：

```bash
scp root@<SERVER_IP>:~/vpn.yaml ./vpn.yaml
```

如果直接用订阅方式，在 Clash 中填入脚本输出的订阅链接即可，无需手动下载文件。

## 3. 参数说明

```text
Required:
  --password <PASS>            Shadowsocks 密码

Optional:
  --port <PORT>                服务端口，默认 443
  --method <METHOD>            加密算法，默认 chacha20-ietf-poly1305
  --server-ip <IP>             指定输出中的服务器 IP（默认自动探测）
  --enable-ufw <auto|yes|no>   是否处理 UFW 规则，默认 auto
  --enable-subscription <yes|no>
                               是否启用静态订阅服务，默认 yes
  --subscription-port <PORT>   订阅服务端口，默认 18080
  --subscription-token <TOKEN> 固定订阅 token；不传则自动生成并持久化
  -h, --help                   查看帮助
```

## 4. 常用命令示例

### 4.1 默认端口（443）

```bash
sudo bash deploy_ss_oneclick.sh --password 'StrongPass_2026'
```

### 4.2 自定义端口

```bash
sudo bash deploy_ss_oneclick.sh --password 'StrongPass_2026' --port 8443
```

### 4.3 强制写入 UFW 规则

```bash
sudo bash deploy_ss_oneclick.sh --password 'StrongPass_2026' --enable-ufw yes
```

### 4.4 指定输出 IP（多网卡场景）

```bash
sudo bash deploy_ss_oneclick.sh --password 'StrongPass_2026' --server-ip 23.144.132.167
```

### 4.5 自定义订阅端口和 token

```bash
sudo bash deploy_ss_oneclick.sh --password 'StrongPass_2026' --subscription-port 18080 --subscription-token myclashsubtoken
```

### 4.6 关闭订阅服务

```bash
sudo bash deploy_ss_oneclick.sh --password 'StrongPass_2026' --enable-subscription no
```

## 5. 执行后验收

在服务器执行：

```bash
systemctl status shadowsocks-libev --no-pager
ss -lunpt | grep ':443'
```

期望结果：
- `shadowsocks-libev` 为 `active (running)`
- 看到 `0.0.0.0:443` 的 tcp/udp 监听（如果你改了端口则对应新端口）

在客户端执行：
- 直接使用脚本输出的订阅链接，或导入脚本保存的 `~/vpn.yaml`
- 启用 Clash 配置后访问 `https://ip.sb` 或 `https://ipinfo.io`
- 出口 IP 应为服务器公网 IP

## 6. Clash 节点片段示例

脚本会输出类似以下内容（示例）：

```yaml
- name: SS-23.144.132.167-443
  type: ss
  server: 23.144.132.167
  port: 443
  cipher: chacha20-ietf-poly1305
  password: your_password
  udp: true
```

## 7. 回滚与重部署

### 7.1 停止服务

```bash
sudo systemctl stop shadowsocks-libev
```

### 7.2 查看当前配置

```bash
cat /etc/shadowsocks-libev/config.json
```

### 7.3 重新部署（覆盖式）

```bash
sudo bash deploy_ss_oneclick.sh --password '<新密码>' --port 443
```

## 8. 常见问题

### 8.1 脚本执行提示权限不足

请使用 root 或 sudo 执行：

```bash
sudo bash deploy_ss_oneclick.sh --password '<密码>'
```

### 8.2 节点连不上

依次检查：
1. 云安全组是否放行 TCP/UDP 端口
2. 服务器防火墙是否拦截
3. 客户端节点参数是否与服务器一致（端口、算法、密码）
4. 服务是否正常运行：`systemctl status shadowsocks-libev`

### 8.3 订阅链接无法访问

依次检查：
1. 云安全组是否放行订阅端口 TCP（默认 18080）
2. 服务是否正常运行：`systemctl status clash-subscription`
3. 端口是否监听：`ss -lnpt | grep ':18080'`
4. 订阅文件是否存在：`ls -l /opt/clash-subscription/`

### 8.4 忘记订阅链接如何找回

可用以下任一方式找回：

1. 读取 token 文件：

```bash
cat /opt/clash-subscription/.token
```

若输出为 `abc123xyz`，服务器 IP 为 `23.144.132.167`，订阅端口为默认 `18080`，则订阅链接为：

```text
http://23.144.132.167:18080/abc123xyz.yaml
```

2. 查看订阅目录中的 YAML 文件名：

```bash
ls -l /opt/clash-subscription/
```

目录中的 `<token>.yaml` 文件名就是订阅链接中的 token。

3. 重新运行部署脚本：

```bash
sudo bash deploy_ss_oneclick.sh --password '<你的原密码>'
```

脚本会复用已保存的 token，并重新在终端输出订阅链接。

### 8.5 UFW 未生效

脚本默认 `auto` 模式：仅在 UFW 激活时写规则。可手动强制：

```bash
sudo bash deploy_ss_oneclick.sh --password '<密码>' --enable-ufw yes
```

## 9. 安全建议

- 使用高强度随机密码（至少 16 位）
- 定期更换密码并同步更新客户端
- 避免将密码和配置文件公开到代码仓库
- 生产环境建议准备备用节点或备用端口

## 10. 相关文件

- `deploy_ss_oneclick.sh`：一键部署脚本
- `部署手册.md`：完整部署流程文档
- `配置手册.md`：Clash 使用与配置说明
- `vpn.yaml`：当前 Clash 配置样例
