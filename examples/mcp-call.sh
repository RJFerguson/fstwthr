#!/usr/bin/env bash
# fstwthr — raw MCP smoke test against mcp.fstwthr.com.
# Useful for diagnostics when an MCP client isn't behaving and you
# want to confirm the server itself is healthy.

set -euo pipefail

MCP_URL="${MCP_URL:-https://mcp.fstwthr.com/mcp}"

post() {
  curl -sS -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    "$@"
}

echo "=== 1. initialize ==="
SID=$(curl -sS -D - -o /dev/null -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-call.sh","version":"1.0"}}}' \
  | grep -iE '^mcp-session-id:' \
  | sed -E 's/^[Mm]cp-[Ss]ession-[Ii]d: *//' \
  | tr -d '\r\n')
echo "Session: $SID"

echo
echo "=== 2. initialized notification ==="
post -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'

echo
echo "=== 3. tools/list ==="
post -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | sed 's/^data: //' | python3 -c "
import sys, json
for line in sys.stdin:
  line = line.strip()
  if not line.startswith('{'): continue
  data = json.loads(line)
  for t in data['result']['tools']:
    print(f\"- {t['name']}: {t.get('description','')[:70]}\")
"

echo
echo "=== 4. resources/list ==="
post -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":3,"method":"resources/list"}' \
  | sed 's/^data: //' | python3 -c "
import sys, json
for line in sys.stdin:
  line = line.strip()
  if not line.startswith('{'): continue
  data = json.loads(line)
  for r in data['result']['resources']:
    print(f\"- {r['uri']}: {r.get('description','')[:70]}\")
"

echo
echo "=== 5. prompts/list ==="
post -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":4,"method":"prompts/list"}' \
  | sed 's/^data: //' | python3 -c "
import sys, json
for line in sys.stdin:
  line = line.strip()
  if not line.startswith('{'): continue
  data = json.loads(line)
  for p in data['result']['prompts']:
    print(f\"- {p['name']}: {p.get('description','')[:70]}\")
"

echo
echo "=== 6. tools/call get_weather(boulder) ==="
post -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"get_weather","arguments":{"location":"boulder"}}}' \
  | sed 's/^data: //' | python3 -c "
import sys, json
for line in sys.stdin:
  line = line.strip()
  if not line.startswith('{'): continue
  data = json.loads(line)
  r = data['result']
  print('TEXT:', r['content'][0]['text'])
  sc = r.get('structuredContent', {})
  print('LOC: ', sc.get('location', {}).get('name'), '/', sc.get('location', {}).get('region'))
  obs = sc.get('observed', {})
  print('OBS: ', f\"{obs.get('temp')}° {obs.get('conditionText')}\")
  print('NOW: ', sc.get('nowcast'))
"

echo
echo "Done."
