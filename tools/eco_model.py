"""Jungle Loop 0.46 economy model (python tools/eco_model.py): 800 runs of a typical player, from the game's own measures.

Measured in the game (god, no input, 4 seeds): gold laid per distance, events per 4000 m.
Assumed (stated in the report): the distance of each run, the share of coins a player picks up, how often
he does the things the objectives count.
"""
import math, random, re, sys, json

import os
PROG = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'reglages', 'progression.txt')

# gold laid on the road, Histoire (story), cumulative, no upgrade / coin upgrades maxed (measured)
LAID = [(0, 0), (500, 188), (1000, 341), (1500, 496), (2000, 1044), (3000, 1392), (4000, 1578)]
LAID_MAX = [(0, 0), (500, 288), (1000, 518), (1500, 731), (2000, 1362), (3000, 1817), (4000, 2101)]


def interp(tab, x):
    if x >= tab[-1][0]:
        (x0, y0), (x1, y1) = tab[-2], tab[-1]
        return y1 + (y1 - y0) / (x1 - x0) * (x - x1)
    for (x0, y0), (x1, y1) in zip(tab, tab[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)


def read_prog(path=PROG):
    ups, quests, sec = {}, {}, ''
    order = []
    for raw in open(path, encoding='utf-8'):
        line = raw.split('#')[0].strip()
        if not line:
            continue
        if line.startswith('['):
            sec = line.strip('[]').strip()
            continue
        c = [x.strip() for x in line.split('|')]
        if sec == 'ameliorations':
            ups[c[0]] = {'unlock': int(c[1]), 'costs': [int(v) for v in c[2].split('/')]}
            order.append(c[0])
        elif sec == 'defis':
            if c[0] in ('longs a la fois',):
                continue
            quests.setdefault(c[0], []).append({'goal': float(c[1]), 'reward': int(c[2]), 'xp': int(c[3]), 'long': len(c) > 4 and c[4] == 'long'})
    return ups, quests


def dist_of(k, scale=1.0):
    pts = [(1, 300), (20, 700), (200, 1600), (800, 2600)]
    lk = math.log(k)
    for (a, da), (b, db) in zip(pts, pts[1:]):
        if k <= b:
            t = (lk - math.log(a)) / (math.log(b) - math.log(a))
            return scale * (da + (db - da) * t)
    return scale * pts[-1][1]


SINGLE = {'dist1', 'coins1', 'safe', 'monkeys', 'darts1'}
NEEDS = {'breaks': ['breaker', 'dash', 'boots', 'tnt']}
SEEN = {'gorilla', 'rhino', 'dragonfly'}


def rides(d):
    if d < 850:
        return 0.0
    return 0.8 * (1 + (d - 850) / 1550)


def stats_of(d, coins, owned, rng):
    r = rides(d)
    return {
        'dist1': d, 'distT': d, 'coins1': coins, 'coinsT': coins,
        'gems': 1.5 * d / 1000, 'jumps': 60 * d / 1000, 'plats': 10 * d / 1000,
        'safe': d * rng.uniform(0.2, 0.7), 'runs': 1, 'shrooms': 2.75 * d / 1000,
        'monkeys': 1.5 * d / 1000, 'breaks': (5 if owned.get('breaker') else 1) * d / 1000,
        'mounts': r, 'dodges': 2.2 * d / 1000,
        'gorilla': r / 3 * 350, 'rhino': r / 3 * 230, 'dragonfly': r / 3 * 400,
        'darts1': 0.85 * 4.3 * max(0, d - 300) / 1000, 'dartsT': 0.85 * 4.3 * max(0, d - 300) / 1000,
    }


def simulate(scale=1.0, runs=800, seed=1, ups=None, quests=None, extra_items=None, verbose=False, slots=3, cap_long=1, lvl_cap=10**9, urn_coins=182, steps=(300, 500, 700, 1000), drums_every=10, drums_coins=450):
    rng = random.Random(seed)
    if ups is None:
        ups, quests = read_prog()
    items = []                           # (unlock, price, id, level) every purchase, buyable in price order
    for uid, u in ups.items():
        for i, c in enumerate(u['costs']):
            items.append({'id': uid, 'lvl': i + 1, 'unlock': u['unlock'], 'price': c})
    for it in (extra_items or []):
        items.append(dict(it))
    total_cost = sum(i['price'] for i in items)
    owned, coins, xp, best = {}, 0.0, 0.0, 0.0
    qsteps, active, last = {}, [], ''
    spent, bought_at = 0.0, {}
    income = {'route': 0.0, 'niveaux': 0.0, 'defis': 0.0}
    snap = {}

    def level():
        l, rest = 1, xp
        while rest >= steps[min(l - 1, len(steps) - 1)]:
            rest -= steps[min(l - 1, len(steps) - 1)]
            l += 1
        return l

    def fill():
        nonlocal active
        while len(active) < slots:
            free = [k for k in quests if k not in [a['k'] for a in active] and k != last
                    and not (k in SEEN and best < 700)
                    and not (k in NEEDS and not any(owned.get(x) for x in NEEDS[k]))]
            if cap_long is not None:
                longs = [a for a in active if a['long']]
                if len(longs) >= cap_long:
                    free = [k for k in free if not is_long(k)]
            k = rng.choice(free)
            st = quests[k][min(qsteps.get(k, 0), len(quests[k]) - 1)]
            active.append({'k': k, 'goal': st['goal'], 'p': 0.0, 'reward': st['reward'], 'xp': st['xp'], 'long': is_long(k)})

    def is_long(k):
        return quests[k][min(qsteps.get(k, 0), len(quests[k]) - 1)].get('long', False)

    fill()
    quests_done = 0
    for k in range(1, runs + 1):
        d = dist_of(k, scale) * rng.uniform(0.5, 1.5)
        cl = (owned.get('lucky', 0) / 2 + owned.get('scatter', 0) / 3) / 2
        laid = interp(LAID, d) * (1 - cl) + interp(LAID_MAX, d) * cl
        pick = 0.70 + 0.20 * owned.get('magnet', 0) / 3
        gold = laid * pick
        coins += gold
        income['route'] += gold
        best = max(best, d)
        for a in active:
            if a['k'] in SINGLE:
                a['p'] = 0
        st = stats_of(d, gold, owned, rng)
        gained_xp = d / 20
        done = []
        for a in active:
            a['p'] = min(a['goal'], a['p'] + st[a['k']])
            if a['p'] >= a['goal']:
                done.append(a)
        for a in done:
            active.remove(a)
            coins += a['reward']
            income['defis'] += a['reward']
            gained_xp += a['xp']
            qsteps[a['k']] = qsteps.get(a['k'], 0) + 1
            last = a['k']
            quests_done += 1
        if done:
            fill()
        l0 = level()
        xp += gained_xp
        for l in range(l0 + 1, level() + 1):
            coins += 20 * min(l, lvl_cap) + urn_coins
            income['niveaux'] += 20 * min(l, lvl_cap) + urn_coins
        if drums_every and k % drums_every == 0:        # the drums of the day, now and then
            coins += drums_coins
            income['niveaux'] += drums_coins
        # shopping: the cheapest thing unlocked whose previous level is owned
        while True:
            cands = [i for i in items if i['unlock'] <= level() and owned.get(i['id'], 0) == i['lvl'] - 1 and i['price'] <= coins]
            if not cands:
                break
            it = min(cands, key=lambda i: i['price'])
            coins -= it['price']
            spent += it['price']
            owned[it['id']] = it['lvl']
            bought_at[(it['id'], it['lvl'])] = k
        if k in (20, 50, 100, 200, 400, 800) or k == runs:
            snap[k] = {'spent': spent, 'pct': 100 * spent / total_cost, 'level': level(), 'coins': coins,
                       'n_owned': sum(1 for i in items if (i['id'], i['lvl']) in bought_at), 'n_items': len(items),
                       'income': dict(income), 'quests': quests_done, 'active': [a['k'] for a in active]}
    all_at = max(bought_at.values()) if len(bought_at) == len(items) else None
    return {'total': total_cost, 'snap': snap, 'all_at': all_at, 'bought_at': bought_at}


def avg(scale=1.0, seeds=30, **kw):
    res = [simulate(scale=scale, seed=s, **kw) for s in range(seeds)]
    out = {}
    for k in res[0]['snap']:
        out[k] = {f: sum(r['snap'][k][f] for r in res) / seeds for f in ('spent', 'pct', 'level', 'coins', 'n_owned', 'quests')}
        out[k]['income'] = {f: sum(r['snap'][k]['income'][f] for r in res) / seeds for f in ('route', 'niveaux', 'defis')}
    alls = [r['all_at'] for r in res]
    done = [a for a in alls if a]
    out['all_at'] = (sum(done) / len(done) if done else None, len(done), seeds)
    out['total'] = res[0]['total']
    # median run at which each item is bought
    first = {}
    for r in res:
        for key, k in r['bought_at'].items():
            first.setdefault(key, []).append(k)
    out['items'] = {f'{a}{b}': (sorted(v)[len(v) // 2], len(v)) for (a, b), v in first.items()}
    out['n_items'] = res[0]['snap'][max(res[0]['snap'])]['n_items']
    return out


if __name__ == '__main__':
    for scale, name in ((1.0, 'moyen'), (0.6, 'prudent (courses 40 % plus courtes)'), (1.5, 'rapide (50 % plus longues)')):
        o = avg(scale)
        print('==', name, '| boutique', o['total'], 'pièces,', o['n_items'], 'achats')
        for k in (20, 50, 100, 200, 400, 800):
            s = o[k]
            print(f"  course {k:4d} : niveau {s['level']:.0f}, dépensé {s['spent']:.0f} ({s['pct']:.0f} %), achats {s['n_owned']:.0f}, défis {s['quests']:.0f}, revenus route/niveaux/défis {s['income']['route']:.0f}/{s['income']['niveaux']:.0f}/{s['income']['defis']:.0f}")
        print('  tout acheté à la course', o['all_at'])
        if scale == 1.0:
            print('  achats (course médiane) :', sorted(o['items'].items(), key=lambda kv: kv[1][0]))
