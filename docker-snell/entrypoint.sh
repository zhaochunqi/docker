#!/bin/sh
set -e

# 挂载了完整配置文件时直接使用(逃生通道,绕过下面的 env 模板)
if [ -n "${SNELL_CONF:-}" ]; then
    echo "Using provided config: ${SNELL_CONF}"
    exec snell-server -c "${SNELL_CONF}"
fi

PORT="${PORT:-8388}"
# v6 的 mode 三选一:default(混淆+AES)/ unshaped(仅 AES,约 +10% 吞吐)/ unsafe-raw(仅限内网)
# 客户端与服务器端 mode 必须一致
MODE="${MODE:-default}"
# v6 用 dns-ip-preference 取代了旧的 ipv6 开关
DNS_IP_PREFERENCE="${DNS_IP_PREFERENCE:-default}"
# 默认单栈;双栈传 LISTEN="0.0.0.0:8388,[::]:8388"
LISTEN="${LISTEN:-0.0.0.0:${PORT}}"

if [ -z "${PSK:-}" ]; then
    # 官方建议 32 字符随机 PSK;不传则每次启动随机生成,重启即换,生产必须显式传
    PSK=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
    echo "WARN: PSK not set, generated ephemeral PSK: ${PSK}"
fi

CONF=/etc/snell-server.conf
cat > "${CONF}" <<EOF
[snell-server]
listen = ${LISTEN}
psk = ${PSK}
mode = ${MODE}
dns-ip-preference = ${DNS_IP_PREFERENCE}
EOF

echo "snell-server starting: listen=${LISTEN} mode=${MODE} dns-ip-preference=${DNS_IP_PREFERENCE}"
exec snell-server -c "${CONF}"
