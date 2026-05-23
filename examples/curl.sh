#!/usr/bin/env bash
# fstwthr — copy-paste smoke tests for the HTTP surfaces.
# Run sections individually or all at once: `bash curl.sh`

set -euo pipefail

echo "=== plain text (curl gets text via UA negotiation) ==="
curl -s fstwthr.com/boulder | head -10

echo
echo "=== explicit format override ==="
curl -s 'fstwthr.com/denver?fmt=json' | head -15

echo
echo "=== JSON subdomain (always JSON regardless of UA) ==="
curl -s json.fstwthr.com/tokyo | head -20

echo
echo "=== YAML subdomain ==="
curl -s yaml.fstwthr.com/paris,fr | head -15

echo
echo "=== metric units + snark voice ==="
curl -s 'fstwthr.com/london?units=metric&voice=snark' | head -10

echo
echo "=== wttr.in-style one-liner ==="
curl -s 'fstwthr.com/sydney?format=3'

echo
echo "=== US ZIP code ==="
curl -s fstwthr.com/80302 | head -10

echo
echo "=== famous-city disambiguation ==="
echo "/london      → London, GB (tier-1 wins by population)"
curl -s 'fstwthr.com/london?format=3'
echo "/london,ky   → London, KY (region disambiguation)"
curl -s 'fstwthr.com/london,ky?format=3'

echo
echo "=== LLM index ==="
curl -s fstwthr.com/llms.txt | head -10

echo
echo "=== robots.txt allows LLM crawlers ==="
curl -s fstwthr.com/robots.txt | head -10

echo
echo "Done."
