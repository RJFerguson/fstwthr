# fstwthr

**Plain-text weather for humans and agents.**

A free, keyless weather service at [fstwthr.com](https://fstwthr.com).
Same canonical forecast in seven formats — modern HTML, minimal HTML,
plain text, JSON, YAML, wttr.in-style one-liners, and
[Model Context Protocol](https://modelcontextprotocol.io) for AI
agents.

No API keys. No accounts. No advertising. No third-party aggregators.
Just government weather data ([NOAA](https://www.weather.gov) in the
US, [MET Norway](https://api.met.no) globally) shaped into a clean,
fast surface.

---

## Try it

```bash
curl fstwthr.com/boulder
curl json.fstwthr.com/tokyo
curl 'fstwthr.com/london?units=metric&voice=snark'
curl 'fstwthr.com/denver?format=3'        # wttr.in-style one-liner
curl fstwthr.com/80302                    # any US ZIP code
curl -o radar.png fstwthr.com/boulder/radar.png   # current radar tile (US)
```

Sample plain-text output (`curl fstwthr.com/boulder`):

```
BOULDER, CO
────────────────────────────────────────

Sunny and 75° in Boulder. 11° warmer
than yesterday. Cooling to 50° overnight.
Tomorrow: thunderstorms, high 83°. Good
day to be outside — sunny, high 75°.

NOW
  75°F  Clear
  feels 75°F
  wind 4 mph S
  humidity 38%
  dew point 48°F
  pressure 30.2 inHg

7-DAY
────────────────────────────────────────
Sat   83° /  54°  Mostly Sunny then Showers And Thunderstorms
Sun   86° /  56°  Sunny
Mon   84° /  56°  Mostly Sunny then Chance Showers And Thunderstorms
…

SUN
────────────────────────────────────────
sunrise  5:38 AM
sunset   8:16 PM
moon     Waxing Crescent 40%
```

More samples: [`examples/outputs/`](./examples/outputs/).

---

## Formats

| Host                    | Browser default   | curl / agents  |
| ----------------------- | ----------------- | -------------- |
| `fstwthr.com`           | Modern HTML       | Plain text     |
| `min.fstwthr.com`       | Minimal HTML      | Plain text     |
| `json.fstwthr.com`      | JSON              | JSON           |
| `api.fstwthr.com`       | JSON (alias)      | JSON           |
| `yaml.fstwthr.com`      | YAML (inline)     | YAML           |
| `mcp.fstwthr.com/mcp`   | Model Context Protocol (StreamableHTTP) ||

Query params layer on top of every format:

- `?units=metric` — °C / kph / hPa output.
- `?voice=plain|snark|hype` — stylistic dial on the natural-language
  summary line.
- `?format=1..4` — wttr.in-compatible compact one-liners
  (`?format=3` → `Boulder, CO: ☀️ +75°F`).
- `?fmt=text|json|yaml|min|modern` — explicit format override (wins
  over host + UA).

---

## Location lookup

```
/denver, /boulder, /new-york      US cities
/80302, /10001, /02134            US ZIP codes (33.8k ZCTAs)
/london, /paris, /tokyo, /sydney  globally famous cities
/portland,me  vs  /portland,or    US state disambiguation
/london,gb    vs  /london,ky      country / state disambiguation
/anything-else                    Nominatim long tail (KV-cached)
```

Tier-1 disambiguation uses population — `/london` resolves to London,
GB (~9M) over London, KY (~7k). `/london,ky` forces the US town.

---

## Radar

Current-frame precipitation radar as a PNG, one tile per US city:

```bash
curl -o boulder.png fstwthr.com/boulder/radar.png
```

| | |
| --- | --- |
| URL | `/<slug>/radar.png` — same slug resolution as the text endpoints |
| Image | 250×250 PNG, NWS-style intensity colormap (light green → yellow → red), a ~250 km square (±125 km) centered on the city at MRMS's 1 km resolution |
| Source | NOAA [MRMS](https://www.nssl.noaa.gov/projects/mrms/) `PrecipRate` (mm/hr), refreshed every 5 minutes |
| Freshness | `X-Radar-Ts` response header stamps the source frame time; edge-cached `s-maxage=300, stale-while-revalidate=3600` like every other surface |
| Coverage | US only — non-US slugs return `404` (MRMS has no global data) |

Precipitation below 0.1 mm/hr renders fully transparent, so a dry city
returns an essentially blank tile — that's expected, not an error.
Overlay it on your own basemap, or just eyeball it:
`fstwthr.com/<your-city>/radar.png`.

---

## For AI agents

Wire fstwthr's MCP server into any client that supports Model Context
Protocol. The server exposes **5 tools, 3 resources, and 3 prompt
templates** over the same canonical forecast that powers every other
format.

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "fstwthr": { "url": "https://mcp.fstwthr.com/mcp" }
  }
}
```

Restart Claude Desktop. The prompts (`check_weather`, `best_window`,
`travel_planning`) land in the prompt picker; the 5 tools are
available to any conversation.

### Other clients

[`INSTALL.md`](./INSTALL.md) has copy-paste config snippets for Cursor,
Continue, Cline, Zed, VS Code, and the MCP Inspector.

### Tools

| Tool | Purpose |
| --- | --- |
| `get_weather(location, units?)` | Current conditions + short forecast. |
| `get_forecast(location, days?, units?)` | 7-day forecast with hi/lo, sunrise/sunset, moon phase. |
| `get_alerts(location)` | Active severe-weather alerts (US-only; NOAA-sourced). |
| `get_best_window(location, activity?, units?)` | "Good time to go outside" recommendation across today/tomorrow. |
| `get_nowcast(location)` | Radar-derived current precipitation (US-only). |

### Resources

| URI | Content |
| --- | --- |
| `fstwthr://locations/popular` | Hand-curated popular cities (US + global). |
| `fstwthr://schemas/forecast` | JSON Schema for the canonical Forecast type. |
| `fstwthr://about` | Project description + attribution. |

For machine-readable index see [`/llms.txt`](https://fstwthr.com/llms.txt)
(short) and [`/llms-full.txt`](https://fstwthr.com/llms-full.txt) (long).

---

## Architecture

Single Cloudflare Worker, ~1 MB gzip including 50k embedded US places
+ ZIP codes. Every URL is edge-cached (5 min fresh + 1 hour
stale-while-revalidate); upstream provider JSON is KV-cached
separately so the hot path is sub-50 ms globally.

```
  request
     │
     ▼
  format negotiation   ── host + ?fmt= + UA → text / JSON / YAML /
     │                                        modern HTML / min HTML /
     │                                        MCP / compact one-liner
     ▼
  edge response cache  ── synthetic cache key over
     │                    (URL × format × units × voice × compact)
     ▼
  slug resolution      ── 5-tier cascade:
     │                    ZIP table → CITIES → US Census Places →
     │                    KV-cached Nominatim → live Nominatim
     ▼
  KV upstream cache    ── 'noaa-fc:{lat},{lon}' or 'metno-fc:{lat},{lon}'
     │
     ▼
  provider router      ── country=='US' → NOAA, else → MET Norway
     │
     ▼
  canonical Forecast   ── single type all renderers consume
     │
     ▼
  renderer             ── HTML / text / JSON / YAML / MCP tool / one-liner
```

A sibling Cloudflare Container parses [MRMS](https://www.nssl.noaa.gov/projects/mrms/)
radar tiles every five minutes. It writes per-gridpoint
"rain-on-radar" records into shared KV — surfaced by the main worker
as a one-sentence clause in the natural-language summary — and renders
the per-city radar PNGs served at `/<slug>/radar.png` (see
[Radar](#radar)) into a private R2 bucket the worker proxies.

---

## Data sources

- **NOAA / National Weather Service** — US forecast, alerts,
  real-time station observations, and radar (MRMS).
- **MET Norway / Norwegian Meteorological Institute** — global
  forecast fallback.
- **OpenStreetMap Foundation / Nominatim** — geocoding long tail.
- **US Census Bureau Gazetteer** — embedded places + ZIP-code data.

All free for non-commercial use. fstwthr passes attribution through
its `source` field and surfaces no third-party tracking. The
hosted service uses identifying `User-Agent` headers on all
upstream calls per each provider's policy.

---

## FAQ

**Is the source code public?**
No — only this docs repo is public. The hosted service at
[fstwthr.com](https://fstwthr.com) is the canonical implementation.
The MCP / HTTP / format contracts documented here are stable.

**Can I self-host?**
Not as-shipped, but every upstream is keyless and the canonical
Forecast shape is documented in [`/llms-full.txt`](https://fstwthr.com/llms-full.txt).
You can build a compatible service from the same data sources.

**Is it free?**
Yes, for non-commercial use. The hosted service runs on Cloudflare's
paid tier and is funded informally; please don't hammer it. Wrap
your agent calls in reasonable backoff; we won't rate-limit
aggressively unless we have to.

**Can I help / contribute?**
File an issue here for bug reports, feature requests, or peering
interest. We're not accepting source PRs since the codebase is
private, but real-world bug reports (especially around location
resolution or unusual MCP clients) are very welcome.

**What's the license?**
This docs repo is MIT. The hosted service is not open source.

---

## Contact

[Open an issue](https://github.com/RJFerguson/fstwthr/issues) for bug
reports, feature requests, peering interest, or anything else. Real-
world reports (especially around location resolution and unusual MCP
client behaviors) are very welcome.
