import eco_model as m, copy
ups0, q0 = m.read_prog()
NEW = {'heart': [5000, 30000, 100000], 'rewind': [80000], 'flight': [4800, 20000, 60000], 'slow': [15000, 50000],
       'monster': [2500, 15000, 40000], 'sphere': [30000], 'tnt': [2000, 4000, 25000], 'nature': [1200, 2800, 20000],
       'dash': [1200, 2800, 20000], 'boots': [2500, 15000]}
SKINS = [
 ('perso', 'Safari', 3, 1500), ('perso', 'Pirate', 6, 4000), ('perso', 'Ninja', 10, 10000), ('perso', 'Momie', 15, 20000), ('perso', 'Doré', 30, 60000),
 ('monture', 'Gorille argenté', 5, 3000), ('monture', 'Rhino cuirassé', 3, 3000), ('monture', 'Papillon', 7, 3000),
 ('monture', 'Yéti', 12, 9000), ('monture', 'Tricératops', 12, 9000), ('monture', 'Libellule néon', 12, 9000),
 ('monture', 'Gorille de lave', 20, 25000), ('monture', 'Rhino de cristal', 20, 25000), ('monture', 'Phénix', 20, 25000),
 ('temple', 'Jade', 8, 5000), ('temple', 'Englouti', 16, 15000), ('temple', 'Or', 25, 40000),
 ('pygmees', 'Masques de fête', 7, 4000), ('pygmees', 'Squelettes', 14, 12000), ('pygmees', 'Garde royale', 22, 30000),
 ('menu', 'Nuit', 4, 2000), ('menu', 'Coucher de soleil', 9, 6000), ('menu', 'Ruines dorées', 18, 18000),
 ('musique', 'Tambours', 2, 1500), ('musique', 'Flûtes', 8, 5000), ('musique', 'Orage', 15, 12000), ('musique', 'Épopée', 25, 25000),
]
extra = [{'id': 'skin:' + n, 'lvl': 1, 'unlock': l, 'price': p} for (_, n, l, p) in SKINS]
print('catalogue skins', sum(p for *_, p in SKINS), 'pièces,', len(SKINS), 'skins')
by = {}
for c, n, l, p in SKINS:
    by.setdefault(c, [0, 0]); by[c][0] += 1; by[c][1] += p
print(by)
def run(ups, label, scale=1.0, items=extra):
    o = m.avg(ups=ups, quests=q0, seeds=20, scale=scale, extra_items=items)
    up_ids = set(ups)
    ups_last = max(v[0] for k, v in o['items'].items() if not k.startswith('skin:'))
    sk = [v[0] for k, v in o['items'].items() if k.startswith('skin:')]
    print(f"{label}: tout {o['total']} ; achats 20/200/400/800 = " + " / ".join(f"{o[k]['n_owned']:.0f}" for k in (20,200,400,800)) + f" sur {o['n_items']} ; dépensé % " + " / ".join(f"{o[k]['pct']:.0f}" for k in (20,200,400,800)) + f" ; dernière amélioration ~{ups_last}, dernier skin ~{max(sk) if sk else None} ({len(sk)} skins achetés sur 20 essais médians), tout à {o['all_at']}")
    return o
u = copy.deepcopy(ups0)
for k, v in NEW.items(): u[k]['costs'] = v
o = run(u, 'proposition + skins')
run(u, 'prudent', 0.6)
run(u, 'rapide', 1.5)
print(sorted([(k, v[0]) for k, v in o['items'].items() if k.startswith('skin:')], key=lambda kv: kv[1]))
o2 = run(ups0, 'tes prix + skins')
print('--- B : avec skins')
NEWB = {'heart': [5000, 20000, 50000], 'rewind': [40000], 'flight': [4800, 12000, 25000], 'slow': [8000, 20000],
        'monster': [2500, 8000, 20000], 'sphere': [15000], 'tnt': [2000, 4000, 12000], 'nature': [1200, 2800, 12000],
        'dash': [1200, 2800, 12000], 'boots': [2500, 10000]}
ub = copy.deepcopy(ups0)
for k, v in NEWB.items(): ub[k]['costs'] = v
print('améliorations B', sum(sum(x['costs']) for x in ub.values()))
ob = run(ub, 'B + skins')
run(ub, 'B + skins prudent', 0.6)
run(ub, 'B + skins rapide', 1.5)
print(sorted([(k, v[0]) for k, v in ob['items'].items()], key=lambda kv: kv[1])[-20:])
for k in (20, 200, 400, 800):
    print(k, 'niveau', round(ob[k]['level']), 'revenus', {a: round(b) for a, b in ob[k]['income'].items()})
