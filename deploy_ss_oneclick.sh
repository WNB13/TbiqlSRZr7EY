#!/usr/bin/env bash
set -euo pipefail

# One-click deploy Shadowsocks-libev for Clash clients.
# Tested on Ubuntu 22.04 / Debian family.

PORT="443"
METHOD="chacha20-ietf-poly1305"
PASSWORD=""
SERVER_IP=""
ENABLE_UFW="auto"

usage() {
  cat <<'EOF'
Usage:
  sudo bash deploy_ss_oneclick.sh --password <PASS> [options]

Required:
  --password <PASS>            Shadowsocks password

Optional:
  --port <PORT>                Server port (default: 443)
  --method <METHOD>            Cipher method (default: chacha20-ietf-poly1305)
  --server-ip <IP>             Override server IP shown in output (default: auto detect)
  --enable-ufw <auto|yes|no>   Manage UFW rules for port (default: auto)
  -h, --help                   Show this help

Example:
  sudo bash deploy_ss_oneclick.sh --password 'StrongPass123!' --port 443
EOF
}

log() {
  echo "[INFO] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Please run as root (use sudo)."
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --password)
        PASSWORD="${2:-}"
        shift 2
        ;;
      --port)
        PORT="${2:-}"
        shift 2
        ;;
      --method)
        METHOD="${2:-}"
        shift 2
        ;;
      --server-ip)
        SERVER_IP="${2:-}"
        shift 2
        ;;
      --enable-ufw)
        ENABLE_UFW="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "${PASSWORD}" ]]; then
    err "--password is required"
    usage
    exit 1
  fi

  if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    err "Invalid --port: ${PORT}"
    exit 1
  fi

  case "${ENABLE_UFW}" in
    auto|yes|no) ;;
    *)
      err "--enable-ufw must be one of: auto, yes, no"
      exit 1
      ;;
  esac
}

install_packages() {
  log "Updating apt index..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y

  log "Installing dependencies: shadowsocks-libev, jq, qrencode..."
  apt-get install -y shadowsocks-libev jq qrencode curl
}

write_config() {
  log "Writing /etc/shadowsocks-libev/config.json ..."
  cat >/etc/shadowsocks-libev/config.json <<EOF
{
  "server": "0.0.0.0",
  "server_port": ${PORT},
  "password": "${PASSWORD}",
  "timeout": 300,
  "method": "${METHOD}",
  "mode": "tcp_and_udp",
  "fast_open": false
}
EOF
}

start_service() {
  log "Restarting and enabling shadowsocks-libev service..."
  systemctl restart shadowsocks-libev
  systemctl enable shadowsocks-libev >/dev/null 2>&1 || true

  if ! systemctl is-active --quiet shadowsocks-libev; then
    err "shadowsocks-libev service is not active"
    systemctl --no-pager --full status shadowsocks-libev || true
    exit 1
  fi
}

configure_firewall() {
  if ! command -v ufw >/dev/null 2>&1; then
    log "UFW not installed, skip firewall step."
    return
  fi

  local ufw_state
  ufw_state="$(ufw status | head -n1 | awk '{print $2}')"

  if [[ "${ENABLE_UFW}" == "no" ]]; then
    log "Skipping UFW rules by user choice."
    return
  fi

  if [[ "${ENABLE_UFW}" == "yes" || "${ufw_state}" == "active" ]]; then
    log "Applying UFW rules for ${PORT}/tcp and ${PORT}/udp ..."
    ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
    ufw allow "${PORT}/udp" >/dev/null 2>&1 || true
    ufw reload >/dev/null 2>&1 || true
  else
    log "UFW inactive, skip opening ports in UFW."
  fi
}

resolve_server_ip() {
  if [[ -n "${SERVER_IP}" ]]; then
    return
  fi

  SERVER_IP="$(curl -4s --max-time 5 https://api.ipify.org || true)"
  if [[ -z "${SERVER_IP}" ]]; then
    SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi

  if [[ -z "${SERVER_IP}" ]]; then
    SERVER_IP="YOUR_SERVER_IP"
  fi
}

generate_yaml() {
  cat <<EOF
port: 7890
socks-port: 7891
redir-port: 7892
mixed-port: 7893
tproxy-port: 7895
allow-lan: true
mode: rule
log-level: info
ipv6: false
unified-delay: true
tcp-concurrent: true
find-process-mode: strict
global-client-fingerprint: chrome

profile:
  store-selected: true
  store-fake-ip: true

sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    TLS:
      ports: [443, 8443]
    HTTP:
      ports: [80, 8080-8880]
    QUIC:
      ports: [443, 8443]
  force-domain:
    - +.v2ex.com
    - +.google.com
    - +.youtube.com
  skip-domain:
    - Mijia Cloud
    - +.push.apple.com

tun:
  enable: true
  stack: mixed
  dns-hijack:
    - any:53
    - tcp://any:53
  auto-route: true
  auto-detect-interface: true
  strict-route: true
  endpoint-independent-nat: true

dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - +.lan
    - +.local
    - +.msftconnecttest.com
    - +.msftncsi.com
    - localhost.ptlogin2.qq.com
    - localhost.sec.qq.com
    - +.qq.com
    - +.ntp.org
    - time.*.com
    - time.*.gov
    - pool.ntp.org
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  proxy-server-nameserver:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
  nameserver-policy:
    geosite:cn:
      - https://dns.alidns.com/dns-query
      - https://doh.pub/dns-query
    geosite:geolocation-!cn:
      - https://1.1.1.1/dns-query
      - https://8.8.8.8/dns-query

proxies:
  - name: SS-${SERVER_IP}-${PORT}
    type: ss
    server: ${SERVER_IP}
    port: ${PORT}
    cipher: ${METHOD}
    password: ${PASSWORD}
    udp: true

proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
      - 手动切换
      - DIRECT

  - name: 手动切换
    type: select
    proxies:
      - SS-${SERVER_IP}-${PORT}
      - DIRECT

  - name: 自动选择
    type: url-test
    proxies:
      - SS-${SERVER_IP}-${PORT}
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50

  - name: AI服务
    type: select
    proxies:
      - 节点选择
      - 手动切换
      - DIRECT

  - name: YouTube
    type: select
    proxies:
      - 节点选择
      - 手动切换

  - name: Telegram
    type: select
    proxies:
      - 节点选择
      - 手动切换

  - name: 国外媒体
    type: select
    proxies:
      - 节点选择
      - 手动切换
      - DIRECT

  - name: 国内直连
    type: select
    proxies:
      - DIRECT
      - 节点选择

  - name: 漏网之鱼
    type: select
    proxies:
      - 节点选择
      - DIRECT

rule-providers:
  reject:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt
    path: ./ruleset/reject.yaml
    interval: 86400

  icloud:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/icloud.txt
    path: ./ruleset/icloud.yaml
    interval: 86400

  apple:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/apple.txt
    path: ./ruleset/apple.yaml
    interval: 86400

  google:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/google.txt
    path: ./ruleset/google.yaml
    interval: 86400

  proxy:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt
    path: ./ruleset/proxy.yaml
    interval: 86400

  direct:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt
    path: ./ruleset/direct.yaml
    interval: 86400

  private:
    type: http
    behavior: domain
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt
    path: ./ruleset/private.yaml
    interval: 86400

  telegramcidr:
    type: http
    behavior: ipcidr
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt
    path: ./ruleset/telegramcidr.yaml
    interval: 86400

  cncidr:
    type: http
    behavior: ipcidr
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt
    path: ./ruleset/cncidr.yaml
    interval: 86400

  lancidr:
    type: http
    behavior: ipcidr
    url: https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/lancidr.txt
    path: ./ruleset/lancidr.yaml
    interval: 86400

rules:
  - RULE-SET,reject,REJECT
  - RULE-SET,private,DIRECT
  - RULE-SET,icloud,DIRECT
  - RULE-SET,apple,DIRECT
  - RULE-SET,google,节点选择
  - RULE-SET,proxy,节点选择
  - RULE-SET,direct,DIRECT
  - RULE-SET,telegramcidr,Telegram
  - RULE-SET,lancidr,DIRECT
  - RULE-SET,cncidr,DIRECT

  - DOMAIN-KEYWORD,openai,AI服务
  - DOMAIN-KEYWORD,anthropic,AI服务
  - DOMAIN-KEYWORD,claude,AI服务
  - DOMAIN-SUFFIX,chatgpt.com,AI服务
  - DOMAIN-SUFFIX,openai.com,AI服务
  - DOMAIN-SUFFIX,oaistatic.com,AI服务
  - DOMAIN-SUFFIX,oaiusercontent.com,AI服务

  - DOMAIN-SUFFIX,youtube.com,YouTube
  - DOMAIN-SUFFIX,youtu.be,YouTube
  - DOMAIN-SUFFIX,ytimg.com,YouTube

  - GEOIP,CN,DIRECT
  - MATCH,漏网之鱼
EOF
}

print_result() {
  local enc ss_uri
  if base64 --help 2>/dev/null | grep -q -- '-w'; then
    enc="$(printf '%s' "${METHOD}:${PASSWORD}" | base64 -w 0)"
  else
    enc="$(printf '%s' "${METHOD}:${PASSWORD}" | base64 | tr -d '\n')"
  fi

  ss_uri="ss://${enc}@${SERVER_IP}:${PORT}#ss-${SERVER_IP}-${PORT}"

  echo
  echo "================ Deployment Success ================"
  echo "Service: shadowsocks-libev"
  echo "Server : ${SERVER_IP}"
  echo "Port   : ${PORT}"
  echo "Method : ${METHOD}"
  echo "UDP    : true"
  echo
  echo "SS URI:"
  echo "${ss_uri}"
  echo
  echo "Clash proxy snippet:"
  cat <<EOF
- name: SS-${SERVER_IP}-${PORT}
  type: ss
  server: ${SERVER_IP}
  port: ${PORT}
  cipher: ${METHOD}
  password: ${PASSWORD}
  udp: true
EOF
  echo
  echo "Service status:"
  systemctl --no-pager --full status shadowsocks-libev | sed -n '1,18p'
  echo "Listening check:"
  ss -lunpt | grep ":${PORT}" || true
  echo "===================================================="

  local yaml_path="${HOME}/vpn.yaml"
  generate_yaml >"${yaml_path}"
  log "Clash YAML saved to ${yaml_path}"

  echo
  echo "================ Clash YAML Config ================"
  generate_yaml
  echo "===================================================="
  echo "Tip: YAML also saved to ${HOME}/vpn.yaml, copy it to your local machine and import into Clash."
  echo
}

main() {
  require_root
  parse_args "$@"
  install_packages
  write_config
  start_service
  configure_firewall
  resolve_server_ip
  print_result
}

main "$@"
