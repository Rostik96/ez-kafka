#!/bin/sh
set -eu

KIBANA="${KIBANA_URL:-http://kibana:5601}"

echo "waiting for Kibana at $KIBANA"
i=0
while [ "$i" -lt 60 ]; do
  if curl -sf "$KIBANA/api/status" >/dev/null; then
    break
  fi
  i=$((i + 1))
  sleep 5
done

if ! curl -sf "$KIBANA/api/status" >/dev/null; then
  echo "Kibana did not become available" >&2
  exit 1
fi

echo "starting Elasticsearch trial license (webhook connector needs it)"
curl -sS -X POST "http://elasticsearch:9200/_license/start_trial?acknowledge=true" || true
echo

echo "waiting until .webhook is licensed"
w=0
while [ "$w" -lt 30 ]; do
  code=$(curl -sS -o /tmp/wh.json -w "%{http_code}" -X POST "$KIBANA/api/actions/connector/telegram/_execute" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"params":{"body":"{\"chat_id\":\"0\",\"text\":\"license-check\"}}"}' || true)
  if grep -q '"status":"ok"' /tmp/wh.json 2>/dev/null; then
    break
  fi
  if grep -q 'chat not found\|Bad Request\|Unauthorized' /tmp/wh.json 2>/dev/null; then
    break
  fi
  w=$((w + 1))
  sleep 3
done

echo "creating data view ez-kafka-logs-*"
curl -sS -o /dev/null -X DELETE "$KIBANA/api/data_views/data_view/logs-ez-kafka" \
  -H "kbn-xsrf: true" || true
curl -sS -o /dev/null -X DELETE "$KIBANA/api/data_views/data_view/ez-kafka-logs" \
  -H "kbn-xsrf: true" || true
dv_code=$(curl -sS -o /tmp/dv-resp.json -w "%{http_code}" -X POST "$KIBANA/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"data_view":{"id":"ez-kafka-logs","title":"ez-kafka-logs-*","name":"ez-kafka logs","timeFieldName":"@timestamp"}}')
echo "data view HTTP $dv_code"
cat /tmp/dv-resp.json
echo

if [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "TELEGRAM_CHAT_ID not set; skip Elasticsearch query rule" >&2
  exit 0
fi

tmp=/tmp/rule.json
sed "s|__TELEGRAM_CHAT_ID__|$TELEGRAM_CHAT_ID|g" /rule.json > "$tmp"

echo "replacing rule spring-error-logs"
curl -sS -o /dev/null -X DELETE "$KIBANA/api/alerting/rule/spring-error-logs" \
  -H "kbn-xsrf: true" || true

code=$(curl -sS -o /tmp/rule-resp.json -w "%{http_code}" -X POST "$KIBANA/api/alerting/rule/spring-error-logs" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  --data-binary @"$tmp")

echo "create rule HTTP $code"
cat /tmp/rule-resp.json
echo
if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
  exit 1
fi
