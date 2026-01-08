#!/usr/bin/env bash
set -euo pipefail; set +H
umask 022

ROOT="/var/www/dalmia/public"
BASE_DIR="$ROOT/knowledge/india/states"
PAGES_DIR="$BASE_DIR/pages"
mkdir -p "$PAGES_DIR"

python3 <<'PY'
import html, pathlib

ROOT = pathlib.Path("/var/www/dalmia/public")
BASE_DIR = ROOT / "knowledge/india/states"
PAGES_DIR = BASE_DIR / "pages"
PAGES_DIR.mkdir(parents=True, exist_ok=True)

states = [
  ("andhra-pradesh", "Andhra Pradesh", "state"),
  ("arunachal-pradesh", "Arunachal Pradesh", "state"),
  ("assam", "Assam", "state"),
  ("bihar", "Bihar", "state"),
  ("chhattisgarh", "Chhattisgarh", "state"),
  ("goa", "Goa", "state"),
  ("gujarat", "Gujarat", "state"),
  ("haryana", "Haryana", "state"),
  ("himachal-pradesh", "Himachal Pradesh", "state"),
  ("jharkhand", "Jharkhand", "state"),
  ("karnataka", "Karnataka", "state"),
  ("kerala", "Kerala", "state"),
  ("madhya-pradesh", "Madhya Pradesh", "state"),
  ("maharashtra", "Maharashtra", "state"),
  ("manipur", "Manipur", "state"),
  ("meghalaya", "Meghalaya", "state"),
  ("mizoram", "Mizoram", "state"),
  ("nagaland", "Nagaland", "state"),
  ("odisha", "Odisha", "state"),
  ("punjab", "Punjab", "state"),
  ("rajasthan", "Rajasthan", "state"),
  ("sikkim", "Sikkim", "state"),
  ("tamil-nadu", "Tamil Nadu", "state"),
  ("telangana", "Telangana", "state"),
  ("tripura", "Tripura", "state"),
  ("uttar-pradesh", "Uttar Pradesh", "state"),
  ("uttarakhand", "Uttarakhand", "state"),
  ("west-bengal", "West Bengal", "state"),
  ("andaman-nicobar", "Andaman and Nicobar Islands", "ut"),
  ("chandigarh", "Chandigarh", "ut"),
  ("dadra-nagar-haveli-daman-diu", "Dadra and Nagar Haveli and Daman and Diu", "ut"),
  ("delhi", "Delhi (NCT)", "ut"),
  ("jammu-kashmir", "Jammu and Kashmir", "ut"),
  ("ladakh", "Ladakh", "ut"),
  ("lakshadweep", "Lakshadweep", "ut"),
  ("puducherry", "Puducherry", "ut"),
]

def page_shell(title, desc, canon, h1, lead, body):
  return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(desc)}"/>
<link rel="canonical" href="{html.escape(canon)}"/>
<link rel="stylesheet" href="/assets/css/janu-theme.css"/>
</head>
<body>
<!--#include virtual="/includes/header.php" -->
<main class="kb kb-wrap">
<header class="kb-hero"><div class="kb-hero-text">
  <h1>{html.escape(h1)}</h1>
  <p class="kb-lead">{html.escape(lead)}</p>
</div></header>
{body}
</main>
<!--#include virtual="/includes/footer.php" -->
</body></html>"""

def starter_body(badge):
  return f"""
<section class="kb-card">
  <h2>Starter hub</h2>
  <p><span class="kb-tag">{html.escape(badge)}</span> Starter page for phased expansion in Project JANU.</p>
</section>
"""

lis=[]
for slug,name,kind in states:
  badge = "State" if kind=="state" else "Union Territory"
  lis.append(f'<li><a href="/knowledge/india/states/pages/{slug}.html">{html.escape(name)}</a> <span class="kb-tag">{html.escape(badge)}</span></li>')
list_html="\\n".join(lis)

index_body=f"""
<section class="kb-card">
  <h2>States & Union Territories</h2>
  <ul>{list_html}</ul>
</section>
"""

(BASE_DIR / "index.html").write_text(page_shell(
  "India States & Union Territories Directory | Dalmia Computers",
  "India directory: all states and union territories with starter hub pages (JANU phases).",
  "https://dalmiacomputers.in/knowledge/india/states/index.html",
  "India — States & Union Territories",
  "State-first build → districts → blocks → villages (PIN).",
  index_body
), encoding="utf-8")

for slug,name,kind in states:
  badge="State" if kind=="state" else "Union Territory"
  canon=f"https://dalmiacomputers.in/knowledge/india/states/pages/{slug}.html"
  (PAGES_DIR / f"{slug}.html").write_text(page_shell(
    f"{name} | India Knowledge Hub | Dalmia Computers",
    f"India Knowledge Hub: {name}. Starter page for phased expansion in Project JANU.",
    canon,
    name,
    f"{badge} starter hub: phased expansion.",
    starter_body(badge)
  ), encoding="utf-8")

print("OK: index:", str(BASE_DIR / "index.html"))
print("OK: pages:", len(states))
PY
