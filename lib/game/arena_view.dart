import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/arcade.dart';
import 'arena_engine.dart';

/// Painter for every arena flavour (procedural vector art, no assets).
const _upgradeIcon = {
  'dmg': '⚔ +20%',
  'rate': '⚡ +15%',
  'multi': '✦ +1',
  'speed': '👟 +',
  'pierce': '➶ +1',
  'range': '◎ +',
  'heal': '❤ +15',
  'magnet': '🧲 +',
};

Paint _p(int c) => Paint()..color = Color(c);

void _bar(Canvas c, Offset o, double w, double f, int color) {
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: w, height: 12), const Radius.circular(6)),
    _p(0x88000000),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - w / 2, o.dy - 6, w * f.clamp(0.0, 1.0), 12), const Radius.circular(6)),
    _p(color),
  );
}

void _ground(Canvas c, ArenaSim s, double t) {
  const r = Rect.fromLTWH(0, 0, kWorldW, kWorldH);
  switch (s.kind) {
    case ArenaKind.zombie:
      c.drawRect(r, _p(0xFF2B2D2F));
      final crack = Paint()
        ..color = const Color(0xFF3D4043)
        ..strokeWidth = 4;
      for (var i = 0; i < 18; i++) {
        final x = (i * 173) % kWorldW, y = (i * 311) % kWorldH;
        c.drawLine(Offset(x, y), Offset(x + 60, y + 30), crack);
        c.drawCircle(Offset((i * 271) % kWorldW, (i * 157) % kWorldH), 18, _p(0x33550000));
      }
    case ArenaKind.dungeon:
      c.drawRect(r, _p(0xFF3A3335));
      final line = Paint()
        ..color = const Color(0xFF2A2426)
        ..strokeWidth = 4;
      for (var y = 0.0; y < kWorldH; y += 100) {
        c.drawLine(Offset(0, y), Offset(kWorldW, y), line);
        for (var x = (y ~/ 100).isEven ? 0.0 : 50.0; x < kWorldW; x += 100) {
          c.drawLine(Offset(x, y), Offset(x, y + 100), line);
        }
      }
      for (final o in const [Offset(60, 60), Offset(940, 60), Offset(60, 1540), Offset(940, 1540)]) {
        c.drawCircle(o, 30 + math.sin(t * 8 + o.dx) * 4, _p(0x66FFB703));
        c.drawCircle(o, 12, _p(0xFFFFD166));
      }
    case ArenaKind.defense:
      c.drawRect(r, _p(0xFF10002B));
      for (var i = 0; i < 50; i++) {
        c.drawCircle(Offset((i * 197) % kWorldW, (i * 89 + t * 6) % 1300), 2.5, _p(0x88FFFFFF));
      }
      c.drawRect(const Rect.fromLTWH(0, 1400, kWorldW, 200), _p(0xFF5A189A));
      c.drawArc(const Rect.fromLTWH(250, 1380, 500, 260), math.pi, math.pi, true, _p(0xFF9D4EDD));
      c.drawArc(const Rect.fromLTWH(330, 1420, 340, 180), math.pi, math.pi, true, _p(0x88E0AAFF));
      _bar(c, const Offset(500, 1570), 600, s.baseHp / 150, 0xFF52B788);
    case ArenaKind.robot:
      c.drawRect(r, _p(0xFF1B263B));
      final grid = Paint()
        ..color = const Color(0xFF274060)
        ..strokeWidth = 3;
      for (var x = 0.0; x <= kWorldW; x += 125) {
        c.drawLine(Offset(x, 0), Offset(x, kWorldH), grid);
      }
      for (var y = 0.0; y <= kWorldH; y += 125) {
        c.drawLine(Offset(0, y), Offset(kWorldW, y), grid);
      }
      c.drawCircle(
        const Offset(500, 800),
        300,
        Paint()
          ..color = const Color(0xFF00B4D8).withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
    case ArenaKind.hunter:
      c.drawRect(r, _p(0xFF6A994E));
      for (var i = 0; i < 40; i++) {
        final o = Offset((i * 233) % kWorldW, (i * 401) % kWorldH);
        c.drawLine(
          o,
          o.translate(-6, -22),
          Paint()
            ..color = const Color(0xFF386641)
            ..strokeWidth = 4,
        );
        c.drawLine(
          o,
          o.translate(6, -20),
          Paint()
            ..color = const Color(0xFF386641)
            ..strokeWidth = 4,
        );
      }
    case ArenaKind.island:
      c.drawRect(r, _p(0xFF0077B6));
      c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(40, 120, 920, 1360), const Radius.circular(220)),
        _p(0xFFF4D58D),
      );
      final wave = Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(30 - math.sin(t * 2) * 6, 110, 940, 1380), const Radius.circular(230)),
        wave,
      );
    case ArenaKind.shooter:
      c.drawRect(r, _p(0xFF03071E));
      for (var i = 0; i < 70; i++) {
        final sp = 1 + i % 3;
        c.drawCircle(Offset((i * 137) % kWorldW, (i * 53 + t * 60 * sp * 3) % kWorldH), sp * 1.6, _p(0xAAFFFFFF));
      }
  }
}

void _mob(Canvas c, ArenaSim s, Mob m, ArcadePalette p, double t) {
  final o = Offset(m.x, m.y);
  final flash = m.flash > 0;
  final big = m.type == kBoss;
  final r = m.r;
  int col;
  switch (s.kind) {
    case ArenaKind.zombie:
      col = switch (m.type) {
        kRunner => 0xFF95D5B2,
        kTank => 0xFF2D6A4F,
        kSpitter => 0xFFB5E48C,
        kBomber => 0xFFF77F00,
        kBoss => 0xFF1B4332,
        _ => 0xFF74C69D,
      };
      // arms reaching forward
      final a = math.atan2(s.py - m.y, s.px - m.x);
      final arm = Paint()
        ..color = Color(col)
        ..strokeWidth = r * 0.35
        ..strokeCap = StrokeCap.round;
      for (final side in const [-0.5, 0.5]) {
        final b = o + Offset(math.cos(a + side), math.sin(a + side)) * r * 0.8;
        c.drawLine(b, b + Offset(math.cos(a), math.sin(a)) * r * 0.9, arm);
      }
      c.drawCircle(o, r, _p(flash ? 0xFFFFFFFF : col));
      c.drawCircle(o + Offset(math.cos(a - 0.4), math.sin(a - 0.4)) * r * 0.5, r * 0.15, _p(0xFFD00000));
      c.drawCircle(o + Offset(math.cos(a + 0.4), math.sin(a + 0.4)) * r * 0.5, r * 0.15, _p(0xFFD00000));
    case ArenaKind.robot:
      col = switch (m.type) {
        kSpitter => 0xFF90E0EF,
        kCharger => 0xFFFF6B6B,
        kTank => 0xFF6C757D,
        kBomber => 0xFFFFD166,
        kBoss => 0xFFE63946,
        _ => 0xFFADB5BD,
      };
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: r * 2, height: r * 2), Radius.circular(r * 0.3)),
        _p(flash ? 0xFFFFFFFF : col),
      );
      c.drawRect(Rect.fromCenter(center: o.translate(0, -r * 0.2), width: r * 1.2, height: r * 0.4), _p(0xFF0D1B2A));
      c.drawCircle(o.translate(math.sin(t * 3 + m.x) * r * 0.35, -r * 0.2), r * 0.15, _p(0xFF00F5D4));
      c.drawLine(
        o.translate(0, -r),
        o.translate(0, -r * 1.5),
        Paint()
          ..color = Color(col)
          ..strokeWidth = 4,
      );
    case ArenaKind.dungeon:
    case ArenaKind.hunter:
    case ArenaKind.island:
      // creatures: slimes, skeletons, beasts, crabs
      col = switch (m.type) {
        kRunner => 0xFFE9C46A,
        kTank => 0xFF6D597A,
        kSpitter => 0xFF8338EC,
        kCharger => 0xFFE76F51,
        kSplitter => 0xFF4CC9F0,
        kMini => 0xFF90E0EF,
        kBoss => s.kind == ArenaKind.hunter ? 0xFF9D0208 : 0xFF3C096C,
        _ => s.kind == ArenaKind.island ? 0xFFE63946 : 0xFF52B788,
      };
      final body = Rect.fromCenter(center: o, width: r * 2.1, height: r * 1.7 + math.sin(t * 10 + m.x) * 3);
      c.drawOval(body, _p(flash ? 0xFFFFFFFF : col));
      if (big) {
        // horns / spikes
        for (final sx in const [-1.0, 1.0]) {
          c.drawPath(
            Path()
              ..moveTo(m.x + sx * r * 0.5, m.y - r * 0.6)
              ..lineTo(m.x + sx * r * 0.9, m.y - r * 1.4)
              ..lineTo(m.x + sx * r * 0.2, m.y - r * 0.8)
              ..close(),
            _p(0xFFF1FAEE),
          );
        }
      }
      if (s.kind == ArenaKind.island) {
        for (final sx in const [-1.0, 1.0]) {
          c.drawCircle(o.translate(sx * r * 1.1, -r * 0.3), r * 0.35, _p(col));
        }
      }
      c.drawCircle(o.translate(-r * 0.35, -r * 0.2), r * 0.18, _p(0xFFFFFFFF));
      c.drawCircle(o.translate(r * 0.35, -r * 0.2), r * 0.18, _p(0xFFFFFFFF));
      c.drawCircle(o.translate(-r * 0.35, -r * 0.2), r * 0.08, _p(0xFF000000));
      c.drawCircle(o.translate(r * 0.35, -r * 0.2), r * 0.08, _p(0xFF000000));
    case ArenaKind.defense:
    case ArenaKind.shooter:
      col = switch (m.type) {
        kRunner => 0xFF4CC9F0,
        kSpitter => 0xFFF72585,
        kTank => 0xFF7209B7,
        kBomber => 0xFFFF9F1C,
        kSplitter => 0xFF06D6A0,
        kBoss => 0xFFD00000,
        _ => 0xFF80FFDB,
      };
      final path = Path()
        ..moveTo(m.x, m.y + r)
        ..lineTo(m.x + r, m.y - r * 0.5)
        ..lineTo(m.x + r * 0.4, m.y - r * 0.2)
        ..lineTo(m.x, m.y - r)
        ..lineTo(m.x - r * 0.4, m.y - r * 0.2)
        ..lineTo(m.x - r, m.y - r * 0.5)
        ..close();
      c.drawPath(path, _p(flash ? 0xFFFFFFFF : col));
      c.drawCircle(o.translate(0, -r * 0.1), r * 0.3, _p(0xCCFFFFFF));
      if (s.kind == ArenaKind.defense) c.drawCircle(o.translate(0, -r * 0.1), r * 0.14, _p(0xFF240046));
  }
  // telegraphs
  if (m.type == kCharger && m.state == 1) {
    c.drawLine(
      o,
      o + Offset(m.ax, m.ay) * 420,
      Paint()
        ..color = const Color(0x88FF0000)
        ..strokeWidth = r * 1.4,
    );
  }
  if (m.type == kBomber && m.state == 1) {
    c.drawCircle(
      o,
      150 * (1 - m.timer / 45),
      Paint()
        ..color = const Color(0x55FF4D00)
        ..style = PaintingStyle.fill,
    );
  }
  if (big && m.state == 2 && m.cd > 20) {
    c.drawLine(
      o,
      o + Offset(m.ax, m.ay) * 600,
      Paint()
        ..color = const Color(0x66FF0000)
        ..strokeWidth = r * 1.6,
    );
  }
  if (!big && m.hp < m.maxHp) _bar(c, o.translate(0, -r - 16), r * 1.6, m.hp / m.maxHp, 0xFFFF4D6D);
}

void _player(Canvas c, ArenaSim s, ArcadePalette p, double t) {
  final o = Offset(s.px, s.py);
  final blink = s.shield > 0 && (s.ticks ~/ 5).isOdd;
  final hurt = s.hurt > 0;
  final col = hurt ? const Color(0xFFFF4D6D) : (blink ? Colors.white38 : p.piece(0));
  final aim = math.atan2(s.aimY, s.aimX);
  switch (s.kind) {
    case ArenaKind.shooter:
      final ship = Path()
        ..moveTo(s.px, s.py - 52)
        ..lineTo(s.px + 44, s.py + 34)
        ..lineTo(s.px + 14, s.py + 22)
        ..lineTo(s.px, s.py + 40)
        ..lineTo(s.px - 14, s.py + 22)
        ..lineTo(s.px - 44, s.py + 34)
        ..close();
      c.drawOval(
        Rect.fromCenter(center: o.translate(0, 52), width: 22, height: 36 + math.sin(t * 40) * 8),
        _p(0xFFFFB703),
      );
      c.drawPath(ship, Paint()..color = col);
      c.drawCircle(o.translate(0, -8), 10, _p(0xFF90E0EF));
    case ArenaKind.defense:
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: o.translate(0, 20), width: 110, height: 50),
          const Radius.circular(14),
        ),
        Paint()..color = col,
      );
      final t0 = s.nearest(1600);
      final a = t0 == null ? -math.pi / 2 : math.atan2(t0.y - s.py, t0.x - s.px);
      c.drawLine(
        o,
        o + Offset(math.cos(a), math.sin(a)) * 70,
        Paint()
          ..color = const Color(0xFFE0E1DD)
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
      c.drawCircle(o, 28, _p(0xFF415A77));
    default:
      // body + direction
      c.drawCircle(o, 34, Paint()..color = col);
      c.drawCircle(o + Offset(math.cos(aim), math.sin(aim)) * 14, 12, _p(0xFFFFE8D6));
      if (usesMelee(s.kind)) {
        if (s.swing > 0) {
          final f = 1 - s.swing / 12;
          c.drawArc(
            Rect.fromCircle(center: o, radius: s.range + 20),
            s.swingAng - 1.1 + f * 0.6,
            2.2 - f * 0.6,
            false,
            Paint()
              ..color = const Color(0xAAFFFFFF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 16,
          );
        }
        final sa = s.swing > 0 ? s.swingAng : aim;
        c.drawLine(
          o + Offset(math.cos(sa), math.sin(sa)) * 30,
          o + Offset(math.cos(sa), math.sin(sa)) * (s.kind == ArenaKind.island ? 75 : 95),
          Paint()
            ..color = Color(s.kind == ArenaKind.island ? 0xFF8D5524 : 0xFFE0E1DD)
            ..strokeWidth = s.kind == ArenaKind.hunter ? 16 : 10
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final t0 = s.nearest(s.range);
        final a = t0 == null ? aim : math.atan2(t0.y - s.py, t0.x - s.px);
        c.drawLine(
          o,
          o + Offset(math.cos(a), math.sin(a)) * 58,
          Paint()
            ..color = const Color(0xFF343A40)
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round,
        );
      }
  }
  if (s.kind != ArenaKind.defense) _bar(c, o.translate(0, 60), 90, s.php / s.pmax, 0xFF52B788);
}

void paintArena(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as ArenaSim;
  _ground(c, s, t);
  for (final w in s.level.walls) {
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(w.x, w.y, w.w, w.h), const Radius.circular(12));
    c.drawRRect(rr.shift(const Offset(6, 8)), _p(0x55000000));
    c.drawRRect(rr, _p(s.kind == ArenaKind.robot ? 0xFF415A77 : 0xFF6C584C));
    c.drawRRect(rr.deflate(10), _p(s.kind == ArenaKind.robot ? 0xFF778DA9 : 0xFFA98467));
  }
  for (final n in s.nodes) {
    final o = Offset(n.x, n.y);
    switch (n.kind) {
      case 0:
        c.drawRect(Rect.fromCenter(center: o.translate(0, 30), width: 24, height: 60), _p(0xFF7F5539));
        if (n.amount > 0) {
          for (var i = 0; i < 5; i++) {
            final a = i * 2 * math.pi / 5 + math.sin(t + n.x) * 0.05;
            c.drawLine(
              o,
              o + Offset(math.cos(a), math.sin(a)) * 70,
              Paint()
                ..color = const Color(0xFF2D6A4F)
                ..strokeWidth = 18
                ..strokeCap = StrokeCap.round,
            );
          }
        }
      case 1:
        if (n.amount > 0) {
          c.drawPath(
            Path()
              ..moveTo(n.x - 45, n.y + 25)
              ..lineTo(n.x - 30, n.y - 25)
              ..lineTo(n.x + 15, n.y - 35)
              ..lineTo(n.x + 45, n.y + 25)
              ..close(),
            _p(0xFF8D99AE),
          );
        } else {
          c.drawOval(Rect.fromCenter(center: o.translate(0, 20), width: 60, height: 16), _p(0x55000000));
        }
      default:
        c.drawCircle(o, 34, _p(0xFF40916C));
        for (var i = 0; i < n.amount; i++) {
          c.drawCircle(o + Offset(math.cos(i * 1.7), math.sin(i * 1.7)) * 18, 7, _p(0xFFD62828));
        }
    }
  }
  for (final pk in s.pickups) {
    final o = Offset(pk.x, pk.y + math.sin(t * 6 + pk.x) * 4);
    switch (pk.kind) {
      case 0:
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy - 14)
            ..lineTo(o.dx + 10, o.dy)
            ..lineTo(o.dx, o.dy + 14)
            ..lineTo(o.dx - 10, o.dy)
            ..close(),
          _p(pk.value > 1 ? 0xFFB5179E : 0xFF4CC9F0),
        );
      case 1:
        c.drawCircle(o, 18, _p(0xFFFFFFFF));
        paintText(c, '+', o, 30, const Color(0xFFE63946));
      case 2:
        c.drawCircle(o, 14, _p(0xFFFFD60A));
      case 3:
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 46, height: 18), const Radius.circular(8)),
          _p(0xFF9C6644),
        );
      case 4:
        c.drawCircle(o, 14, _p(0xFF8D99AE));
      default:
        c.drawCircle(o, 12, _p(0xFFD62828));
    }
  }
  for (final m in s.mobs) {
    _mob(c, s, m, p, t);
  }
  for (final b in s.bullets) {
    if (b.enemy) {
      c.drawCircle(Offset(b.x, b.y), b.r + 2, _p(0xFFFF4D6D));
      c.drawCircle(Offset(b.x, b.y), b.r * 0.5, _p(0xFFFFFFFF));
    } else {
      c.drawLine(
        Offset(b.x, b.y),
        Offset(b.x - b.vx * 0.8, b.y - b.vy * 0.8),
        Paint()
          ..color = Color(s.kind == ArenaKind.robot ? 0xFF00F5D4 : 0xFFFFE066)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }
  }
  for (final (x, y, life) in s.booms) {
    c.drawCircle(Offset(x, y), (30 - life) * 7.0 + 40, _p((((life * 8).clamp(0, 200)).toInt() << 24) | 0xFFB703));
  }
  _player(c, s, p, t);
  if (s.kind == ArenaKind.island) {
    final dusk = s.dayTick / ArenaSim.dayLen;
    if (s.night) {
      c.drawRect(const Rect.fromLTWH(0, 0, kWorldW, kWorldH), _p(0x77000822));
      c.drawCircle(Offset(s.px, s.py), 160, _p(0x22FFD166));
    } else if (dusk > 0.45) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, kWorldW, kWorldH),
        Paint()..color = Color.fromARGB(((dusk - 0.45) * 400).round().clamp(0, 90), 120, 40, 20),
      );
    }
    _bar(c, const Offset(500, 60), 400, s.hunger / 100, 0xFFF4A261);
    paintText(c, '🍖', const Offset(270, 60), 34, Colors.white);
    paintText(c, '🪵 ${s.wood}/${s.woodGoal}   🪨 ${s.stone}/${s.stoneGoal}', const Offset(500, 110), 36, Colors.white);
  }
  final b = s.boss;
  if (b != null && s.mobs.contains(b)) {
    _bar(c, const Offset(500, 170), 700, b.hp / b.maxHp, 0xFFD00000);
    paintText(c, '☠', const Offset(120, 170), 40, Colors.white);
  }
  // XP bar + level
  _bar(c, const Offset(500, 1590), 960, s.xp / s.xpNeed, 0xFF4CC9F0);
  paintText(c, 'Lv ${s.plevel}', const Offset(60, 1560), 30, Colors.white);
  if (s.upgradeShow > 0) {
    paintText(
      c,
      '★ ${_upgradeIcon[s.lastUpgrade] ?? ''}',
      Offset(s.px, s.py - 110 - (120 - s.upgradeShow) * 0.4),
      40,
      const Color(0xFFFFD166),
    );
  }
  if (s.waveGap > 0) paintText(c, '⚑ ${s.wave + 1}', const Offset(500, 760), 90, Colors.white70);
}

Sfx? arenaSound(ArcadeSim sim) => switch ((sim as ArenaSim).lastEvent) {
  1 => Sfx.tap,
  2 => Sfx.error,
  3 => Sfx.unlock,
  4 => Sfx.win,
  5 => Sfx.coin,
  _ => null,
};
