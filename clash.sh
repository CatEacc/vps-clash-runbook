#!/bin/bash
# ==============================================================================
# CatEacc 生产级 Clash (Mihomo v1.19.34) 一键生成配置 & Linux 部署脚本
# 仓库: https://github.com/CatEacc/vps-clash-runbook
# 配套服务端: https://github.com/CatEacc/vps-xray-runbook
# ==============================================================================

set -euo pipefail
trap 'rm -rf /tmp/mihomo-dl' EXIT

MIHOMO_VERSION="v1.19.34"
OS_INFO=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}" || uname -s)
ARCH_INFO=$(uname -m)

ESC="$(printf '\033')"
R="${ESC}[0m"
B="${ESC}[1m"
SKY="${ESC}[38;5;39m"
CYAN="${ESC}[38;5;51m"
GREEN="${ESC}[38;5;46m"
YELLOW="${ESC}[38;5;220m"
 PINK="${ESC}[38;5;205m"
WHITE="${ESC}[1;97m"
DIM="${ESC}[38;5;245m"

print_cateacc_logo() {
    G1="${ESC}[38;5;46m"
    G2="${ESC}[38;5;82m"
    G3="${ESC}[38;5;118m"
    G4="${ESC}[38;5;226m"
    G5="${ESC}[38;5;220m"
    G6="${ESC}[38;5;208m"
    G7="${ESC}[38;5;199m"
    awk -v c1="$G1" -v c2="$G2" -v c3="$G3" -v c4="$G4" -v c5="$G5" -v c6="$G6" -v c7="$G7" -v rs="$R" -v bd="$B" '
    {
        line = $0
        while (length(line) < 42) line = line " "
        printf "  %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n", \
            bd c1, substr(line, 1, 6), \
            c2, substr(line, 7, 6), \
            c3, substr(line, 13, 6), \
            c4, substr(line, 19, 6), \
            c5, substr(line, 25, 6), \
            c6, substr(line, 31, 6), \
            c7, substr(line, 37, 6), \
            rs
    }
    ' <<'BANNER'
   ______      __  ______               
  / ____/___ _/ /_/ ____/___ ___________
 / /   / __ `/ __/ __/ / __ `/ ___/ ___/
/ /___/ /_/ / /_/ /___/ /_/ / /__/ /__  
\____/\__,_/\__/_____/\__,_/\___/\___/  
BANNER
}

yaml_quote() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "$s"
}

clean_host() {
    local h="$1"
    h=$(printf "%s" "$h" | tr -d '[:space:]')
    h="${h#[}"
    h="${h%]}"
    printf "%s" "$h"
}

validate_port() {
    local p="$1" def="$2"
    if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]; then
        echo "$p"
    else
        echo "  [提示] 端口 '${p}' 非法，已使用默认端口 ${def}" >&2
        echo "$def"
    fi
}

MODE="${1:-}"
if [ -z "$MODE" ]; then
    clear 2>/dev/null || true
    printf '\n'
    print_cateacc_logo
    printf '\n'
    printf "  ${CYAN}猫e/acc (CatEacc)${R} ${DIM}· Clash (Mihomo ${MIHOMO_VERSION}) 一键配置与部署脚本${R}\n"
    printf "  ${GREEN}──────────────────────────────────────────────────────────${R}\n"
    printf "  ${SKY}System:${R}   ${GREEN}${OS_INFO} (${ARCH_INFO})${R}\n"
    printf "  ${SKY}GitHub:${R}   ${CYAN}https://github.com/CatEacc/vps-clash-runbook${R}\n"
    printf "  ${SKY}Channel:${R}  ${CYAN}https://t.me/CatCryptoMaster${R}\n"
    printf "  ${GREEN}──────────────────────────────────────────────────────────${R}\n\n"
    printf "  ${WHITE}请选择功能：${R}\n"
    printf "  ${GREEN}[1]${R} ${WHITE}一键生成 Mihomo config.yaml 配置文件${R} ${CYAN}★ 推荐 · 零缩进报错${R}\n"
    printf "      ${DIM}交互式填入前置节点 (REALITY Vision / Hy2) + 可选家宽链式代理 (SS-2022)${R}\n"
    printf "  ${GREEN}[2]${R} ${WHITE}Linux / 软路由一键安装 Mihomo ${MIHOMO_VERSION} 客户端服务${R} ${PINK}· systemd 自启${R}\n"
    printf "      ${DIM}自动适配 AVX2/兼容内核 + 原子更新二进制 + 加载 /etc/mihomo/config.yaml${R}\n\n"
    read -rp "$(printf "${YELLOW}  请输入功能编号 [1-2] (回车默认 1): ${R}")" MODE
    MODE="${MODE:-1}"
fi

generate_config() {
    local out_file="$1"
    local def_tun="${2:-true}"
    echo ""
    printf "  ${CYAN}--- 第 1 步：配置前置节点（机房优化机）---${R}\n"
    printf "  1) VLESS + REALITY + Vision（全平台通吃，推荐）\n"
    printf "  2) Hysteria 2 + 端口跳跃\n"
    read -rp "  请选择前置节点协议 [1-2] (回车默认 1): " P_TYPE
    P_TYPE="${P_TYPE:-1}"

    local PROXY_BLOCK=""
    local RELAY_NAME=""

    if [ "$P_TYPE" = "1" ]; then
        RELAY_NAME="Relay-REALITY-Vision"
        read -rp "  前置机 IP 或域名: " R_HOST
        R_HOST=$(clean_host "$R_HOST")
        read -rp "  前置机端口 (回车默认 443): " R_PORT
        R_PORT=$(validate_port "${R_PORT:-443}" 443)
        read -rp "  VLESS UUID: " R_UUID
        R_UUID=$(printf "%s" "$R_UUID" | tr -d '[:space:]')
        read -rp "  REALITY Public Key (pbk): " R_PBK
        R_PBK=$(printf "%s" "$R_PBK" | tr -d '[:space:]')
        read -rp "  REALITY Short ID (sid，可留空): " R_SID
        R_SID=$(printf "%s" "$R_SID" | tr -d '[:space:]')
        echo "  请选择 REALITY SNI (须与服务端完全一致)："
        echo "    1) addons.mozilla.org （推荐：纯海外无国内 CDN）"
        echo "    2) www.gentoo.org     （纯海外无国内 CDN）"
        echo "    3) 手动输入自定义域名"
        read -rp "  请输入选项 [1-3] (回车默认 1): " SNI_OPT
        case "${SNI_OPT:-1}" in
            1) R_SNI="addons.mozilla.org" ;;
            2) R_SNI="www.gentoo.org" ;;
            3)
                read -rp "  -> 请输入自定义 SNI: " SNI_CUSTOM
                R_SNI=$(printf "%s" "${SNI_CUSTOM:-addons.mozilla.org}" | tr -d '[:space:]')
                ;;
            *) R_SNI="addons.mozilla.org" ;;
        esac

        PROXY_BLOCK="  - name: \"${RELAY_NAME}\"
    type: vless
    server: $(yaml_quote "$R_HOST")
    port: ${R_PORT}
    uuid: $(yaml_quote "$R_UUID")
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: $(yaml_quote "$R_SNI")
    reality-opts:
      public-key: $(yaml_quote "$R_PBK")
      short-id: $(yaml_quote "$R_SID")
    client-fingerprint: chrome"
    else
        RELAY_NAME="Relay-Hy2-Hopping"
        read -rp "  前置机 IP 或域名: " R_HOST
        R_HOST=$(clean_host "$R_HOST")
        read -rp "  Hysteria 2 端口 (回车默认 8443): " R_PORT
        R_PORT=$(validate_port "${R_PORT:-8443}" 8443)
        read -rp "  端口跳跃范围 (回车默认 20000-50000): " R_MPORT
        R_MPORT=$(printf "%s" "${R_MPORT:-20000-50000}" | tr -d '[:space:]')
        read -rp "  Hysteria 2 密码: " R_PASS
        read -rp "  SNI (回车默认 www.bing.com): " R_SNI
        R_SNI=$(printf "%s" "${R_SNI:-www.bing.com}" | tr -d '[:space:]')
        read -rp "  证书 SHA256 指纹 (正规证书留空): " R_FP
        R_FP=$(printf "%s" "$R_FP" | tr -d '[:space:]')

        PROXY_BLOCK="  - name: \"${RELAY_NAME}\"
    type: hysteria2
    server: $(yaml_quote "$R_HOST")
    port: ${R_PORT}
    ports: $(yaml_quote "$R_MPORT")
    password: $(yaml_quote "$R_PASS")
    sni: $(yaml_quote "$R_SNI")"
        if [ -n "$R_FP" ]; then
            PROXY_BLOCK="${PROXY_BLOCK}
    skip-cert-verify: true
    fingerprint: $(yaml_quote "$R_FP")"
        fi
    fi

    echo ""
    read -rp "  是否通过 dialer-proxy 链式中转后端海外家宽 (SS-2022)？[y/N]: " USE_RES
    USE_RES="${USE_RES:-n}"
    local RES_NAME=""
    if [[ "$USE_RES" =~ ^[Yy]$ ]]; then
        RES_NAME="Residential-ISP-Landing"
        read -rp "  -> 家宽机 IP: " RES_HOST
        RES_HOST=$(clean_host "$RES_HOST")
        read -rp "  -> 家宽机 SS-2022 端口: " RES_PORT
        RES_PORT=$(validate_port "${RES_PORT:-30001}" 30001)
        read -rp "  -> 家宽机 SS-2022 密钥 (32字节 Base64): " RES_PASS
        RES_PASS=$(printf "%s" "$RES_PASS" | tr -d '[:space:]')
        PROXY_BLOCK="${PROXY_BLOCK}

  - name: \"${RES_NAME}\"
    type: ss
    server: $(yaml_quote "$RES_HOST")
    port: ${RES_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: $(yaml_quote "$RES_PASS")
    udp: true
    dialer-proxy: \"🚀 前置优化机\""
    fi

    local TUN_ENABLE="$def_tun"
    if [ "$def_tun" = "false" ]; then
        read -rp "  是否开启 TUN 全局网卡模式？（远程 SSH 服务器强烈选 n 防断网；本地软路由可选 y）[y/N]: " ASK_TUN
        [[ "${ASK_TUN:-n}" =~ ^[Yy]$ ]] && TUN_ENABLE="true" || TUN_ENABLE="false"
    else
        read -rp "  是否开启 TUN 虚拟网卡模式？（桌面端推荐选 Y；仅用系统代理可选 n）[Y/n]: " ASK_TUN
        [[ "${ASK_TUN:-y}" =~ ^[Nn]$ ]] && TUN_ENABLE="false" || TUN_ENABLE="true"
    fi

    read -rp "  是否拦截 UDP 443 (QUIC) 以保护驻地家宽光猫？[y/N]: " BLOCK_Q
    BLOCK_Q="${BLOCK_Q:-n}"
    local QUIC_RULE="  # - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT"
    if [[ "$BLOCK_Q" =~ ^[Yy]$ ]]; then
        QUIC_RULE="  - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT"
    fi

    local LANDING_PROXIES="      - 🚀 前置优化机"
    if [ -n "$RES_NAME" ]; then
        LANDING_PROXIES="      - ${RES_NAME}
      - 🚀 前置优化机"
    fi

    mkdir -p "$(dirname "$out_file")"
    (
    umask 077
    cat << EOF > "$out_file"
# Generated by CatEacc/vps-clash-runbook (Mihomo ${MIHOMO_VERSION}+)
mixed-port: 7890
allow-lan: false
bind-address: 127.0.0.1
mode: rule
log-level: warning
ipv6: false
unified-delay: true
tcp-concurrent: true
find-process-mode: strict

profile:
  store-selected: true
  store-fake-ip: true

sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  override-destination: false
  sniff:
    HTTP:
      ports: [80, 8080-8880]
      override-destination: true
    TLS:
      ports: [443, 8443]
    QUIC:
      ports: [443, 8443]

tun:
  enable: ${TUN_ENABLE}
  stack: mixed
  dns-hijack:
    - any:53
    - tcp://any:53
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  strict-route: true

dns:
  enable: true
  listen: 127.0.0.1:1053
  ipv6: false
  respect-rules: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "+.msftconnecttest.com"
    - "+.msftncsi.com"
    - "localhost.ptlogin2.qq.com"
    - "time.*.com"
    - "ntp.*.com"
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  proxy-server-nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  nameserver:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
  nameserver-policy:
    "rule-set:cn_domain,private_domain":
      - https://doh.pub/dns-query
      - https://dns.alidns.com/dns-query

proxies:
${PROXY_BLOCK}

proxy-groups:
  - name: "🚀 前置优化机"
    type: select
    proxies:
      - ${RELAY_NAME}

  - name: "🏠 纯净家宽出口"
    type: select
    proxies:
${LANDING_PROXIES}

  - name: "🤖 AI 平台"
    type: select
    proxies:
      - 🏠 纯净家宽出口
      - 🚀 前置优化机

  - name: "🎬 海外流媒体"
    type: select
    proxies:
      - 🏠 纯净家宽出口
      - 🚀 前置优化机

  - name: "🌐 默认代理"
    type: select
    proxies:
      - 🚀 前置优化机
      - 🏠 纯净家宽出口
      - DIRECT

  - name: "🐟 漏网之鱼"
    type: select
    proxies:
      - 🌐 默认代理
      - DIRECT

rule-anchor:
  domain: &domain { type: http, interval: 86400, behavior: domain, format: mrs }
  ip: &ip { type: http, interval: 86400, behavior: ipcidr, format: mrs }

rule-providers:
  private_domain: { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/private.mrs" }
  private_ip:     { <<: *ip,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/private.mrs" }
  cn_domain:      { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/cn.mrs" }
  cn_ip:          { <<: *ip,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/cn.mrs" }
  openai:         { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/openai.mrs" }
  anthropic:      { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/anthropic.mrs" }
  gemini:         { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/google-gemini.mrs" }
  netflix:        { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/netflix.mrs" }
  tiktok:         { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/tiktok.mrs" }
  youtube:        { <<: *domain, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/youtube.mrs" }
  telegram_ip:    { <<: *ip,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/telegram.mrs" }

rules:
${QUIC_RULE}
  - RULE-SET,private_domain,DIRECT
  - RULE-SET,private_ip,DIRECT,no-resolve
  - RULE-SET,openai,🤖 AI 平台
  - RULE-SET,anthropic,🤖 AI 平台
  - RULE-SET,gemini,🤖 AI 平台
  - RULE-SET,netflix,🎬 海外流媒体
  - RULE-SET,tiktok,🎬 海外流媒体
  - RULE-SET,youtube,🌐 默认代理
  - RULE-SET,telegram_ip,🌐 默认代理,no-resolve
  - RULE-SET,cn_domain,DIRECT
  - RULE-SET,cn_ip,DIRECT,no-resolve
  - MATCH,🐟 漏网之鱼
EOF
    )
    chmod 600 "$out_file"
}

case "$MODE" in
    1)
        OUT_FILE="./mihomo-config.yaml"
        generate_config "$OUT_FILE" "true"
        echo ""
        printf "  ${GREEN}配置已生成：${WHITE}${OUT_FILE}${R}\n"
        printf "  ${DIM}直接将该文件下载或复制导入 Clash Verge Rev / Mihomo Party / FlClash 即可使用。${R}\n"
        ;;
    2)
        if [ "$(id -u)" != "0" ]; then
            echo "[错误] 安装 Linux Mihomo 服务需要 root 权限！请先执行 sudo -i"
            exit 1
        fi
        case "$ARCH_INFO" in
            x86_64|amd64)
                if grep -qw avx2 /proc/cpuinfo 2>/dev/null; then
                    M_ARCH="amd64"
                else
                    M_ARCH="amd64-compatible"
                    echo "  [提示] 检测到当前 x86_64 CPU 不支持 AVX2，自动选用 ${M_ARCH} 兼容内核防 SIGILL 崩溃"
                fi
                ;;
            aarch64|arm64) M_ARCH="arm64" ;;
            *)             echo "[错误] 暂不支持架构: ${ARCH_INFO}"; exit 1 ;;
        esac

        if ! command -v gzip >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq && apt-get install -y -qq curl gzip ca-certificates
        fi

        echo "[1/3] 下载官方 Mihomo ${MIHOMO_VERSION} (${M_ARCH})..."
        mkdir -p /etc/mihomo /tmp/mihomo-dl
        curl -fsSL -o /tmp/mihomo-dl/mihomo.gz "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${M_ARCH}-${MIHOMO_VERSION}.gz"
        gzip -dc /tmp/mihomo-dl/mihomo.gz > /usr/local/bin/mihomo.new
        chmod 755 /usr/local/bin/mihomo.new
        mv -f /usr/local/bin/mihomo.new /usr/local/bin/mihomo
        rm -rf /tmp/mihomo-dl

        echo "[2/3] 配置 /etc/mihomo/config.yaml..."
        IS_PLACEHOLDER="0"
        if [ ! -f /etc/mihomo/config.yaml ]; then
            read -rp "  是否立即交互生成 /etc/mihomo/config.yaml？[Y/n]: " GEN_NOW
            GEN_NOW="${GEN_NOW:-y}"
            if [[ "$GEN_NOW" =~ ^[Yy]$ ]]; then
                generate_config /etc/mihomo/config.yaml "false"
            else
                (umask 077; curl -fsSL -o /etc/mihomo/config.yaml "https://raw.githubusercontent.com/CatEacc/vps-clash-runbook/main/config.yaml")
                sed -i '/^tun:/,/^[^[:space:]]/ s/enable: true/enable: false/' /etc/mihomo/config.yaml 2>/dev/null || true
                IS_PLACEHOLDER="1"
            fi
        fi
        chmod 700 /etc/mihomo && chmod 600 /etc/mihomo/config.yaml

        echo "[3/3] 校验配置并注册 systemd 服务..."
        cat << 'EOF' > /etc/systemd/system/mihomo.service
[Unit]
Description=Mihomo (Clash Meta) Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo -f /etc/mihomo/config.yaml
Restart=always
RestartSec=3s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        if [ "$IS_PLACEHOLDER" = "1" ]; then
            systemctl enable mihomo >/dev/null 2>&1 || true
            printf "  ${YELLOW}[提示] 当前 /etc/mihomo/config.yaml 为示例占位模板（已自动关闭 TUN 防断联）。${R}\n"
            printf "  ${DIM}请填入真实节点参数后执行：mihomo -d /etc/mihomo -t -f /etc/mihomo/config.yaml && systemctl restart mihomo${R}\n"
        else
            /usr/local/bin/mihomo -d /etc/mihomo -t -f /etc/mihomo/config.yaml
            systemctl enable --now mihomo && systemctl restart mihomo
            printf "  ${GREEN}Mihomo 服务状态：$(systemctl is-active mihomo)${R}\n"
            printf "  ${DIM}混合代理监听: 127.0.0.1:7890 | 配置文件: /etc/mihomo/config.yaml${R}\n"
        fi
        ;;
    *)
        echo "[错误] 无效编号: ${MODE}，仅支持 1 或 2"
        exit 1
        ;;
esac

printf "\n  ${GREEN}──────────────────────────────────────────────────────────${R}\n"
printf "  ${CYAN}本脚本由 猫e/acc (CatEacc) 维护提供${R}\n"
printf "  ${SKY}GitHub:${R}  ${CYAN}https://github.com/CatEacc/vps-clash-runbook${R}\n"
printf "  ${SKY}Channel:${R} ${CYAN}https://t.me/CatCryptoMaster${R}\n"
printf "  ${GREEN}──────────────────────────────────────────────────────────${R}\n"
