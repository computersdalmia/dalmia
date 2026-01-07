sudo bash -lc '
set -euo pipefail; set +H
cd /opt/janu-packs/dalmia
mkdir -p packs

cat > packs/india_states_full_v2.sh <<'"'"'EOF'"'"'
#!/usr/bin/env bash
set -euo pipefail
set +H

ROOT="/var/www/dalmia/public"
IN="$ROOT/knowledge/india"
S="$IN/states"
P="$S/pages"
TS="$(date +%F_%H%M%S)"
BK="/var/backups/janu/india_states_full_v2_$TS"

mkdir -p "$BK" "$S" "$P"
[ -d "$S" ] && cp -a "$S" "$BK/" 2>/dev/null || true

cat > /tmp/janu_india_states.tsv <<'"'"'TSV'"'"'
andhra-pradesh	Andhra Pradesh	state
arunachal-pradesh	Arunachal Pradesh	state
assam	Assam	state
bihar	Bihar	state
chhattisgarh	Chhattisgarh	state
goa	Goa	state
gujarat	Gujarat	state
haryana	Haryana	state
himachal-pradesh	Himachal Pradesh	state
jharkhand	Jharkhand	state
karnataka	Karnataka	state
kerala	Kerala	state
madhya-pradesh	Madhya Pradesh	state
maharashtra	Maharashtra	state
manipur	Manipur	state
meghalaya	Meghalaya	state
mizoram	Mizoram	state
nagaland	Nagaland	state
odisha	Odisha	state
punjab	Punjab	state
rajasthan	Rajasthan	state
sikkim	Sikkim	state
tamil-nadu	Tamil Nadu	state
telangana	Telangana	state
tripura	Tripura	state
uttar-pradesh	Uttar Pradesh	state
uttarakhand	Uttarakhand	state
west-bengal	West Bengal	state
andaman-nicobar-islands	Andaman & Nicobar Islands	ut
chandigarh	Chandigarh	ut
dadra-nagar-haveli-daman-diu	Dadra & Nagar Haveli and Daman & Diu	ut
delhi	Delhi (NCT)	ut
jammu-kashmir	Jammu & Kashmir	ut
ladakh	Ladakh	ut
lakshadweep	Lakshadweep	ut
puducherry	Puducherry	ut
TSV

python3 - <<'"'"'PY'"'"'
import os, datetime, html

root="/var/www/dalmia/public"
IN=os.path.join(root,"knowledge","india")
S=os.path.join(IN,"states")
P=os.path.join(S,"pages")
os.makedirs(P, exist_ok=True)

today=datetime.date.today().isoformat()

items=[]
with open("/tmp/janu_india_states.tsv","r",encoding="utf-8") as f:
    for line in f:
        line=line.strip()
        if not line: 
            continue
        parts=line.split("\t")
        if len(parts)!=3:
            parts=line.split()
            if len(parts)<3:
                continue
            slug=parts[0]; kind=parts[-1]; name=" ".join(parts[1:-1])
        else:
            slug,name,kind=parts
        items.append((slug,name,kind))

def page_shell(title, desc, canon, h1, lead, body):
    return f"""<!doctype html><html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(desc)}"/>
<link rel="canonical" href="{html.escape(canon)}"/>
<link rel="stylesheet" href="/assets/css/janu-theme.css"/><link rel="stylesheet" href="/assets/css/janu-knowledge.css"/>
</head><body>
<!--#include virtual="/includes/header.php" -->
<main class="kb kb-wrap">
<header class="kb-hero"><div class="kb-hero-text">
<h1>{html.escape(h1)}</h1>
<p class="kb-lead">{html.escape(lead)}</p>
<div class="kb-meta"><span>India</span><span>Updated: {today}</span></div>
</div></header>
{body}
</main>
<!--#include virtual="/includes/footer.php" -->
</body></html>"""

lis=[]
for slug,name,kind in items:
    badge = "State" if kind=="state" else "Union Territory"
    lis.append(f'<li><a href="/knowledge/india/states/pages/{slug}.html">{html.escape(name)}</a> <span class="kb-tag">{badge}</span></li>')
list_html="\n".join(lis)

index_body=f"""
<section class="kb-card"><h2>Fast links</h2><ul>
<li><a href="/knowledge/india/index.html">India Hub</a></li>
<li><a href="/knowledge/west-bengal/index.html">West Bengal Hub</a></li>
<li><a href="/knowledge/purulia/index.html">Purulia Hub (reference standard)</a></li>
</ul></section>

<section class="kb-card">
<h2>States & Union Territories (starter pages)</h2>
<ul>{list_html}</ul>
<p class="kb-note">Each page is a starter shell. Next phases will add: districts, key geography, history timeline, culture forms, festivals, tourism routes, connectivity, and image manifests.</p>
</section>
"""

open(os.path.join(S,"index.html"),"w",encoding="utf-8").write(page_shell(
    "India States & Union Territories Directory | Dalmia Computers",
    "India directory: all states and union territories with starter hub pages (JANU phases).",
    "https://dalmiacomputers.in/knowledge/india/states/index.html",
    "India — States & Union Territories",
    "State-first build → districts → blocks → villages (PIN). Each hub expands with geography, history, culture, tourism, spirituality, cinema, and dance & culture.",
    index_body
))

for slug,name,kind in items:
    badge="State" if kind=="state" else "Union Territory"
    canon=f"https://dalmiacomputers.in/knowledge/india/states/pages/{slug}.html"
    body=f"""
<section class="kb-card">
<h2>Quick facts (starter)</h2>
<ul>
<li><strong>Type:</strong> {badge}</li>
<li><strong>Name:</strong> {html.escape(name)}</li>
<li><strong>Next build:</strong> districts directory + hubs (geography/history/culture/tourism/spirituality)</li>
</ul>
</section>

<section class="kb-card">
<h2>Build plan (JANU phases)</h2>
<ol>
<li>Districts directory + key cities/towns</li>
<li>Geography: rivers/relief/climate (map)</li>
<li>History: timeline + region notes</li>
<li>Culture: languages, arts, festivals, crafts</li>
<li>Tourism: routes, seasons, safety, stays</li>
<li>Connectivity: rail/road/air (where applicable)</li>
</ol>
</section>

<section class="kb-card">
<h2>Cross links</h2>
<ul>
<li><a href="/knowledge/india/index.html">India Hub</a></li>
<li><a href="/knowledge/india/states/index.html">States Directory</a></li>
</ul>
</section>
"""
    open(os.path.join(P,f"{slug}.html"),"w",encoding="utf-8").write(page_shell(
        f"{name} ({badge}) | India Knowledge Hub | Dalmia Computers",
        f"{name}: starter hub page for districts, geography, history, culture, tourism, and spirituality (JANU phases).",
        canon,
        f"{name} — {badge}",
        "Starter hub page. Next phases will add district-by-district pages and deep knowledge sections.",
        body
    ))

print(f"OK: generated index + {len(items)} pages")
PY

chown -R www-data:www-data "$S" 2>/dev/null || true
find "$S" -type d -exec chmod 755 {} \; || true
find "$S" -type f -exec chmod 644 {} \; || true

echo "OK: India states+UTs v2 deployed"
echo "PAGE: /knowledge/india/states/index.html"
echo "PAGES: $(ls -1 "$P"/*.html 2>/dev/null | wc -l | tr -d " ")"
echo "BACKUP: $BK"
EOF

chmod +x packs/india_states_full_v2.sh

git add packs/india_states_full_v2.sh
git commit -m "JANU: India states+UTs directory v2" || true
git push || true

echo "RUNNING..."
bash packs/india_states_full_v2.sh
'
