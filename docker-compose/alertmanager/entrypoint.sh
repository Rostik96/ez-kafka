#!/bin/sh
set -e

cfg=/tmp/alertmanager.yml

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
  sed \
    -e "s|__TELEGRAM_BOT_TOKEN__|$TELEGRAM_BOT_TOKEN|g" \
    -e "s|__TELEGRAM_CHAT_ID__|$TELEGRAM_CHAT_ID|g" \
    /etc/alertmanager/alertmanager.yml > "$cfg"
else
  cat > "$cfg" <<'EOF'
global:
  resolve_timeout: 1m

route:
  receiver: telegram
  group_by: [alertname]
  group_wait: 5s
  group_interval: 15s
  repeat_interval: 1h

receivers:
  - name: telegram

inhibit_rules:
  - source_matchers:
      - alertname = TargetDown
    target_matchers:
      - alertname = KafkaConsumerDisconnected
    equal:
      - job
EOF
  echo "TELEGRAM_BOT_TOKEN/CHAT_ID not set; alerts stay in Prometheus/Alertmanager UI only" >&2
fi

exec /bin/alertmanager \
  --config.file="$cfg" \
  --storage.path=/alertmanager \
  --web.listen-address=:9093
