"""
Damage Graph Generator for MustMod (Chivalry: Medieval Warfare)
Calculates effective damage for EVERY attack of each weapon, vs each class,
at each of the 3 melee hit locations.

Formula: EffectiveDamage = fBaseDamage * sum(DamageType[i] * DamageResistances[i]) * LocationModifier
         Melee LocationModifiers: Head=1.25, Torso=1.0, Legs=0.8

Output: one card per weapon, containing one chart per body part (Head/Torso/Legs).
Each chart plots all of that weapon's damaging attacks against all four classes.
"""
import os
import re
import json

# Damage Type Compositions (EDMG_Swing, EDMG_Pierce, EDMG_Blunt, EDMG_Generic)
DAMAGE_TYPES = {
    "AOCDmgType_Swing":       [1.0, 0.0, 0.0, 0.0],
    "AOCDmgType_Pierce":      [0.0, 1.0, 0.0, 0.0],
    "AOCDmgType_Blunt":       [0.0, 0.0, 1.0, 0.0],
    "AOCDmgType_SwingBlunt":  [0.5, 0.0, 0.5, 0.0],
    "AOCDmgType_PierceBlunt": [0.0, 0.5, 0.5, 0.0],
    "AOCDmgType_Generic":     [0.0, 0.0, 0.0, 1.0],
    "AOCDmgType_Shove":       [0.0, 0.0, 0.0, 1.0],
}

# Class Damage Resistances (multiplier - LOWER = more resistant)
CLASSES = {
    "Archer":    {"Swing": 0.85, "Pierce": 0.85, "Blunt": 0.65},
    "Knight":    {"Swing": 0.40, "Pierce": 0.50, "Blunt": 0.61},
    "ManAtArms": {"Swing": 0.80, "Pierce": 0.85, "Blunt": 0.65},
    "Vanguard":  {"Swing": 0.60, "Pierce": 0.80, "Blunt": 0.70},
}

# Melee Hit Location Modifiers (from AOCFamilyInfo.uc)
LOCATION_MODIFIERS = {
    "Head":  1.25,
    "Torso": 1.0,
    "Legs":  0.8,
}

# AttackTypeInfo array slots. 0-2 and 5 are certain; 3 is the special/charge
# attack (couched lance, sprint attack) and 4 is an alternate slot that is
# almost always zeroed out for melee weapons.
ATTACK_NAMES = {
    0: "Slash (LMB)",
    1: "Overhead",
    2: "Stab",
    3: "Special",
    4: "Alt",
    5: "Shove",
}

CLASS_STYLE = {
    "Archer":    {"color": "rgba(63,185,80,0.85)",  "hex": "#3fb950"},
    "Knight":    {"color": "rgba(248,81,73,0.85)",  "hex": "#f85149"},
    "ManAtArms": {"color": "rgba(88,166,255,0.85)", "hex": "#58a6ff"},
    "Vanguard":  {"color": "rgba(210,168,0,0.85)",  "hex": "#d2a800"},
}


def calc_resistance(dmg_type_name, class_name):
    """Calculate effective resistance multiplier for a damage type vs a class."""
    dmg_composition = DAMAGE_TYPES.get(dmg_type_name, [0, 0, 0, 1.0])
    res = CLASSES[class_name]
    return (dmg_composition[0] * res["Swing"] +
            dmg_composition[1] * res["Pierce"] +
            dmg_composition[2] * res["Blunt"] +
            dmg_composition[3] * 1.0)  # Generic/Shove is unresisted


def calc_effective_damage(base_damage, dmg_type_name, class_name, location='Torso'):
    """Calculate effective damage at a given hit location."""
    return round(base_damage * calc_resistance(dmg_type_name, class_name) * LOCATION_MODIFIERS[location])


def parse_weapon_files(base_dir):
    """Parse all weapon attachment files and extract every AttackTypeInfo entry."""
    weapons = {}

    attach_dir = os.path.join(base_dir, "Classes")
    pattern = re.compile(r'MustModWeaponAttachment_(\w+)\.uc')

    for fname in sorted(os.listdir(attach_dir)):
        m = pattern.match(fname)
        if not m:
            continue
        weapon_name = m.group(1)

        filepath = os.path.join(attach_dir, fname)
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        # AttackTypeInfo(n)=(fBaseDamage=X, ... cDamageType="AOC.AOCDmgType_YYY", ...)
        atk_pattern = re.compile(
            r'AttackTypeInfo\((\d+)\)=\(fBaseDamage=([\d.]+).*?cDamageType="([^"]+)"',
            re.DOTALL
        )

        attacks = {}
        for match in atk_pattern.finditer(content):
            idx = int(match.group(1))
            dmg = float(match.group(2))
            dmg_type = match.group(3).split('.')[-1]
            attacks[idx] = (dmg, dmg_type)

        if attacks:
            weapons[weapon_name] = attacks

    return weapons


def generate_html(weapons, output_path):
    """Generate a self-contained HTML file: per weapon, one chart per body part."""

    # Build JS weapon data: every attack slot with non-zero base damage, in slot order.
    js_weapons = {}
    skipped = {}
    for wname, attacks in sorted(weapons.items()):
        atk_list = []
        empty = []
        for idx in sorted(attacks):
            dmg, dtype = attacks[idx]
            short_type = dtype.replace("AOCDmgType_", "")
            if dmg <= 0:
                empty.append(ATTACK_NAMES.get(idx, "Slot %d" % idx))
                continue
            atk_list.append({
                "i": idx,
                "n": ATTACK_NAMES.get(idx, "Slot %d" % idx),
                "d": dmg if dmg % 1 else int(dmg),
                "t": short_type,
            })
        if atk_list:
            js_weapons[wname] = atk_list
            skipped[wname] = empty

    class_js = [{"n": n,
                 "r": [r["Swing"], r["Pierce"], r["Blunt"]],
                 "color": CLASS_STYLE[n]["color"],
                 "hex": CLASS_STYLE[n]["hex"]}
                for n, r in CLASSES.items()]

    weapons_json = json.dumps(js_weapons, indent=1)
    classes_json = json.dumps(class_js, indent=1)
    loc_mod_json = json.dumps(LOCATION_MODIFIERS)
    skipped_json = json.dumps(skipped)

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>MustMod Damage - every attack, per weapon, per body part</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
* {{ box-sizing: border-box; }}
body {{ font-family: 'Segoe UI', Arial, sans-serif; background: #0d1117; color: #c9d1d9; padding: 20px 20px 60px; }}
h1 {{ text-align: center; color: #58a6ff; font-size: 24px; margin: 0 0 6px; }}
.subtitle {{ text-align: center; color: #8b949e; font-size: 13px; margin-bottom: 20px; }}
.info {{ background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 14px 18px; margin: 0 auto 20px; font-size: 13px; line-height: 1.8; max-width: 1200px; }}
.info b {{ color: #58a6ff; }}
.info code {{ background: #21262d; padding: 1px 5px; border-radius: 3px; color: #f0883e; }}
.controls {{ max-width: 1200px; margin: 0 auto 20px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }}
.controls input {{ flex: 1 1 260px; background: #0d1117; border: 1px solid #30363d; border-radius: 6px; padding: 8px 12px; color: #c9d1d9; font-size: 13px; }}
.controls input:focus {{ outline: none; border-color: #1f6feb; }}
.controls .count {{ color: #8b949e; font-size: 12px; }}
.chip {{ padding: 5px 12px; background: #21262d; border: 1px solid #30363d; border-radius: 999px; color: #8b949e; cursor: pointer; font-size: 12px; user-select: none; }}
.chip.on {{ color: #fff; }}
.weapon-grid {{ display: grid; grid-template-columns: 1fr; gap: 18px; max-width: 1200px; margin: 0 auto; }}
.per-weapon {{ background: #161b22; border: 1px solid #30363d; border-radius: 10px; padding: 16px 18px; }}
.per-weapon h3 {{ color: #f0883e; font-size: 16px; margin: 0 0 2px; }}
.per-weapon .atk-summary {{ color: #6e7681; font-size: 11px; margin: 0 0 10px; }}
.per-weapon .atk-summary span {{ color: #8b949e; }}
.location-row {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }}
@media (max-width: 900px) {{ .location-row {{ grid-template-columns: 1fr !important; }} }}
.location-card {{ background: #0d1117; border: 1px solid #21262d; border-radius: 6px; padding: 10px 8px; }}
.location-card h4 {{ color: #8b949e; font-size: 12px; margin: 0 0 6px; text-align: center; text-transform: uppercase; letter-spacing: 1px; }}
.location-card h4 span {{ color: #484f58; letter-spacing: 0; text-transform: none; }}
.byclass {{ margin-top: 40px; max-width: 1200px; margin-left: auto; margin-right: auto; }}
.byclass h2 {{ color: #58a6ff; font-size: 20px; margin-bottom: 18px; }}
.loc-tabs {{ display: flex; gap: 8px; margin-bottom: 12px; }}
.loc-tab {{ padding: 6px 16px; background: #21262d; border: 1px solid #30363d; border-radius: 6px; color: #8b949e; cursor: pointer; font-size: 13px; }}
.loc-tab.active {{ background: #1f6feb; border-color: #1f6feb; color: #fff; }}
.loc-tab:hover:not(.active) {{ background: #30363d; }}
</style>
</head>
<body>

<h1>MustMod &mdash; Every Attack, by Weapon and Hit Location</h1>
<p class="subtitle">Damage = fBaseDamage &times; &Sigma;(DmgType[i] &times; Resist[i]) &times; LocationModifier &mdash; parsed from MustModWeaponAttachment_*.uc</p>

<div class="info">
<b>Effective Damage = &lfloor;BaseDamage &times; Resistance &times; LocationModifier&rceil;</b> where
<code>Resistance = DmgType[S]&times;Resist[S] + DmgType[P]&times;Resist[P] + DmgType[B]&times;Resist[B]</code><br>
<b>Location Modifiers:</b> Head &times;{LOCATION_MODIFIERS["Head"]}, Torso &times;{LOCATION_MODIFIERS["Torso"]}, Legs &times;{LOCATION_MODIFIERS["Legs"]}<br>
<b>Resistances (S/P/B):</b> <span style="color:#3fb950;">Archer 0.85/0.85/0.65</span> &middot; <span style="color:#f85149;">Knight 0.40/0.50/0.61</span> &middot; <span style="color:#58a6ff;">MaA 0.80/0.85/0.65</span> &middot; <span style="color:#d2a800;">Vanguard 0.60/0.80/0.70</span><br>
<b>Attack slots:</b> 0 Slash (LMB) &middot; 1 Overhead &middot; 2 Stab &middot; 3 Special (couched / sprint charge) &middot; 4 Alt &middot; 5 Shove.
Slots with 0 base damage are unused and are listed under each weapon rather than plotted.
<b>Shove/Generic</b> ignores class resistance (composition is pure Generic, multiplier 1.0).
</div>

<div class="controls">
  <input id="filter" type="text" placeholder="Filter weapons... (e.g. sword, axe, lance)" autocomplete="off">
  <div class="chip on" id="chipHead"  style="border-color:#1f6feb">Head</div>
  <div class="chip on" id="chipTorso" style="border-color:#1f6feb">Torso</div>
  <div class="chip on" id="chipLegs"  style="border-color:#1f6feb">Legs</div>
  <div class="count" id="count"></div>
</div>

<div class="weapon-grid" id="weaponGrid"></div>
<div class="byclass" id="byClass"></div>

<script>
const DMG = {{ "Swing":[1,0,0,0],"Pierce":[0,1,0,0],"Blunt":[0,0,1,0],"SwingBlunt":[0.5,0,0.5,0],"PierceBlunt":[0,0.5,0.5,0],"Generic":[0,0,0,1],"Shove":[0,0,0,1] }};
const CL = {classes_json};
const LOC = {loc_mod_json};
const W = {weapons_json};
const EMPTY = {skipped_json};
const ATC = {{Swing:"rgba(248,81,73,0.78)",Pierce:"rgba(63,185,80,0.78)",Blunt:"rgba(88,166,255,0.78)",SwingBlunt:"rgba(188,140,255,0.78)",PierceBlunt:"rgba(255,166,87,0.78)",Shove:"rgba(139,148,158,0.78)",Generic:"rgba(139,148,158,0.78)"}};
const LOCATIONS = ["Head","Torso","Legs"];
const wnames = Object.keys(W).sort();

function calc(base, dtype, cls, loc) {{
  const d = DMG[dtype];
  if (!d) return 0;
  const res = d[0]*cls.r[0] + d[1]*cls.r[1] + d[2]*cls.r[2] + d[3]*1.0;
  return Math.round(base * res * LOC[loc]);
}}

// A shared y-max per weapon so Head/Torso/Legs stay visually comparable.
function weaponMax(w) {{
  let m = 0;
  W[w].forEach(a => CL.forEach(cl => {{ m = Math.max(m, calc(a.d, a.t, cl, "Head")); }}));
  return Math.ceil((m * 1.12) / 10) * 10;
}}

// ============ PER-WEAPON: one chart per body part ============
const grid = document.getElementById("weaponGrid");

wnames.forEach(wname => {{
  const atks = W[wname];
  const yMax = weaponMax(wname);

  const div = document.createElement("div");
  div.className = "per-weapon";
  div.dataset.weapon = wname.toLowerCase();

  const summary = atks.map(a => `<span>${{a.n}}</span> ${{a.d}} ${{a.t}}`).join(" &nbsp;&middot;&nbsp; ");
  const unused = (EMPTY[wname] || []);
  const unusedTxt = unused.length ? ` &nbsp;|&nbsp; unused: ${{unused.join(", ")}}` : "";

  let cards = "";
  LOCATIONS.forEach(loc => {{
    cards += `<div class="location-card" data-loc="${{loc}}"><h4>${{loc}} <span>&times;${{LOC[loc]}}</span></h4><canvas id="w_${{wname}}_${{loc}}"></canvas></div>`;
  }});
  div.innerHTML = `<h3>${{wname}}</h3><p class="atk-summary">${{summary}}${{unusedTxt}}</p><div class="location-row">${{cards}}</div>`;
  grid.appendChild(div);

  const labels = atks.map(a => [a.n, `${{a.t}} ${{a.d}}`]);

  LOCATIONS.forEach(loc => {{
    const datasets = CL.map(cl => ({{
      label: cl.n,
      data: atks.map(a => calc(a.d, a.t, cl, loc)),
      backgroundColor: cl.color,
      borderColor: cl.hex,
      borderWidth: 1,
    }}));

    new Chart(document.getElementById(`w_${{wname}}_${{loc}}`), {{
      type: "bar",
      data: {{ labels, datasets }},
      options: {{
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.1,
        plugins: {{
          legend: {{ display: loc === "Head", labels: {{ color:"#c9d1d9", font:{{size:10}}, usePointStyle:true, pointStyleWidth:8, boxWidth:8 }} }},
          tooltip: {{
            callbacks: {{
              title: (items) => {{
                const a = atks[items[0].dataIndex];
                return `${{a.n}} \\u2014 ${{a.t}} (${{a.d}} base) \\u2192 ${{loc}} \\u00d7${{LOC[loc]}}`;
              }},
              label: (ctx) => {{
                const a = atks[ctx.dataIndex];
                const cl = CL[ctx.datasetIndex];
                const d = DMG[a.t] || [0,0,0,1];
                const res = d[0]*cl.r[0] + d[1]*cl.r[1] + d[2]*cl.r[2] + d[3];
                return `${{cl.n}}: ${{ctx.raw}} dmg  (resist \\u00d7${{res.toFixed(2)}})`;
              }},
            }},
          }},
        }},
        scales: {{
          x: {{ ticks: {{ color:"#8b949e", font:{{size:9}}, autoSkip:false }}, grid:{{color:"#21262d"}} }},
          y: {{ beginAtZero:true, max:yMax, ticks:{{color:"#8b949e", font:{{size:9}} }}, grid:{{color:"#21262d"}} }},
        }},
      }},
    }});
  }});
}});

// ============ FILTER + BODY-PART TOGGLES ============
const cards = Array.from(grid.children);
const countEl = document.getElementById("count");
const filterEl = document.getElementById("filter");
const locOn = {{Head:true, Torso:true, Legs:true}};

function applyFilter() {{
  const q = filterEl.value.trim().toLowerCase();
  let shown = 0;
  cards.forEach(c => {{
    const hit = !q || c.dataset.weapon.includes(q);
    c.style.display = hit ? "" : "none";
    if (hit) shown++;
    c.querySelectorAll(".location-card").forEach(lc => {{
      lc.style.display = locOn[lc.dataset.loc] ? "" : "none";
    }});
  }});
  const cols = LOCATIONS.filter(l => locOn[l]).length || 1;
  document.querySelectorAll(".location-row").forEach(r => {{
    r.style.gridTemplateColumns = `repeat(${{cols}}, 1fr)`;
  }});
  countEl.textContent = `${{shown}} / ${{cards.length}} weapons`;
}}
filterEl.addEventListener("input", applyFilter);
LOCATIONS.forEach(l => {{
  const chip = document.getElementById("chip" + l);
  chip.addEventListener("click", () => {{
    locOn[l] = !locOn[l];
    chip.classList.toggle("on", locOn[l]);
    chip.style.borderColor = locOn[l] ? "#1f6feb" : "#30363d";
    applyFilter();
  }});
}});
applyFilter();

// ============ BY-CLASS COMPARISON (all attacks) with location tabs ============
const byClassDiv = document.getElementById("byClass");
byClassDiv.innerHTML = '<h2>Full Comparison by Class &mdash; every attack</h2>';

CL.forEach(cl => {{
  const container = document.createElement("div");
  container.className = "per-weapon";
  container.style.marginBottom = "16px";

  let tabsHtml = '<div class="loc-tabs">';
  LOCATIONS.forEach((loc, i) => {{
    tabsHtml += `<button class="loc-tab${{i === 1 ? ' active' : ''}}" data-cls="${{cl.n}}" data-loc="${{loc}}">${{loc}} &times;${{LOC[loc]}}</button>`;
  }});
  tabsHtml += '</div>';

  let canvasesHtml = "";
  LOCATIONS.forEach((loc, i) => {{
    canvasesHtml += `<div class="location-card" id="bc_card_${{cl.n}}_${{loc}}" style="${{i !== 1 ? 'display:none' : ''}}"><canvas id="c_${{cl.n}}_${{loc}}"></canvas></div>`;
  }});

  container.innerHTML = `<h3>vs <span style="color:${{cl.hex}}">${{cl.n}}</span> &mdash; Resist S:${{cl.r[0]}} P:${{cl.r[1]}} B:${{cl.r[2]}}</h3>${{tabsHtml}}${{canvasesHtml}}`;
  byClassDiv.appendChild(container);

  LOCATIONS.forEach(loc => {{
    const labels=[], data=[], bg=[], info=[];
    wnames.forEach(w => {{
      W[w].forEach(a => {{
        labels.push(`${{w}} ${{a.n}}`);
        data.push(calc(a.d, a.t, cl, loc));
        bg.push(ATC[a.t] || "#888");
        info.push({{w, atk:a.n, dtype:a.t, base:a.d, loc}});
      }});
      labels.push(''); data.push(null); bg.push('transparent'); info.push(null);
    }});

    new Chart(document.getElementById(`c_${{cl.n}}_${{loc}}`), {{
      type:"bar",
      data:{{labels,datasets:[{{label:`vs ${{cl.n}} (${{loc}})`,data,backgroundColor:bg,borderColor:bg.map(c=>c==='transparent'?'transparent':c.replace("0.78","1")),borderWidth:1,atkInfo:info}}]}},
      options:{{
        responsive:true, maintainAspectRatio:true, aspectRatio:3.2,
        plugins:{{legend:{{display:false}},
          tooltip:{{callbacks:{{
            title:(items)=>{{const i=items[0]?.dataset?.atkInfo?.[items[0]?.dataIndex];return i?`${{i.w}} \\u2014 ${{i.atk}} (${{i.dtype}} ${{i.base}}) \\u2192 ${{i.loc}}`:'';}},
            label:(ctx)=>ctx.raw===null?'':`${{ctx.raw}} damage`
          }}}}
        }},
        scales:{{
          x:{{ticks:{{color:"#8b949e",font:{{size:6}},maxRotation:90,autoSkip:false}},grid:{{color:"#21262d"}}}},
          y:{{beginAtZero:true,ticks:{{color:"#8b949e",font:{{size:9}}}},grid:{{color:"#21262d"}}}},
        }},
      }},
    }});
  }});

  container.querySelectorAll('.loc-tab').forEach(btn => {{
    btn.addEventListener('click', () => {{
      container.querySelectorAll('.loc-tab').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      LOCATIONS.forEach(l => {{
        const card = document.getElementById(`bc_card_${{btn.dataset.cls}}_${{l}}`);
        if (card) card.style.display = l === btn.dataset.loc ? '' : 'none';
      }});
    }});
  }});
}});
</script>
</body>
</html>'''

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html)

    total_atks = sum(len(v) for v in js_weapons.values())
    print(f"Generated {output_path}")
    print(f"  Weapons: {len(js_weapons)}   Damaging attacks plotted: {total_atks}")
    print(f"  Charts: {len(js_weapons)} weapons x {len(LOCATION_MODIFIERS)} body parts = {len(js_weapons)*len(LOCATION_MODIFIERS)}")

    # Console table: every attack, every class, at Torso.
    print("\n=== EFFECTIVE DAMAGE - ALL ATTACKS (Torso) ===")
    print(f"{'Weapon':<22}{'Attack':<13}{'Type':<12}{'Base':>5}" + "".join(f"{c:>11}" for c in CLASSES))
    print("-" * (22 + 13 + 12 + 5 + 11 * len(CLASSES)))
    for wname in sorted(weapons):
        for idx in sorted(weapons[wname]):
            dmg, dtype = weapons[wname][idx]
            if dmg <= 0:
                continue
            short = dtype.replace("AOCDmgType_", "")
            row = f"{wname:<22}{ATTACK_NAMES.get(idx, idx):<13}{short:<12}{dmg:>5.0f}"
            for cls_name in CLASSES:
                row += f"{calc_effective_damage(dmg, dtype, cls_name, 'Torso'):>11}"
            print(row)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_dir = script_dir  # Script lives in MustMod root

    if not os.path.isdir(os.path.join(base_dir, "Classes")):
        base_dir = r"c:\Program Files (x86)\Steam\steamapps\common\chivalrymedievalwarfare\Development\Src\MustMod"

    weapons = parse_weapon_files(base_dir)
    print(f"Parsed {len(weapons)} weapons from {base_dir}")

    output_path = os.path.join(base_dir, "damage_graph.html")
    generate_html(weapons, output_path)


if __name__ == "__main__":
    main()
