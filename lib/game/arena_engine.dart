import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';

/// Top-down action arena shared by the survival / shooter games.
///
/// One engine, seven flavours ([ArenaKind]); each flavour changes the
/// player weapon, the enemy roster, the map and the goal. Everything is
/// deterministic so the shell can validate levels with a bot and resume
/// by input replay.
enum ArenaKind { zombie, dungeon, defense, robot, hunter, island, shooter }

/// Enemy behaviours.
const kWalker = 0, kRunner = 1, kTank = 2, kSpitter = 3, kCharger = 4, kSplitter = 5, kBomber = 6, kBoss = 7, kMini = 8;

class Mob {
  final int type;
  double x, y;
  double vx = 0, vy = 0;
  double hp;
  final double maxHp;
  final double speed;
  final double r;
  final double dmg;
  int cd = 0;
  int state = 0; // charger/bomber/boss phases
  int timer = 0;
  int flash = 0;
  double ax = 0, ay = 0; // charge direction / shooter anchor
  Mob(this.type, this.x, this.y, this.hp, this.speed, this.r, this.dmg) : maxHp = hp;
}

class Bullet {
  double x, y, vx, vy;
  final double r;
  final double dmg;
  final bool enemy;
  int life;
  int pierce;
  Bullet(this.x, this.y, this.vx, this.vy, this.r, this.dmg, this.enemy, this.life, {this.pierce = 0});
}

/// kind: 0 xp gem, 1 heal, 2 coin, 3 wood, 4 stone, 5 food
class Pickup {
  double x, y;
  final int kind;
  final int value;
  int life;
  Pickup(this.x, this.y, this.kind, this.value, {this.life = 900});
}

/// Island resource node: 0 tree, 1 rock, 2 berry bush.
class Node {
  final double x, y;
  final int kind;
  int amount;
  int regrow = 0;
  Node(this.x, this.y, this.kind, this.amount);
}

class Wall {
  final double x, y, w, h;
  const Wall(this.x, this.y, this.w, this.h);
  bool hits(double px, double py, double r) => px + r > x && px - r < x + w && py + r > y && py - r < y + h;
}

class WaveDef {
  /// (type, count)
  final List<(int, int)> mobs;
  final bool boss;
  const WaveDef(this.mobs, {this.boss = false});
  int get total => mobs.fold<int>(0, (a, b) => a + b.$2) + (boss ? 1 : 0);
}

class ArenaLevel {
  final ArcadeMeta meta;
  final ArenaKind kind;
  final List<WaveDef> waves; // empty in endless modes (generated on the fly)
  final List<Wall> walls;
  final double hpScale;
  final double speedScale;
  final double dmgScale;
  final int spawnEvery;
  final int days; // island goal
  final int theme;
  final bool elites;
  const ArenaLevel({
    required this.meta,
    required this.kind,
    required this.waves,
    required this.walls,
    required this.hpScale,
    required this.speedScale,
    required this.dmgScale,
    required this.spawnEvery,
    required this.days,
    required this.theme,
    required this.elites,
  });
}

/// Enemy roster per flavour (types that may appear, unlocked by difficulty).
List<int> rosterOf(ArenaKind k, int d) {
  final all = switch (k) {
    ArenaKind.zombie => [kWalker, kRunner, kTank, kSpitter, kBomber, kSplitter],
    ArenaKind.dungeon => [kWalker, kSpitter, kCharger, kTank, kSplitter, kRunner],
    ArenaKind.defense => [kWalker, kRunner, kTank, kSpitter, kSplitter],
    ArenaKind.robot => [kWalker, kSpitter, kCharger, kTank, kBomber, kRunner],
    ArenaKind.hunter => [kRunner, kWalker, kSpitter, kCharger],
    ArenaKind.island => [kWalker, kRunner, kCharger],
    ArenaKind.shooter => [kWalker, kRunner, kSpitter, kTank, kBomber],
  };
  return all.take((2 + d ~/ 2).clamp(2, all.length)).toList();
}

bool usesMelee(ArenaKind k) => k == ArenaKind.dungeon || k == ArenaKind.hunter || k == ArenaKind.island;

WaveDef makeWave(ArenaKind k, int d, int w, bool boss, int Function(int) pick) {
  final roster = rosterOf(k, d);
  final n = (5 + d + w * 2).clamp(4, 28);
  final counts = <int, int>{};
  for (var i = 0; i < n; i++) {
    final t = i < n ~/ 2 ? roster[0] : roster[pick(roster.length)];
    counts[t] = (counts[t] ?? 0) + 1;
  }
  return WaveDef([for (final e in counts.entries) (e.key, e.value)], boss: boss);
}

ArenaLevel generateArena(ArenaKind kind, LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final d = spec.difficulty;
  final rng = _Lcg(spec.seed);
  final waves = <WaveDef>[];
  if (m.goal && kind != ArenaKind.island) {
    final bossLevel = spec.has('boss') || (spec.levelId > 0 && spec.levelId % 5 == 0) || kind == ArenaKind.hunter;
    final count = kind == ArenaKind.hunter ? 1 : (2 + d ~/ 3).clamp(2, 5);
    for (var w = 0; w < count; w++) {
      final last = w == count - 1;
      waves.add(makeWave(kind, d, w, last && bossLevel, rng.next));
    }
  }
  final walls = <Wall>[];
  if (kind == ArenaKind.dungeon || kind == ArenaKind.robot || (kind == ArenaKind.zombie && d >= 4)) {
    final layout = rng.next(4);
    switch (layout) {
      case 0:
        walls.addAll(const [
          Wall(220, 480, 110, 110),
          Wall(670, 480, 110, 110),
          Wall(220, 900, 110, 110),
          Wall(670, 900, 110, 110),
        ]);
      case 1:
        walls.addAll(const [Wall(445, 520, 110, 110), Wall(180, 820, 110, 110), Wall(710, 820, 110, 110)]);
      case 2:
        walls.addAll(const [Wall(300, 640, 90, 90), Wall(610, 640, 90, 90), Wall(455, 940, 90, 90)]);
      default:
        walls.addAll(const [Wall(150, 600, 90, 90), Wall(455, 760, 90, 90), Wall(760, 600, 90, 90)]);
    }
  }
  return ArenaLevel(
    meta: m,
    kind: kind,
    waves: waves,
    walls: walls,
    hpScale: 1 + d * 0.12,
    speedScale: 0.85 + d * 0.035,
    dmgScale: 0.8 + d * 0.06,
    spawnEvery: (34 - d * 2).clamp(14, 34),
    days: m.goal ? (1 + d ~/ 3).clamp(1, 4) : 0,
    theme: spec.theme,
    elites: spec.has('elites') || d >= 8,
  );
}

class _Lcg {
  int s;
  _Lcg(int seed) : s = seed & 0x7fffffff;
  int next(int n) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return (s >> 8) % n;
  }
}

/// Player upgrades granted on level-up.
const kUpgrades = ['dmg', 'rate', 'multi', 'speed', 'pierce', 'range', 'heal', 'magnet'];

class ArenaSim extends ArcadeSim {
  final ArenaLevel level;
  ArenaKind get kind => level.kind;

  // player
  double px = kWorldW / 2, py = 1300;
  double php = 100, pmax = 100;
  double aimX = 0, aimY = -1;
  double anchorX = -1, anchorY = -1;
  int fireCd = 0;
  int swing = 0; // melee swing animation ticks
  double swingAng = 0;
  int hurt = 0;

  // weapon stats
  double dmg = 10;
  int rate = 22;
  int multi = 1;
  double moveSpeed = 9;
  int pierce = 0;
  double range = 520;
  double magnet = 90;
  int xp = 0, plevel = 1;
  String lastUpgrade = '';
  int upgradeShow = 0;

  final List<Mob> mobs = [];
  final List<Bullet> bullets = [];
  final List<Pickup> pickups = [];
  final List<Node> nodes = [];
  final List<(double, double, int)> booms = []; // x, y, ticks left

  // waves
  int wave = 0;
  int toSpawn = 0;
  final List<int> queue = [];
  bool bossPending = false;
  int spawnCd = 0;
  int waveGap = 0;
  Mob? boss;

  // island
  int wood = 0, stone = 0, food = 0;
  double hunger = 100;
  int day = 1;
  int dayTick = 0;
  static const dayLen = 60 * 40;
  bool get night => kind == ArenaKind.island && dayTick > dayLen * 0.6;

  // defense
  double baseHp = 150;

  // stats
  int kills = 0, bossKills = 0, wavesCleared = 0, gathered = 0;
  int lastKill = 0;
  int lastEvent = 0; // 1 kill, 2 hurt, 3 level up, 4 boss down, 5 pickup

  ArenaSim(this.level) : super(level.meta, lives: 3) {
    switch (kind) {
      case ArenaKind.dungeon:
        dmg = 16;
        rate = 26;
        range = 150;
        pmax = php = 120;
      case ArenaKind.hunter:
        dmg = 18;
        rate = 24;
        range = 170;
        pmax = php = 140;
      case ArenaKind.island:
        dmg = 12;
        rate = 24;
        range = 140;
      case ArenaKind.defense:
        py = 1330;
        range = 1300;
        rate = 14;
        dmg = 16;
        multi = 2;
      case ArenaKind.shooter:
        py = 1350;
        range = 1500;
        rate = 10;
        dmg = 7;
        moveSpeed = 12;
      case ArenaKind.robot:
        rate = 16;
        dmg = 9;
      case ArenaKind.zombie:
        break;
    }
    // Equipment tier grows with the campaign (monster hunter gear, etc.).
    final tier = (meta.difficulty - 1) ~/ 3;
    dmg *= 1 + tier * 0.15;
    if (kind == ArenaKind.island) _seedIsland();
    _nextWave();
  }

  void _seedIsland() {
    for (var i = 0; i < 9; i++) {
      nodes.add(Node(120 + rng.nextDouble() * 760, 220 + rng.nextDouble() * 1120, 0, 6));
    }
    for (var i = 0; i < 6; i++) {
      nodes.add(Node(120 + rng.nextDouble() * 760, 220 + rng.nextDouble() * 1120, 1, 5));
    }
    for (var i = 0; i < 5; i++) {
      nodes.add(Node(120 + rng.nextDouble() * 760, 220 + rng.nextDouble() * 1120, 2, 4));
    }
  }

  // ------------------------------------------------------------- waves
  int get totalWaves => level.waves.length;

  void _nextWave() {
    if (kind == ArenaKind.island) return;
    wave++;
    queue.clear();
    WaveDef def;
    if (meta.goal) {
      if (wave > totalWaves) return;
      def = level.waves[wave - 1];
    } else {
      def = makeWave(kind, (meta.difficulty + wave ~/ 2).clamp(1, 10), wave, wave % 5 == 0 && !meta.zen, rng.nextInt);
    }
    for (final (t, c) in def.mobs) {
      for (var i = 0; i < c; i++) {
        queue.add(t);
      }
    }
    rng.shuffle(queue);
    bossPending = def.boss;
    if (kind == ArenaKind.hunter) {
      bossPending = true;
    }
    spawnCd = 40;
  }

  (double, double) _edgePoint() {
    switch (kind) {
      case ArenaKind.defense:
      case ArenaKind.shooter:
        return (80 + rng.nextDouble() * 840, -40);
      default:
        final side = rng.nextInt(4);
        final t = rng.nextDouble();
        return switch (side) {
          0 => (t * kWorldW, -40.0),
          1 => (kWorldW + 40, t * kWorldH),
          2 => (t * kWorldW, kWorldH + 40),
          _ => (-40.0, t * kWorldH),
        };
    }
  }

  Mob makeMob(int type, double x, double y, {double scale = 1}) {
    final hs = level.hpScale * scale;
    final ss = level.speedScale;
    final ds = level.dmgScale;
    final elite = level.elites && rng.chance(0.12);
    final e = elite ? 1.8 : 1.0;
    final m = switch (type) {
      kRunner => Mob(type, x, y, 14 * hs * e, 4.2 * ss, 26, 8 * ds),
      kTank => Mob(type, x, y, 70 * hs * e, 1.6 * ss, 50, 20 * ds),
      kSpitter => Mob(type, x, y, 22 * hs * e, 2.2 * ss, 30, 9 * ds),
      kCharger => Mob(type, x, y, 34 * hs * e, 2.0 * ss, 36, 18 * ds),
      kSplitter => Mob(type, x, y, 30 * hs * e, 2.0 * ss, 38, 10 * ds),
      kBomber => Mob(type, x, y, 18 * hs * e, 3.0 * ss, 30, 26 * ds),
      kMini => Mob(type, x, y, 8 * hs, 3.4 * ss, 20, 5 * ds),
      kBoss => Mob(type, x, y, (kind == ArenaKind.hunter ? 900 : 500) * hs, 1.9 * ss, 90, 24 * ds),
      _ => Mob(type, x, y, 22 * hs * e, 2.4 * ss, 32, 10 * ds),
    };
    if (kind == ArenaKind.shooter || kind == ArenaKind.defense) {
      m.ax = clampD(x, 140, kWorldW - 140);
      m.ay = 260 + rng.nextDouble() * 360; // gunship hover line
    }
    return m;
  }

  void _spawn() {
    if (kind == ArenaKind.island) {
      if (!night) return;
      final alive = mobs.length;
      if (alive < 3 + day * 2 && ticks % level.spawnEvery == 0) {
        final roster = rosterOf(kind, meta.difficulty);
        final (x, y) = _edgePoint();
        mobs.add(makeMob(roster[rng.nextInt(roster.length)], x, y));
      }
      return;
    }
    if (waveGap > 0) {
      waveGap--;
      if (waveGap == 0) _nextWave();
      return;
    }
    if (spawnCd > 0) {
      spawnCd--;
      return;
    }
    final cap = 10 + meta.difficulty;
    if (queue.isNotEmpty && mobs.length < cap) {
      final (x, y) = _edgePoint();
      mobs.add(makeMob(queue.removeLast(), x, y));
      spawnCd = level.spawnEvery;
    } else if (queue.isEmpty && bossPending && (mobs.isEmpty || kind == ArenaKind.hunter)) {
      bossPending = false;
      final b = makeMob(kBoss, kWorldW / 2, kind == ArenaKind.shooter || kind == ArenaKind.defense ? -80 : 200);
      boss = b;
      mobs.add(b);
    }
  }

  bool get waveDone => queue.isEmpty && !bossPending && mobs.isEmpty;

  // ------------------------------------------------------------- update
  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (upgradeShow > 0) upgradeShow--;
    if (hurt > 0) hurt--;
    if (swing > 0) swing--;
    _move(input);
    _spawn();
    _attack();
    _mobs();
    _bullets();
    _pickups();
    if (kind == ArenaKind.island) _island();
    for (var i = booms.length - 1; i >= 0; i--) {
      final b = booms[i];
      if (b.$3 <= 1) {
        booms.removeAt(i);
      } else {
        booms[i] = (b.$1, b.$2, b.$3 - 1);
      }
    }
    // regen
    if (ticks % 60 == 0 && php < pmax) php = math.min(pmax, php + (kind == ArenaKind.island ? 0 : 1));
    if (kind != ArenaKind.island && waveDone && waveGap == 0 && !over) {
      wavesCleared++;
      score += 150 * wave;
      if (meta.goal && wave >= totalWaves) {
        win();
      } else {
        waveGap = 90;
      }
    }
  }

  void _move(ArcadeInput input) {
    double dx = 0, dy = 0;
    if (input.down && input.hasPointer) {
      if (input.tap || anchorX < 0) {
        anchorX = input.x;
        anchorY = input.y;
      }
      dx = input.x - anchorX;
      dy = input.y - anchorY;
      final l = math.sqrt(dx * dx + dy * dy);
      if (l < 10) {
        dx = dy = 0;
      } else {
        final k = math.min(1.0, l / 90) / l;
        dx *= k;
        dy *= k;
      }
    } else {
      anchorX = anchorY = -1;
      dx = input.dirX.toDouble();
      dy = input.dirY.toDouble();
      final l = math.sqrt(dx * dx + dy * dy);
      if (l > 0) {
        dx /= l;
        dy /= l;
      }
    }
    if (kind == ArenaKind.defense) dy = 0;
    final sp = moveSpeed;
    final nx = px + dx * sp, ny = py + dy * sp;
    final minY = kind == ArenaKind.shooter ? 700.0 : 60.0;
    final maxY = kind == ArenaKind.shooter ? 1540.0 : 1540.0;
    if (!_blocked(nx, py, 28)) px = clampD(nx, 40, kWorldW - 40);
    if (!_blocked(px, ny, 28)) py = clampD(ny, minY, maxY);
    if (dx != 0 || dy != 0) {
      aimX = dx;
      aimY = dy;
    }
  }

  bool _blocked(double x, double y, double r) {
    for (final w in level.walls) {
      if (w.hits(x, y, r)) return true;
    }
    return false;
  }

  Mob? nearest(double maxD) {
    Mob? best;
    var bd = maxD * maxD;
    for (final m in mobs) {
      final d = (m.x - px) * (m.x - px) + (m.y - py) * (m.y - py);
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    return best;
  }

  void _attack() {
    if (fireCd > 0) {
      fireCd--;
      return;
    }
    if (usesMelee(kind)) {
      final reach = range + 30;
      final t = nearest(reach + 60);
      if (t == null) return;
      swing = 12;
      swingAng = math.atan2(t.y - py, t.x - px);
      var any = false;
      for (final m in [...mobs]) {
        final d = math.sqrt((m.x - px) * (m.x - px) + (m.y - py) * (m.y - py));
        if (d - m.r > reach) continue;
        final a = math.atan2(m.y - py, m.x - px);
        var diff = (a - swingAng).abs();
        if (diff > math.pi) diff = 2 * math.pi - diff;
        if (diff < 1.1 + multi * 0.25) {
          _damage(m, dmg);
          any = true;
          // knockback
          if (m.type != kBoss) {
            m.x += math.cos(a) * 26;
            m.y += math.sin(a) * 26;
          }
        }
      }
      fireCd = rate;
      if (!any) fireCd = 6;
      return;
    }
    double vx, vy;
    if (kind == ArenaKind.defense) {
      Mob? low;
      for (final m in mobs) {
        if (m.y > 0 && (low == null || m.y > low.y)) low = m;
      }
      if (low == null) return;
      final dx = low.x - px, dy = low.y - py;
      final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      vx = dx / l;
      vy = dy / l;
    } else if (kind == ArenaKind.shooter) {
      vx = 0;
      vy = -1;
      Mob? t;
      var bd = 1e12;
      for (final m in mobs) {
        final dy = py - m.y;
        if (dy < 60 || m.y < 0) continue;
        final dx = (m.x - px).abs();
        if (dx > dy * 0.55) continue;
        if (dx + dy * 0.3 < bd) {
          bd = dx + dy * 0.3;
          t = m;
        }
      }
      if (t != null) {
        final dx = t.x - px, dy = t.y - py;
        final l = math.sqrt(dx * dx + dy * dy);
        vx = dx / l;
        vy = dy / l;
      }
    } else {
      final t = nearest(range);
      if (t == null) return;
      final dx = t.x - px, dy = t.y - py;
      final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      vx = dx / l;
      vy = dy / l;
    }
    const spd = 22.0;
    for (var i = 0; i < multi; i++) {
      final off = (i == 0 ? 0 : ((i + 1) ~/ 2) * (i.isOdd ? 1 : -1)) * 0.14;
      final c = math.cos(off), s = math.sin(off);
      final bx = vx * c - vy * s, by = vx * s + vy * c;
      bullets.add(Bullet(px + bx * 40, py + by * 40, bx * spd, by * spd, 10, dmg, false, 80, pierce: pierce));
    }
    fireCd = rate;
  }

  void _damage(Mob m, double d) {
    m.hp -= d;
    m.flash = 5;
    if (m.hp > 0 || !mobs.contains(m)) return;
    mobs.remove(m);
    kills++;
    lastKill = ticks;
    lastEvent = 1;
    score += switch (m.type) {
      kTank => 40,
      kBoss => 1000,
      kMini => 5,
      _ => 15,
    };
    if (m.type == kBoss) {
      bossKills++;
      lastEvent = 4;
      boss = null;
      for (var i = 0; i < 6; i++) {
        pickups.add(Pickup(m.x + rng.nextDouble() * 120 - 60, m.y + rng.nextDouble() * 120 - 60, 0, 5));
      }
    }
    if (m.type == kSplitter) {
      for (var i = 0; i < 2; i++) {
        final mx = m.x + (i == 0 ? -30 : 30);
        mobs.add(makeMob(kMini, _blocked(mx, m.y, 20) ? m.x : mx, m.y));
      }
    }
    if (m.type == kBomber) _explode(m.x, m.y, 0, friendly: true);
    pickups.add(Pickup(m.x, m.y, 0, m.type == kTank ? 3 : 1));
    if (rng.chance(0.04)) pickups.add(Pickup(m.x + 20, m.y, 1, 25));
    if (rng.chance(0.08)) pickups.add(Pickup(m.x - 20, m.y, 2, 5));
  }

  void _explode(double x, double y, double dmg, {bool friendly = false}) {
    booms.add((x, y, 20));
    if (!friendly) {
      if ((px - x) * (px - x) + (py - y) * (py - y) < 150 * 150) hurtPlayer(dmg);
    } else {
      for (final m in [...mobs]) {
        if ((m.x - x) * (m.x - x) + (m.y - y) * (m.y - y) < 140 * 140) _damage(m, 20);
      }
    }
  }

  void hurtPlayer(double d) {
    if (shield > 0 || meta.zen || over) return;
    php -= d;
    hurt = 10;
    lastEvent = 2;
    if (php <= 0) {
      php = pmax;
      hit();
    }
  }

  void _mobs() {
    final defenseLine = 1430.0;
    for (final m in [...mobs]) {
      if (m.flash > 0) m.flash--;
      if (m.cd > 0) m.cd--;
      final dx = px - m.x, dy = py - m.y;
      final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      var (tx, ty) = kind == ArenaKind.defense || kind == ArenaKind.shooter ? (dx / d, dy / d) : chaseDir(m.x, m.y);
      var sp = m.speed;
      if (kind == ArenaKind.defense) {
        // March to the base, weave a little.
        tx = math.sin((ticks + m.ax) / 40) * 0.3;
        ty = 1;
        if (m.type == kSpitter && m.y >= m.ay) {
          ty = 0;
          if (m.cd == 0) {
            _shootAt(m, 9);
            m.cd = 90;
          }
        }
        if (m.type == kBoss) {
          ty = m.y < 260 ? 1 : 0;
          tx = math.sin(ticks / 70);
          if (m.cd == 0) {
            _ring(m, 10, 7);
            m.cd = 100;
          }
        }
        m.x += tx * sp;
        m.y += ty * sp;
        m.x = clampD(m.x, 40, kWorldW - 40);
        if (m.y > defenseLine) {
          mobs.remove(m);
          baseHp -= m.type == kTank ? 25 : 10;
          lastEvent = 2;
          if (baseHp <= 0) {
            baseHp = 150;
            hit();
          }
          continue;
        }
        _touch(m, d);
        continue;
      }
      if (kind == ArenaKind.shooter) {
        _shooterMob(m);
        _touch(m, d);
        continue;
      }
      switch (m.type) {
        case kSpitter:
          final cornered = m.x < 170 || m.x > kWorldW - 170 || m.y < 170 || m.y > kWorldH - 170;
          if (usesMelee(kind)) {
            if (d < 300 && !lineBlocked(m.x, m.y, px, py, 10)) sp = 0;
          } else if (d < 380 && !cornered) {
            tx = -tx;
            ty = -ty;
            sp *= 0.6;
          } else if (d < 560) {
            sp = 0;
          }
          if (cornered && d < 380 && !usesMelee(kind)) sp = 0;
          if (m.cd == 0 && d < 750) {
            _shootAt(m, 8);
            m.cd = 110;
          }
        case kCharger:
          if (m.state == 0) {
            if (d < 420 && m.cd == 0) {
              m.state = 1;
              m.timer = 40;
              m.ax = tx;
              m.ay = ty;
            }
          } else if (m.state == 1) {
            sp = 0;
            if (--m.timer <= 0) {
              m.state = 2;
              m.timer = 30;
            }
          } else {
            tx = m.ax;
            ty = m.ay;
            sp = m.speed * 5;
            if (--m.timer <= 0) {
              m.state = 0;
              m.cd = 90;
            }
          }
        case kBomber:
          if (d < 110 && m.state == 0) {
            m.state = 1;
            m.timer = 45;
          }
          if (m.state == 1) {
            sp = 0;
            if (--m.timer <= 0) {
              mobs.remove(m);
              _explode(m.x, m.y, m.dmg);
              continue;
            }
          }
        case kBoss:
          _bossAi(m, d, tx, ty);
          continue;
        default:
          break;
      }
      _step(m, tx * sp, ty * sp);
      m.x = clampD(m.x, m.r, kWorldW - m.r);
      m.y = clampD(m.y, m.r, kWorldH - m.r);
      _touch(m, d);
    }
    // separation
    for (var i = 0; i < mobs.length; i++) {
      for (var j = i + 1; j < mobs.length; j++) {
        final a = mobs[i], b = mobs[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final min = (a.r + b.r) * 0.8;
        final dd = dx * dx + dy * dy;
        if (dd < min * min && dd > 0.01) {
          final l = math.sqrt(dd);
          final push = (min - l) / 2 / l;
          if (a.type != kBoss) {
            a.x -= dx * push;
            a.y -= dy * push;
          }
          if (b.type != kBoss) {
            b.x += dx * push;
            b.y += dy * push;
          }
        }
      }
    }
  }

  Wall? _wallAt(double x, double y, double r) {
    for (final w in level.walls) {
      if (w.hits(x, y, r)) return w;
    }
    return null;
  }

  // ---- coarse grid path finding (only used when the map has walls)
  static const cell = 50.0;
  static const gw = 20, gh = 32;
  List<bool>? _solid;
  List<bool> get solid => _solid ??= [
    for (var j = 0; j < gh; j++)
      for (var i = 0; i < gw; i++) _wallAt((i + 0.5) * cell, (j + 0.5) * cell, 34) != null,
  ];

  /// BFS distance (in cells) from the cell of (x, y); -1 = unreachable.
  List<int> distField(double x, double y) {
    final d = List.filled(gw * gh, -1);
    final s0 = (clampD(y, 0, kWorldH - 1) ~/ cell) * gw + (clampD(x, 0, kWorldW - 1) ~/ cell);
    final q = <int>[s0];
    d[s0] = 0;
    for (var h = 0; h < q.length; h++) {
      final c = q[h];
      final ci = c % gw, cj = c ~/ gw;
      for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final ni = ci + di, nj = cj + dj;
        if (ni < 0 || nj < 0 || ni >= gw || nj >= gh) continue;
        final n = nj * gw + ni;
        if (d[n] >= 0 || solid[n]) continue;
        d[n] = d[c] + 1;
        q.add(n);
      }
    }
    return d;
  }

  List<int>? _flow;
  int _flowAt = -999;

  bool lineBlocked(double x0, double y0, double x1, double y1, double r) {
    if (level.walls.isEmpty) return false;
    final steps = (math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) / 25).ceil();
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      if (_wallAt(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r) != null) return true;
    }
    return false;
  }

  /// Direction a mob at (x, y) should walk to reach the player.
  (double, double) chaseDir(double x, double y) {
    final dx = px - x, dy = py - y;
    final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    if (level.walls.isEmpty || !lineBlocked(x, y, px, py, 26)) return (dx / d, dy / d);
    if (ticks - _flowAt >= 10 || _flow == null) {
      _flow = distField(px, py);
      _flowAt = ticks;
    }
    final f = _flow!;
    final ci = clampD(x, 0, kWorldW - 1) ~/ cell, cj = clampD(y, 0, kWorldH - 1) ~/ cell;
    var best = 1 << 30;
    var bx = dx / d, by = dy / d;
    for (var dj = -1; dj <= 1; dj++) {
      for (var di = -1; di <= 1; di++) {
        if (di == 0 && dj == 0) continue;
        final ni = ci + di, nj = cj + dj;
        if (ni < 0 || nj < 0 || ni >= gw || nj >= gh) continue;
        final v = f[nj * gw + ni];
        if (v < 0) continue;
        // diagonal moves must not cut a solid corner
        if (di != 0 && dj != 0 && (solid[cj * gw + ni] || solid[nj * gw + ci])) continue;
        if (v < best) {
          best = v;
          final tx = (ni + 0.5) * cell - x, ty = (nj + 0.5) * cell - y;
          final l = math.max(1.0, math.sqrt(tx * tx + ty * ty));
          bx = tx / l;
          by = ty / l;
        }
      }
    }
    return (bx, by);
  }

  void _step(Mob m, double vx, double vy) {
    final r = math.min(m.r * 0.5, 22.0);
    if (_wallAt(m.x + vx, m.y, r) == null) m.x += vx;
    if (_wallAt(m.x, m.y + vy, r) == null) m.y += vy;
  }

  void _touch(Mob m, double d) {
    if (d < m.r + 30 && m.cd <= 0 && m.type != kBomber) {
      hurtPlayer(m.dmg);
      m.cd = 45;
      if (m.type == kCharger && m.state == 2) {
        m.state = 0;
        m.cd = 90;
      }
    }
  }

  void _shooterMob(Mob m) {
    switch (m.type) {
      case kRunner: // weaver
        m.y += m.speed * 1.2;
        m.x = m.ax + math.sin((ticks + m.ay) / 25) * 160;
      case kSpitter: // gunship: descend to hover line then fire
        if (m.y < m.ay) {
          m.y += m.speed * 1.5;
        } else if (m.cd == 0) {
          _shootAt(m, 9);
          m.cd = 80;
        }
        m.x = clampD(m.x + math.sin(ticks / 50 + m.ax) * 1.5, 140, kWorldW - 140);
      case kBomber: // kamikaze aims at player
        final dx = px - m.x, dy = py - m.y;
        final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        m.x += dx / l * m.speed * 1.3;
        m.y += dy / l * m.speed * 1.3;
      case kBoss:
        if (m.y < 260) {
          m.y += 2;
        } else {
          m.x = kWorldW / 2 + math.sin(ticks / 90) * 320;
          if (m.cd == 0) {
            if (m.state.isEven) {
              _ring(m, 10, 6);
            } else {
              for (var i = -2; i <= 2; i++) {
                _shootAt(m, 10, spread: i * 0.18);
              }
            }
            m.state++;
            m.cd = 95;
          }
        }
      default:
        m.y += m.speed * 1.4;
        if (m.type == kTank && m.cd == 0 && m.y > 100) {
          _shootAt(m, 7);
          m.cd = 120;
        }
    }
    m.x = clampD(m.x, 30, kWorldW - 30);
    if (m.y > kWorldH + 60) mobs.remove(m);
  }

  void _bossAi(Mob m, double d, double tx, double ty) {
    // Phase 2 under half health: faster attacks.
    final enraged = m.hp < m.maxHp / 2;
    if (m.state == 0) {
      _step(m, tx * m.speed, ty * m.speed);
      if (m.cd == 0) {
        m.state = 1 + (m.timer++ % 3);
        m.cd = 50;
      }
    } else if (m.state == 1) {
      // radial burst
      if (m.cd == 20) _ring(m, enraged ? 16 : 10, 7);
      if (m.cd == 0) {
        m.state = 0;
        m.cd = enraged ? 70 : 110;
      }
    } else if (m.state == 2) {
      // telegraphed charge
      if (m.cd == 49) {
        m.ax = tx;
        m.ay = ty;
      }
      if (m.cd < 20) _step(m, m.ax * m.speed * 6, m.ay * m.speed * 6);
      if (m.cd == 0) {
        m.state = 0;
        m.cd = enraged ? 70 : 110;
      }
    } else {
      // summon minions
      if (m.cd == 25 && mobs.length < 14) {
        for (var i = 0; i < (enraged ? 4 : 2); i++) {
          mobs.add(makeMob(kind == ArenaKind.hunter ? kRunner : kMini, m.x + (i - 1.5) * 50, m.y + 60));
        }
      }
      if (m.cd == 0) {
        m.state = 0;
        m.cd = enraged ? 70 : 110;
      }
    }
    _touch(m, d);
    m.x = clampD(m.x, 60, kWorldW - 60);
    m.y = clampD(m.y, 60, kWorldH - 60);
  }

  void _shootAt(Mob m, double speed, {double spread = 0}) {
    final dx = px - m.x, dy = py - m.y;
    final a = math.atan2(dy, dx) + spread;
    bullets.add(Bullet(m.x, m.y, math.cos(a) * speed, math.sin(a) * speed, 12, m.dmg, true, 240));
  }

  void _ring(Mob m, int n, double speed) {
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n + ticks * 0.01;
      bullets.add(Bullet(m.x, m.y, math.cos(a) * speed, math.sin(a) * speed, 12, m.dmg * 0.6, true, 240));
    }
  }

  void _bullets() {
    for (final b in [...bullets]) {
      b.x += b.vx;
      b.y += b.vy;
      b.life--;
      if (b.life <= 0 || b.x < -50 || b.x > kWorldW + 50 || b.y < -80 || b.y > kWorldH + 50) {
        bullets.remove(b);
        continue;
      }
      if (b.enemy) {
        if ((b.x - px) * (b.x - px) + (b.y - py) * (b.y - py) < (b.r + 28) * (b.r + 28)) {
          bullets.remove(b);
          hurtPlayer(b.dmg);
        }
        continue;
      }
      for (final m in mobs) {
        final rr = m.r + b.r;
        if ((b.x - m.x) * (b.x - m.x) + (b.y - m.y) * (b.y - m.y) < rr * rr) {
          _damage(m, b.dmg);
          if (b.pierce-- <= 0) bullets.remove(b);
          break;
        }
      }
    }
  }

  void _pickups() {
    for (final p in [...pickups]) {
      final dx = px - p.x, dy = py - p.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < magnet * magnet) {
        final d = math.sqrt(d2);
        p.x += dx / math.max(1, d) * 14;
        p.y += dy / math.max(1, d) * 14;
      }
      if (d2 < 44 * 44) {
        pickups.remove(p);
        lastEvent = 5;
        switch (p.kind) {
          case 0:
            xp += p.value;
            if (xp >= xpNeed) {
              xp -= xpNeed;
              _levelUp();
            }
          case 1:
            php = math.min(pmax, php + p.value);
          case 2:
            score += p.value * 5;
          case 3:
            wood += p.value;
          case 4:
            stone += p.value;
          default:
            food += p.value;
            hunger = math.min(100, hunger + 25);
        }
        continue;
      }
      if (--p.life <= 0) pickups.remove(p);
    }
  }

  int get xpNeed => 6 + plevel * 4;

  void _levelUp() {
    plevel++;
    lastEvent = 3;
    final u = kUpgrades[rng.nextInt(kUpgrades.length)];
    lastUpgrade = u;
    upgradeShow = 120;
    switch (u) {
      case 'dmg':
        dmg *= 1.2;
      case 'rate':
        rate = math.max(6, (rate * 0.85).round());
      case 'multi':
        if (multi < 5) {
          multi++;
        } else {
          dmg *= 1.15;
        }
      case 'speed':
        moveSpeed = math.min(14, moveSpeed + 0.8);
      case 'pierce':
        pierce = math.min(4, pierce + 1);
        if (usesMelee(kind)) range += 15;
      case 'range':
        range += usesMelee(kind) ? 25 : 80;
      case 'heal':
        pmax += 15;
        php = pmax;
      default:
        magnet += 50;
    }
  }

  // ------------------------------------------------------------- island
  int get woodGoal => 10 + meta.difficulty * 2;
  int get stoneGoal => 4 + meta.difficulty;

  void _island() {
    dayTick++;
    if (dayTick >= dayLen) {
      dayTick = 0;
      day++;
      score += 300;
      wavesCleared++;
      for (final n in nodes) {
        if (n.amount == 0) n.amount = n.kind == 2 ? 3 : 4;
      }
      if (meta.goal && day > level.days && wood >= woodGoal && stone >= stoneGoal) {
        win();
        return;
      }
    }
    if (!night) {
      // Monsters flee at dawn.
      mobs.removeWhere((m) => m.type != kBoss && (m.x < 0 || m.x > kWorldW || m.y < 0 || m.y > kWorldH));
    }
    if (meta.goal && day > level.days && wood >= woodGoal && stone >= stoneGoal) win();
    hunger -= 100 / (60 * 75);
    if (hunger <= 0) {
      hunger = 0;
      if (ticks % 60 == 0) hurtPlayer(6);
    } else if (ticks % 60 == 0 && hunger > 50 && php < pmax) {
      php = math.min(pmax, php + 2);
    }
    // Gather from nearby nodes (auto, like the melee swing).
    if (ticks % 20 == 0) {
      for (final n in nodes) {
        if (n.amount <= 0) continue;
        if ((n.x - px) * (n.x - px) + (n.y - py) * (n.y - py) < 110 * 110) {
          n.amount--;
          gathered++;
          pickups.add(Pickup(n.x, n.y + 40, n.kind == 0 ? 3 : (n.kind == 1 ? 4 : 5), n.kind == 2 ? 1 : 1, life: 1200));
          break;
        }
      }
    }
  }

  // ------------------------------------------------------------- shell hooks
  @override
  void onLifeLost() {
    bullets.removeWhere((b) => b.enemy);
    for (final m in mobs) {
      final dx = m.x - px, dy = m.y - py;
      if (dx * dx + dy * dy < 300 * 300 && m.type != kBoss) {
        final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        m.x += dx / l * 250;
        m.y += dy / l * 250;
      }
    }
  }

  /// Booster: shockwave that clears nearby enemies and bullets.
  @override
  bool useBooster() {
    if (over) return false;
    bullets.removeWhere((b) => b.enemy);
    booms.add((px, py, 30));
    for (final m in [...mobs]) {
      if ((m.x - px) * (m.x - px) + (m.y - py) * (m.y - py) < 420 * 420) _damage(m, m.type == kBoss ? 120 : 400);
    }
    shield = 120;
    return true;
  }

  @override
  double get progress {
    if (kind == ArenaKind.island) {
      final dayP = ((day - 1) + dayTick / dayLen) / math.max(1, level.days);
      final res = (math.min(wood, woodGoal) / woodGoal + math.min(stone, stoneGoal) / stoneGoal) / 2;
      return math.min(dayP, 1.0) * 0.5 + res * 0.5;
    }
    if (totalWaves == 0) return 0;
    final def = level.waves[(wave - 1).clamp(0, totalWaves - 1)];
    final left = queue.length + mobs.length + (bossPending ? 1 : 0);
    final inWave = 1 - left / math.max(1, def.total);
    return ((wave - 1) + inWave.clamp(0.0, 1.0)) / totalWaves;
  }

  @override
  String get goalText {
    if (kind == ArenaKind.island) return meta.goal ? 'D$day/${level.days}' : 'D$day';
    return meta.goal ? '$wave/$totalWaves' : 'W$wave';
  }

  @override
  Map<String, int> get stats => {
    'enemies_defeated': kills,
    'waves_survived': wavesCleared,
    'bosses_defeated': bossKills,
    'resources_gathered': gathered,
    'player_level': plevel,
  };

  @override
  int get stars => lifeStars(this, 3);
}

/// Autopilot: samples 16 directions (+ standing still), scores each by
/// predicted danger (enemies, telegraphed charges, bullets, borders, walls)
/// and progress toward the current goal, and walks the best one.
ArcadeInput arenaBot(ArcadeSim sim) {
  final g = sim as ArenaSim;
  if (g.anchorX < 0) return const ArcadeInput(down: true, x: 500, y: 800, tap: true);
  final melee = usesMelee(g.kind);
  // ---- goal point
  double gx = -1, gy = -1;
  final gw = 1 + math.min(6.0, (g.ticks - g.lastKill) / 400);
  double keep = -1; // preferred distance to nearest enemy
  if (g.kind == ArenaKind.island) {
    final threat = g.nearest(2000);
    if (g.night && threat != null && g.php > 45) {
      gx = threat.x;
      gy = threat.y;
      keep = g.range * 0.7;
    } else {
      Node? best;
      var bd = 1e12;
      final needFood = g.hunger < 60;
      for (final n in g.nodes) {
        if (n.amount <= 0) continue;
        var w = 1.0;
        if (n.kind == 2) w = needFood ? 0.2 : 4;
        if (n.kind == 0 && g.wood >= g.woodGoal) w = 6;
        if (n.kind == 1) w = g.stone >= g.stoneGoal ? 6 : 0.7;
        final d = ((n.x - g.px) * (n.x - g.px) + (n.y - g.py) * (n.y - g.py)) * w;
        if (d < bd) {
          bd = d;
          best = n;
        }
      }
      if (best != null) {
        gx = best.x;
        gy = best.y + 60;
      }
    }
  } else if (g.kind == ArenaKind.defense) {
    Mob? low;
    for (final m in g.mobs) {
      if (low == null || m.y > low.y) low = m;
    }
    gx = low?.x ?? 500;
    gy = g.py;
  } else if (g.kind == ArenaKind.shooter) {
    Mob? tgt;
    var bd = 1e12;
    for (final m in g.mobs) {
      final d = (m.x - g.px).abs() + (g.py - m.y) * 0.2;
      if (m.y < g.py - 150 && m.y > 0 && d < bd) {
        bd = d;
        tgt = m;
      }
    }
    gx = tgt?.x ?? 500;
    gy = 1360;
  } else {
    final t = g.nearest(3000);
    if (t != null) {
      gx = t.x;
      gy = t.y;
      keep = melee ? g.range * 0.75 + t.r * 0.3 : 430;
    }
  }
  // pickups nearby act as secondary goals
  Pickup? pick;
  var pd = 260.0 * 260;
  for (final p in g.pickups) {
    final d = (p.x - g.px) * (p.x - g.px) + (p.y - g.py) * (p.y - g.py);
    if (d < pd) {
      pd = d;
      pick = p;
    }
  }
  final field = gx >= 0 && g.level.walls.isNotEmpty && g.lineBlocked(g.px, g.py, gx, gy, 20)
      ? g.distField(gx, gy)
      : null;
  var edgeW = 4.0;
  if (gx >= 0 && (gx < 220 || gx > kWorldW - 220 || gy < 220 || gy > kWorldH - 220)) edgeW = 0.6;
  double cost(double dx, double dy) {
    final sp = g.moveSpeed;
    var c = 0.0;
    double ppx(int k) => clampD(g.px + dx * sp * k, 40, kWorldW - 40);
    double ppy(int k) => g.kind == ArenaKind.defense ? g.py : clampD(g.py + dy * sp * k, 60, 1540);
    for (final k in const [6, 14, 24]) {
      final x = ppx(k), y = ppy(k);
      for (final w in g.level.walls) {
        if (w.hits(x, y, 36)) c += k == 6 ? 3 : 1;
      }
      if (g.kind != ArenaKind.defense) {
        final edge = math.min(
          math.min(x - 40, kWorldW - 40 - x),
          math.min(y - (g.kind == ArenaKind.shooter ? 700 : 60), 1540 - y),
        );
        if (edge < 160) c += (160 - edge) / 160 * (160 - edge) / 160 * edgeW;
      }
      for (final m in g.mobs) {
        if (g.kind == ArenaKind.defense && m.type != kBoss) continue;
        var mx = m.x, my = m.y;
        if (m.type == kCharger && m.state == 2) {
          mx += m.ax * m.speed * 5 * k;
          my += m.ay * m.speed * 5 * k;
        } else if (g.kind != ArenaKind.shooter) {
          final ddx = x - m.x, ddy = y - m.y;
          final dl = math.max(1.0, math.sqrt(ddx * ddx + ddy * ddy));
          final st = math.min(dl - 1, m.speed * k * 0.8);
          mx += ddx / dl * st;
          my += ddy / dl * st;
        } else {
          my += m.speed * 1.3 * k;
        }
        final d = math.sqrt((x - mx) * (x - mx) + (y - my) * (y - my)) - m.r;
        var R = melee ? 70.0 : 220.0;
        if (m.type == kBoss) R = melee ? (m.state == 2 ? 360 : 110) : 260;
        if (m.type == kCharger && m.state == 1) {
          // stand off the charge line
          final lx = m.ax, ly = m.ay;
          final rx = x - m.x, ry = y - m.y;
          final along = rx * lx + ry * ly;
          final off = (rx * ly - ry * lx).abs();
          if (along > 0 && off < 90) c += 3;
        }
        if (m.type == kBomber && m.state == 1) R = 200;
        if (d < R) c += (R - d) / R * (R - d) / R * (k == 6 ? 3 : 2);
      }
    }
    for (final b in g.bullets) {
      if (!b.enemy) continue;
      for (var t = 0; t <= 30; t += 3) {
        final bx = b.x + b.vx * t, by = b.y + b.vy * t;
        final x = ppx(t), y = ppy(t);
        final dd = (bx - x) * (bx - x) + (by - y) * (by - y);
        if (dd < 58 * 58) {
          c += 8 * (1 - t / 40);
          break;
        }
      }
    }
    final x = ppx(14), y = ppy(14);
    if (gx >= 0) {
      var d = math.sqrt((gx - x) * (gx - x) + (gy - y) * (gy - y));
      if (field != null) {
        final v =
            field[(clampD(y, 0, kWorldH - 1) ~/ ArenaSim.cell) * ArenaSim.gw +
                (clampD(x, 0, kWorldW - 1) ~/ ArenaSim.cell)];
        d = v < 0 ? d + 400 : v * ArenaSim.cell;
      }
      if (keep > 0) {
        c += (d - keep).abs() / 300 * gw;
      } else {
        c += d / 400 * gw;
      }
    }
    if (pick != null) {
      c += math.sqrt((pick.x - x) * (pick.x - x) + (pick.y - y) * (pick.y - y)) / 600;
    }
    return c;
  }

  var bx = 0.0, by = 0.0;
  var best = cost(0, 0);
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8;
    final dx = math.cos(a), dy = math.sin(a);
    if (g.kind == ArenaKind.defense && dx.abs() < 0.3) continue;
    final c = cost(dx, dy);
    if (c < best - 1e-6) {
      best = c;
      bx = dx;
      by = dy;
    }
  }
  return ArcadeInput(down: true, x: (500 + bx * 90).roundToDouble(), y: (800 + by * 90).roundToDouble());
}
