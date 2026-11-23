# 生产级 Clash (Mihomo) 实战配置与家宽链式分流手册（Mihomo v1.19.34）

[![Mihomo](https://img.shields.io/badge/Mihomo-v1.19.34-blue)](https://github.com/MetaCubeX/mihomo/releases)
[![Paired With](https://img.shields.io/badge/Server-vps--xray--runbook-green)](https://github.com/CatEacc/vps-xray-runbook)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-%E7%8C%ABe%2Facc-26A5E4?logo=telegram)](https://t.me/CatCryptoMaster)

> **仓库地址**：`github.com/CatEacc/vps-clash-runbook`  
> **配套服务端**：[CatEacc/vps-xray-runbook](https://github.com/CatEacc/vps-xray-runbook)（一键部署 `REALITY Vision` / `Hysteria 2` / `Shadowsocks-2022` 家宽落地）  
> **适用客户端**：Clash Verge Rev / Mihomo Party / FlClash / OpenClash (Meta 内核) / ShellCrash

---

## 小白一键脚本（生成零报错配置 / Linux 软路由一键装 Mihomo）

不想手改 YAML 缩进，或想在 Linux / 软路由上一键安装官方 `Mihomo v1.19.34` 服务，直接运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/CatEacc/vps-clash-runbook/main/clash.sh)
```

* **功能 1（小白推荐）**：交互式填入前置节点（`REALITY Vision` / `Hy2`）与可选家宽落地（`SS-2022`），**一键生成零缩进报错的完整 `mihomo-config.yaml`** 直接导入 Clash Verge Rev / Mihomo Party / FlClash；
* **功能 2（Linux / 软路由）**：一键下载官方 `Mihomo v1.19.34`、校验配置并注册 `systemd` 开机自启。

---

## 核心特性（为什么做这份配置）

1. **完美衔接自建服务端**：原生支持 `VLESS + REALITY + Vision`、`Hysteria 2`（含 `ports: 20000-50000` 端口跳跃）、`Shadowsocks-2022 (2022-blake3-aes-256-gcm)`；
2. **`dialer-proxy` 客户端链式代理**：一行配置即可让高速机房优化机（CN2 GIA / 9929 / CMIN2）自动中转后端**双 ISP 住宅家宽**，AI / 流媒体 / 风控业务精准走纯净住宅出口，日常冲浪走机房直连不浪费家宽流量；
3. **零 DNS 泄露 `Fake-IP` 架构**：严格区分 `proxy-server-nameserver`、`default-nameserver` 与 `nameserver`，开启 `respect-rules: true`，防止本地 DNS 抢答污染住宅 IP 画像；
4. **全量官方 `mrs` 二进制规则集**：采用 MetaCubeX 官方 `mrs` 格式（内存占用较传统 YAML 降 80%+，秒级启动），内置 AI（OpenAI / Claude / Gemini）、流媒体（Netflix / TikTok / YouTube）、私有/局域网、国内直连精准分流；
5. **家宽光猫友好（防 QUIC 丢包）**：可选一键拦截走家宽出口的 `UDP 443`（QUIC），逼迫浏览器无感回退至 `TCP 443`，彻底避免家用光猫状态表打满跳 Ping；
6. **双形态开箱即用**：
   - [`config.yaml`](config.yaml)：完整自建配置模板（填好自己的节点 IP/UUID/密钥直接导入）；
   - [`override.js`](override.js)：Clash Verge Rev / Mihomo Party 全局扩展脚本（直接套在现有订阅上，一键注入零泄露 DNS + AI/家宽分流）。

---

## 一、服务端协议与 Mihomo 客户端兼容性速查

如果你搭配 [vps-xray-runbook](https://github.com/CatEacc/vps-xray-runbook) 使用，**Clash / Mihomo 客户端请按以下优先级选协议**：

| 服务端协议（`vps-xray-runbook`） | Mihomo `v1.19.34` 兼容度 | 推荐定位 |
| :--- | :---: | :--- |
| **`VLESS + raw + REALITY + Vision`**（方案 1-2） | **100% 原生支持** | 主力前置机 / 极致低延迟 / 全平台通吃 |
| **`Hysteria 2 + 端口跳跃`**（方案 3） | **100% 原生支持** | 弱网高丢包线路抗拥堵（配 `ports: 20000-50000`） |
| **`Shadowsocks-2022`**（方案 1-3） | **100% 原生支持** | 后端海外住宅家宽落地（配合 `dialer-proxy` 链式接入） |
| **`VLESS + WS + TLS`**（CF 兼容） | **100% 原生支持** | Cloudflare CDN 兜底节点 |
| **`VLESS + XHTTP`**（方案 1-1 / 2） | 暂不推荐 | Xray 专属新传输层，建议用最新版 v2rayN / v2rayNG |

---

## 二、快速上手（两步完成）

### 方式 1：自建节点直接导入 [`config.yaml`](config.yaml)
1. 下载 [`config.yaml`](config.yaml)；
2. 修改 `proxies:` 段落中的占位信息（服务器 IP、端口、UUID、REALITY `public-key` / `short-id` 或家宽 `SS-2022` 密钥）；
3. 拖入 **Clash Verge Rev / Mihomo Party / FlClash** 启用即可。

### 方式 2：已有订阅一键增强（使用 [`override.js`](override.js)）
1. 在 **Clash Verge Rev -> 订阅 -> 右键「编辑扩展脚本」**（或 Mihomo Party -> 覆写 -> 新建 JS 覆写）；
2. 将 [`override.js`](override.js) 内容完整粘贴并保存启用；
3. 自动为现有订阅注入：**零泄露 Fake-IP DNS + 官方 `mrs` 规则集 + AI 专属分组 + 可选 QUIC 拦截**。

---

## 三、核心架构解析：`dialer-proxy` 链式中转家宽

相比服务端写死固定中转，Mihomo 客户端自带的 **`dialer-proxy`** 可以让你在本地自由切换“哪台优化机中转哪台家宽”：

```yaml
proxies:
  # 1. 前置机房优化机（CN2 GIA / 9929 / CMIN2）
  - name: "Relay-CN2-Vision"
    type: vless
    server: 198.51.100.10
    port: 443
    uuid: 00000000-0000-0000-0000-000000000001
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: addons.mozilla.org
    reality-opts:
      public-key: <你的REALITY公钥>
      short-id: <你的ShortID>
    client-fingerprint: chrome

  # 2. 后端海外住宅家宽（通过 dialer-proxy 经由前置机中转连入！）
  - name: "Residential-ATT-Landing"
    type: ss
    server: 12.34.56.78
    port: 30001
    cipher: 2022-blake3-aes-256-gcm
    password: <家宽机生成的32字节Base64密钥>
    udp: true
    dialer-proxy: "🚀 前置优化机"   # 关键一行：直接指向前置策略组，前置故障时自动切备用机！
```

> **为什么指向策略组 `"🚀 前置优化机"` 而不是单个节点？**  
> 当你的前置机有 2 台（如 DMIT + 备用 CN2/9929）时，`dialer-proxy` 指向 `fallback` / `url-test` 策略组即可实现**前置线路自动容灾切换，而后端住宅出口 IP 纹丝不动（0 IP 漂移）**！

---

## 四、零 DNS 泄露与 TUN 模式避坑清单

1. **杜绝住宅 IP 画像穿帮（DNS 泄露）**：
   - `config.yaml` 默认启用 **`enhanced-mode: fake-ip`** + **`respect-rules: true`**；
   - 节点域名解析独立走 `proxy-server-nameserver`（国内高速 DoH/UDP），海外业务域名全部交由代理出口远端解析，绝不让大陆 ISP DNS 抢答。
2. **Windows / macOS / 软路由 TUN 模式防回环**：
   - Windows 推荐 `stack: system`（性能最高、WFP 驱动级防回环）或 `mixed`，开启 `auto-route: true`、`strict-route: true`、`auto-detect-interface: true`；
   - **切勿同时开启两个代理软件的 TUN**（如同时开 v2rayN TUN 和 Clash TUN 会直接引发路由死循环）。
3. **保护家宽光猫状态表（拒绝 UDP 443 QUIC）**：
   - `config.yaml` 内置 `AND,((NETWORK,UDP),(DST-PORT,443)),REJECT`（默认注释，使用 AT&T / Spectrum 驻地光猫家宽时取消注释即可），浏览器会自动无感回退 `TCP 443`，延迟更稳且不打满光猫 `8,192` 连接表。

---

> **免责声明**：本项目及配置模板仅供网络分流研究、Linux/软路由调优与合规技术学习使用，请遵守当地法律法规。
