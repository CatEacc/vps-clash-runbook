/**
 * CatEacc Mihomo (Clash Verge Rev / Mihomo Party) 全局扩展覆写脚本
 * 仓库: https://github.com/CatEacc/vps-clash-runbook
 * 功能: 给任意现有订阅（兼容 proxies 与 proxy-providers）自动注入零泄露 Fake-IP DNS + 官方 mrs 规则集 + AI/流媒体专属分流 + 可选禁 QUIC
 */

// 设为 true 可全局拒绝 UDP 443 (QUIC)，保护驻地家宽光猫状态表，浏览器无感回退 TCP 443
const BLOCK_QUIC = false;

function main(config) {
  // 1. 底层并发、禁 IPv6 防泄漏与嗅探优化（Mihomo v1.19+ 逐节点补全 client-fingerprint）
  config.ipv6 = false;
  config["unified-delay"] = true;
  config["tcp-concurrent"] = true;
  config["find-process-mode"] = "strict";
  config.profile = {
    ...(config.profile || {}),
    "store-selected": true,
    "store-fake-ip": true,
  };

  if (Array.isArray(config.proxies)) {
    config.proxies.forEach((p) => {
      if (p && typeof p === "object" && ["vless", "vmess", "trojan"].includes(p.type) && !p["client-fingerprint"]) {
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

  // 2. 零泄露 Fake-IP DNS 注入（default-nameserver 纯 IP 自举 DoH，仅监听 127.0.0.1）
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
      "*.arpa",
      "+.msftconnecttest.com",
      "+.msftncsi.com",
      "connectivitycheck.gstatic.com",
      "captive.apple.com",
      "detectportal.firefox.com",
      "localhost.ptlogin2.qq.com",
      "localhost.sec.qq.com",
      "time.*.com",
      "time.*.gov",
      "time.*.apple.com",
      "ntp.*.com",
      "+.pool.ntp.org",
      "+.stun.*.*",
      "+.stun.*.*.*",
      "+.stun.*.*.*.*",
    ],
    "default-nameserver": ["223.5.5.5", "119.29.29.29"],
    "proxy-server-nameserver": [
      "https://doh.pub/dns-query",
      "https://dns.alidns.com/dns-query",
    ],
    nameserver: [
      "https://1.1.1.1/dns-query",
      "https://8.8.8.8/dns-query",
    ],
    "nameserver-policy": {
      "rule-set:cn_domain,private_domain": [
        "https://doh.pub/dns-query",
        "https://dns.alidns.com/dns-query",
      ],
    },
  };

  // 3. 提取节点（兼容内联 proxies 与外部 proxy-providers）并严格隔离【直连/前置机】与【dialer-proxy 链式落地机】
  const proxies = Array.isArray(config.proxies)
    ? config.proxies.filter((p) => p && typeof p === "object" && p.name)
    : [];
  const providersObj = config["proxy-providers"] && typeof config["proxy-providers"] === "object"
    ? config["proxy-providers"]
    : {};
  const providerNames = Object.keys(providersObj);

  if (proxies.length > 0 || providerNames.length > 0) {
    // 防止上游订阅节点名与本脚本生成的策略组重名触发 Mihomo duplicate group name 报错
    const reservedGroups = new Set([
      "🚀 前置优化机",
      "🏠 纯净家宽出口",
      "🤖 AI 平台",
      "🎬 海外流媒体",
      "🌐 默认代理",
      "⚡ 自动优选",
      "🐟 漏网之鱼",
    ]);
    const usedNames = new Set(proxies.map((p) => p.name));
    const renamedMap = new Map();
    proxies.forEach((p) => {
      if (reservedGroups.has(p.name)) {
        let cand = `${p.name}-节点`;
        let seq = 2;
        while (usedNames.has(cand) || reservedGroups.has(cand)) {
          cand = `${p.name}-节点${seq++}`;
        }
        renamedMap.set(p.name, cand);
        usedNames.add(cand);
        p.name = cand;
      }
    });
    if (renamedMap.size > 0) {
      proxies.forEach((p) => {
        if (p["dialer-proxy"] && renamedMap.has(p["dialer-proxy"])) {
          p["dialer-proxy"] = renamedMap.get(p["dialer-proxy"]);
        }
      });
      Object.values(providersObj).forEach((pv) => {
        if (pv && typeof pv === "object") {
          if (pv.proxy && renamedMap.has(pv.proxy)) pv.proxy = renamedMap.get(pv.proxy);
          if (pv.override && pv.override["dialer-proxy"] && renamedMap.has(pv.override["dialer-proxy"])) {
            pv.override["dialer-proxy"] = renamedMap.get(pv.override["dialer-proxy"]);
          }
        }
      });
    }

    const domainCommon = { type: "http", interval: 86400, behavior: "domain", format: "mrs", proxy: "🚀 前置优化机" };
    const ipCommon = { type: "http", interval: 86400, behavior: "ipcidr", format: "mrs", proxy: "🚀 前置优化机" };
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
      youtube:        { ...domainCommon, url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/youtube.mrs" },
      telegram_ip:    { ...ipCommon,     url: "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip/telegram.mrs" },
    };

    const proxyNameSet = new Set(proxies.map((p) => p.name));
    const oldGroups = Array.isArray(config["proxy-groups"]) ? config["proxy-groups"] : [];
    const oldGroupMap = new Map(oldGroups.filter((g) => g && g.name).map((g) => [g.name, g]));

    // 区分直连前置 provider 与带 override.dialer-proxy 的链式落地 provider，防止前置组发生自环
    const directProviderNames = providerNames.filter((k) => {
      const pv = providersObj[k];
      return !(pv && typeof pv === "object" && pv.override && pv.override["dialer-proxy"]);
    });
    const chainProviderNames = providerNames.filter((k) => {
      const pv = providersObj[k];
      return Boolean(pv && typeof pv === "object" && pv.override && pv.override["dialer-proxy"]);
    });
    const frontUseAttr = directProviderNames.length > 0 ? { use: directProviderNames } : {};
    const chainUseAttr = chainProviderNames.length > 0 ? { use: chainProviderNames } : {};

    // 若链式节点的 dialer-proxy 指向了不存在的组或节点，自动修正为前置优化机防 Mihomo 启动报错
    proxies.forEach((p) => {
      const dp = p["dialer-proxy"];
      if (dp && !proxyNameSet.has(dp) && !reservedGroups.has(dp) && !oldGroupMap.has(dp) && dp !== "DIRECT") {
        p["dialer-proxy"] = "🚀 前置优化机";
      }
    });

    const directProxies = proxies.filter((p) => !p["dialer-proxy"]).map((p) => p.name);
    const chainProxies = proxies.filter((p) => Boolean(p["dialer-proxy"])).map((p) => p.name);
    const chainProxySet = new Set(chainProxies);
    const chainProviderSet = new Set(chainProviderNames);
    const hasChain = chainProxies.length > 0 || chainProviderNames.length > 0;
    const frontList = directProxies;
    const fallbackFront = frontList.length === 0 && directProviderNames.length === 0 ? ["DIRECT"] : [];

    const groups = [
      {
        name: "🚀 前置优化机",
        type: "select",
        proxies: ["⚡ 自动优选", ...frontList, ...fallbackFront],
        ...frontUseAttr,
      },
      {
        name: "🌐 默认代理",
        type: "select",
        proxies: ["🚀 前置优化机", ...(hasChain ? ["🏠 纯净家宽出口"] : []), "⚡ 自动优选", ...frontList, "DIRECT"],
        ...frontUseAttr,
      },
      {
        name: "⚡ 自动优选",
        type: "url-test",
        url: "https://www.gstatic.com/generate_204",
        interval: 300,
        tolerance: 50,
        ...(frontList.length > 0 ? { proxies: frontList } : (fallbackFront.length > 0 ? { proxies: fallbackFront } : {})),
        ...frontUseAttr,
      },
    ];

    if (hasChain) {
      groups.splice(
        1,
        0,
        { name: "🏠 纯净家宽出口", type: "select", proxies: [...chainProxies, "🚀 前置优化机"], ...chainUseAttr },
        { name: "🤖 AI 平台", type: "select", proxies: ["🏠 纯净家宽出口", ...chainProxies, "🚀 前置优化机"], ...chainUseAttr },
        { name: "🎬 海外流媒体", type: "select", proxies: ["🏠 纯净家宽出口", ...chainProxies, "🚀 前置优化机"], ...chainUseAttr }
      );
    } else {
      groups.push(
        { name: "🤖 AI 平台", type: "select", proxies: ["🚀 前置优化机", "⚡ 自动优选", ...frontList, ...fallbackFront], ...frontUseAttr },
        { name: "🎬 海外流媒体", type: "select", proxies: ["🚀 前置优化机", "⚡ 自动优选", ...frontList, ...fallbackFront], ...frontUseAttr }
      );
    }
    groups.push({ name: "🐟 漏网之鱼", type: "select", proxies: ["🌐 默认代理", "DIRECT"] });

    // 若订阅中链式节点或 proxy-providers 引用了原订阅的自定义策略组，按 BFS 传递闭包保留并净化子组防循环
    const builtGroupNames = new Set(groups.map((g) => g.name));
    const providerProxyRefs = Object.values(providersObj).flatMap((pv) =>
      pv && typeof pv === "object" ? [pv.proxy, pv.override && pv.override["dialer-proxy"]] : []
    );
    const queue = [...proxies.map((p) => p["dialer-proxy"]), ...providerProxyRefs].filter(Boolean);
    const keptCustomGroups = [];
    while (queue.length > 0) {
      const name = queue.shift();
      if (!name || proxyNameSet.has(name) || builtGroupNames.has(name)) continue;
      const orig = oldGroupMap.get(name);
      if (orig) {
        const cloned = { ...orig };
        builtGroupNames.add(name);
        if (Array.isArray(orig.use)) {
          cloned.use = orig.use.filter((u) => providerNames.includes(u) && !chainProviderSet.has(u));
          if (cloned.use.length === 0) delete cloned.use;
        }
        if (Array.isArray(orig.proxies)) {
          cloned.proxies = orig.proxies
            .map((ref) => (renamedMap.has(ref) ? renamedMap.get(ref) : ref))
            .filter((ref) => ref && !chainProxySet.has(ref) && ref !== name);
          cloned.proxies.forEach((ref) => {
            if (!proxyNameSet.has(ref) && !builtGroupNames.has(ref) && oldGroupMap.has(ref)) {
              queue.push(ref);
            }
          });
        }
        keptCustomGroups.push(cloned);
      }
    }
    const validTargets = new Set([...proxyNameSet, ...builtGroupNames, "DIRECT", "REJECT"]);
    keptCustomGroups.forEach((g) => {
      if (Array.isArray(g.proxies)) {
        g.proxies = g.proxies.filter((ref) => validTargets.has(ref));
      }
      if ((!g.proxies || g.proxies.length === 0) && (!g.use || g.use.length === 0)) {
        g.proxies = ["DIRECT"];
      }
      groups.push(g);
    });

    config["proxy-groups"] = groups;

    const rules = [
      "RULE-SET,private_domain,DIRECT",
      "RULE-SET,private_ip,DIRECT,no-resolve",
      "RULE-SET,openai,🤖 AI 平台",
      "RULE-SET,anthropic,🤖 AI 平台",
      "RULE-SET,gemini,🤖 AI 平台",
      "RULE-SET,netflix,🎬 海外流媒体",
      "RULE-SET,tiktok,🎬 海外流媒体",
      "RULE-SET,youtube,🌐 默认代理",
      "RULE-SET,telegram_ip,🌐 默认代理,no-resolve",
      "RULE-SET,cn_domain,DIRECT",
      "RULE-SET,cn_ip,DIRECT,no-resolve",
      "MATCH,🐟 漏网之鱼",
    ];
    if (BLOCK_QUIC) {
      rules.unshift("AND,((NETWORK,UDP),(DST-PORT,443)),REJECT");
    }
    config.rules = rules;
  }

  return config;
}
