/**
 * CatEacc Mihomo (Clash Verge Rev / Mihomo Party) 全局扩展覆写脚本
 * 仓库: https://github.com/CatEacc/vps-clash-runbook
 * 功能: 给任意现有订阅自动注入零泄露 Fake-IP DNS + 官方 mrs 规则集 + AI 专属分流 + 可选禁 QUIC
 */

// 设为 true 可全局拒绝 UDP 443 (QUIC)，保护驻地家宽光猫状态表，浏览器无感回退 TCP 443
const BLOCK_QUIC = false;

function main(config) {
  // 1. 底层并发与嗅探优化（Mihomo v1.19+ 已移除 global-client-fingerprint，改为逐节点自动补全 client-fingerprint）
  config["unified-delay"] = true;
  config["tcp-concurrent"] = true;
  config["find-process-mode"] = "strict";
  if (Array.isArray(config.proxies)) {
    config.proxies.forEach((p) => {
      if (["vless", "vmess", "trojan"].includes(p.type) && !p["client-fingerprint"]) {
        p["client-fingerprint"] = "chrome";
      }
    });
  }

  config.sniffer = {
    enable: true,
    "force-dns-mapping": true,
    "parse-pure-ip": true,
    "override-destination": false,
    sniff: {
      HTTP: { ports: [80, "8080-8880"], "override-destination": true },
      TLS: { ports: [443, 8443] },
      QUIC: { ports: [443, 8443] },
    },
  };

  // 2. 零泄露 Fake-IP DNS 注入（仅监听 127.0.0.1 避免暴露公网/局域网 DNS 端口）
  config.dns = {
    enable: true,
    listen: "127.0.0.1:1053",
    ipv6: false,
    "respect-rules": true,
    "enhanced-mode": "fake-ip",
    "fake-ip-range": "198.18.0.1/16",
    "fake-ip-filter": [
      "*.lan",
      "*.local",
      "+.msftconnecttest.com",
      "+.msftncsi.com",
      "localhost.ptlogin2.qq.com",
      "time.*.com",
      "ntp.*.com",
    ],
    "default-nameserver": ["223.5.5.5", "119.29.29.29"],
    "proxy-server-nameserver": [
      "https://doh.pub/dns-query",
      "https://dns.alidns.com/dns-query",
    ],
    nameserver: [
      "https://1.1.1.1/dns-query",
      "https://dns.google/dns-query",
    ],
    "nameserver-policy": {
      "rule-set:cn_domain,private_domain": [
        "https://doh.pub/dns-query",
        "https://dns.alidns.com/dns-query",
      ],
    },
  };

  // 3. 挂载官方 mrs 二进制规则集
  const domainCommon = { type: "http", interval: 86400, behavior: "domain", format: "mrs" };
  const ipCommon = { type: "http", interval: 86400, behavior: "ipcidr", format: "mrs" };

  config["rule-providers"] = {
    ...(config["rule-providers"] || {}),
    private_domain: { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/private.mrs" },
    private_ip:     { ...ipCommon,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/private.mrs" },
    cn_domain:      { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/cn.mrs" },
    cn_ip:          { ...ipCommon,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/cn.mrs" },
    openai:         { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/openai.mrs" },
    anthropic:      { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/anthropic.mrs" },
    gemini:         { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/google-gemini.mrs" },
    netflix:        { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/netflix.mrs" },
    tiktok:         { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/tiktok.mrs" },
    telegram_ip:    { ...ipCommon,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/telegram.mrs" },
  };

  // 4. 提取节点并严格隔离【直连/前置机】与【dialer-proxy 链式落地机】，避免混跑与破坏链式出口隔离
  const proxies = Array.isArray(config.proxies) ? config.proxies : [];
  const directProxies = proxies.filter((p) => !p["dialer-proxy"]).map((p) => p.name);
  const chainProxies = proxies.filter((p) => Boolean(p["dialer-proxy"])).map((p) => p.name);

  if (proxies.length > 0) {
    const frontList = directProxies.length > 0 ? directProxies : proxies.map((p) => p.name);
    const groups = [
      { name: "🚀 前置优化机", type: "select", proxies: ["⚡ 自动优选", ...frontList] },
      { name: "🌐 默认代理", type: "select", proxies: ["🚀 前置优化机", "⚡ 自动优选", ...frontList, "DIRECT"] },
      { name: "⚡ 自动优选", type: "url-test", url: "https://www.gstatic.com/generate_204", interval: 300, tolerance: 50, proxies: frontList },
    ];

    if (chainProxies.length > 0) {
      groups.splice(
        1,
        0,
        { name: "🏠 纯净家宽出口", type: "select", proxies: [...chainProxies, "🚀 前置优化机"] },
        { name: "🤖 AI 平台", type: "select", proxies: ["🏠 纯净家宽出口", ...chainProxies, "🚀 前置优化机"] },
        { name: "🎬 海外流媒体", type: "select", proxies: ["🏠 纯净家宽出口", ...chainProxies, "🚀 前置优化机"] }
      );
    } else {
      groups.push(
        { name: "🤖 AI 平台", type: "select", proxies: [...frontList, "🌐 默认代理"] },
        { name: "🎬 海外流媒体", type: "select", proxies: [...frontList, "🌐 默认代理"] }
      );
    }
    groups.push({ name: "🐟 漏网之鱼", type: "select", proxies: ["🌐 默认代理", "DIRECT"] });
    config["proxy-groups"] = groups;

    const rules = [
      "RULE-SET,private_domain,DIRECT",
      "RULE-SET,private_ip,DIRECT,no-resolve",
      "RULE-SET,openai,🤖 AI 平台",
      "RULE-SET,anthropic,🤖 AI 平台",
      "RULE-SET,gemini,🤖 AI 平台",
      "RULE-SET,netflix,🎬 海外流媒体",
      "RULE-SET,tiktok,🎬 海外流媒体",
      "RULE-SET,telegram_ip,🌐 默认代理,no-resolve",
      "RULE-SET,cn_domain,DIRECT",
      "RULE-SET,cn_ip,DIRECT",
      "MATCH,🐟 漏网之鱼",
    ];
    if (BLOCK_QUIC) {
      rules.unshift("AND,((NETWORK,UDP),(DST-PORT,443)),REJECT");
    }
    config.rules = rules;
  }

  return config;
}
