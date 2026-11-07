"""Economy balance simulation for LOT 13 (mirrors the formulas in scripts/game.gd and data.gd).
A simple bot plays N days: picks the best affordable auction, bids up to its estimate, repairs, sells, upgrades.
python3 tools/balance_sim.py [days] [runs]"""
import random
import sys

ITEMS = {}  # id -> (rarity, cat, value)
RAW = """rusty_wrench 0 tools 8|worn_boot 0 clothing 6|tin_kettle 0 home 12|vhs_tape 0 media 5|desk_lamp 0 home 15|
toy_car 0 toys 10|book_stack 0 media 7|claw_hammer 0 tools 9|diner_mug 0 home 4|sunglasses 0 clothing 11|
pocket_radio 0 electronics 18|basketball 0 sports 14|cassette_player 1 electronics 45|skateboard 1 sports 55|
toolbox 1 tools 60|vinyl_record 1 music 40|leather_jacket 1 clothing 70|film_camera 1 electronics 85|
tin_robot 1 toys 65|brass_compass 1 antiques 50|power_drill 1 tools 75|retro_console 1 electronics 90|
electric_guitar 2 music 220|typewriter 2 antiques 180|pocket_watch 2 jewelry 250|first_comic 2 collectibles 200|
brass_telescope 2 antiques 260|gramophone 2 music 300|signed_baseball 2 sports 240|oil_painting 2 art 280|
silver_cutlery 2 home 210|gold_ring 3 jewelry 800|ceremonial_sword 3 antiques 950|coin_album 3 collectibles 700|
music_box 3 art 1100|meteorite_shard 3 collectibles 900|treasure_map 3 antiques 750|golden_idol 4 antiques 4000|
lost_crown 4 jewelry 6500|classic_car_keys 4 collectibles 9000"""
for part in RAW.replace("\n", "").split("|"):
    i, r, c, v = part.split()
    ITEMS[i] = (int(r), c, int(v))

AUCTIONS = [
    dict(rep=1, fee=0, w=[66, 28, 5.3, 0.6, 0.1], n=(3, 4), golden=0.0, rivals=2, low=20, k=1.0),
    dict(rep=3, fee=25, w=[50, 36, 11.5, 2.3, 0.2], n=(3, 5), golden=0.0, rivals=3, low=80, k=1.04),
    dict(rep=6, fee=100, w=[30, 40, 22, 7.2, 0.8], n=(3, 5), golden=0.0, rivals=3, low=250, k=1.1),
    dict(rep=10, fee=300, w=[14, 34, 34, 15.5, 2.5], n=(4, 6), golden=0.0, rivals=3, low=700, k=1.16),
    dict(rep=15, fee=800, w=[5, 24, 40, 25, 6], n=(4, 6), golden=0.25, rivals=3, low=2000, k=1.22),
]
UPG = {"shelves": (100, 4, [10, 14, 20, 28, 40]), "bench": (120, 4, [85, 90, 95, 98, 100]),
       "scanner": (180, 4, [0, 1, 2, 3, 4]), "showroom": (250, 4, [0, 8, 16, 25, 35]),
       "truck": (400, 3, [4, 5, 6, 7]), "charm": (500, 4, [0, 15, 30, 50, 75])}
SPREAD = [0.5, 0.42, 0.33, 0.22, 0.14]
RIVAL_MULT = [(0.78, 0.98), (0.72, 0.92), (0.76, 0.95), (0.74, 0.92), (0.80, 1.0), (0.62, 0.82)]


def nice(x):
    if x < 20: return max(1, round(x))
    if x < 100: return round(x / 5) * 5
    if x < 1000: return round(x / 10) * 10
    if x < 10000: return round(x / 50) * 50
    return round(x / 100) * 100


def cm(c): return 0.2 + 0.8 * c ** 1.4


class Sim:
    def __init__(self, rng, skill=0.4, bid_k=1.0):
        self.r = rng
        self.money, self.level, self.xp = 500, 1, 0
        self.up = {k: 0 for k in UPG}
        self.items = []
        self.found = set()
        self.skill, self.bid_k = skill, bid_k
        self.earned = 0

    def val(self, k): return UPG[k][2][self.up[k]]
    def need(self, l): return round(40 * l ** 1.5)

    def add_xp(self, n):
        self.xp += n
        while self.xp >= self.need(self.level):
            self.xp -= self.need(self.level)
            self.level += 1

    def rarity(self, tier, golden):
        w = list(AUCTIONS[tier]["w"])
        luck = 1 + self.val("charm") / 100
        for i in (2, 3, 4): w[i] *= luck
        if golden: w[0] *= .15; w[1] *= .6; w[3] *= 2; w[4] *= 2.5
        return self.r.choices(range(5), weights=w)[0]

    def item(self, rr):
        return self.r.choice([i for i, d in ITEMS.items() if d[0] == rr])

    def cond(self):
        if self.r.random() < 0.05: return 1.0
        return round(0.15 + 0.8 * self.r.random() ** 1.2, 2)

    def lot(self, tier):
        a = AUCTIONS[tier]
        golden = self.r.random() < max(0.02, a["golden"])
        n = self.r.randint(*a["n"])
        if golden: n = max(n, 4)
        cont = []
        for _ in range(n):
            i = self.item(self.rarity(tier, golden))
            cont.append((i, self.cond()))
        v = sum(max(1, round(ITEMS[i][2] * cm(c))) for i, c in cont)
        s = SPREAD[self.up["scanner"]]
        center = v * self.r.uniform(1 - s * .6, 1 + s * .6)
        return cont, v, center, max(1, nice(center * self.r.uniform(0.22, 0.36))), golden

    def market(self, i, c):
        return ITEMS[i][2] * cm(c) * (1 + min(0.2, len(self.found) * 0.005))

    def day(self):
        tier = 0
        for t in range(len(AUCTIONS) - 1, -1, -1):
            a = AUCTIONS[t]
            if self.level >= a["rep"] and self.money >= a["fee"] + a["low"] * 1.5:
                tier = t
                break
        a = AUCTIONS[tier]
        self.money -= a["fee"]
        for _ in range(self.val("truck")):
            cont, v, center, start, golden = self.lot(tier)
            maxes = []
            for _ in range(a["rivals"]):
                m0, m1 = self.r.choice(RIVAL_MULT)
                maxes.append(v * self.r.uniform(0.8, 1.15) * self.r.uniform(m0, m1) * (1.2 if self.r.random() < 0.25 else 1) * (1.08 if golden else 1) * a["k"])
            mine = min(self.money, center * self.bid_k)
            top_rival = max(maxes) if maxes else 0
            if mine >= start and mine > top_rival:
                price = max(start, nice(top_rival * 1.04)) if top_rival >= start else start
                price = min(price, self.money)
                self.money -= price
                self.add_xp(3)
                for i, c in cont:
                    self.found.add(i)
                    if len(self.items) < self.val("shelves"):
                        self.items.append([i, c, price / len(cont)])
                    else:
                        p = round(self.market(i, c) * 0.45)
                        self.money += p
                        self.earned += p
        # repair and sell everything
        cap = self.val("bench") / 100
        for it in self.items:
            i, c, paid = it
            if c < cap - 0.005:
                cost = max(2, round(ITEMS[i][2] * 0.08 * max(0.05, cap - c)))
                if cost <= self.money:
                    self.money -= cost
                    it[2] += cost
                    gain = self.skill * 0.24 + (1 - self.skill) * 0.13
                    it[1] = min(cap, c + 3 * gain - 0.04)
                    self.add_xp(3)
        for i, c, paid in self.items:
            m = self.market(i, c)
            price = round(m * self.r.uniform(0.9, 1.35) * (1 + self.val("showroom") / 100) * 0.9)
            self.money += price
            self.earned += price
            self.add_xp(max(1, int(price / 5) + max(0, int((price - paid) / 4))))
        self.items = []
        # upgrades
        for k in ["bench", "shelves", "scanner", "truck", "showroom", "charm"]:
            base, mx, _ = UPG[k]
            if self.up[k] < mx:
                cost = nice(base * 2.6 ** self.up[k])
                if self.money > cost * 1.6:
                    self.money -= cost
                    self.up[k] += 1
                    self.add_xp(10 + 5 * self.up[k])
        return tier


def run(days, runs):
    marks = [1, 3, 5, 10, 15, 20, 30, 45, 60, 80, 100, 150, 200]
    table = {d: [] for d in marks if d <= days}
    for s in range(runs):
        sim = Sim(random.Random(s))
        for d in range(1, days + 1):
            tier = sim.day()
            if d in table:
                table[d].append((sim.money, sim.level, tier, sum(sim.up.values()), len(sim.found)))
    print("day   money(med)   level  tier  upgrades found")
    for d, rows in table.items():
        rows.sort()
        m = rows[len(rows) // 2]
        avg = lambda k: sum(r[k] for r in rows) / len(rows)
        print(f"{d:4d} {m[0]:12,.0f} {avg(1):7.1f} {avg(2) + 1:5.1f} {avg(3):8.1f} {avg(4):5.1f}")


if __name__ == "__main__":
    run(int(sys.argv[1]) if len(sys.argv) > 1 else 120, int(sys.argv[2]) if len(sys.argv) > 2 else 60)
