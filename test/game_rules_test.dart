import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:game_080_space_shooter/game/arena_engine.dart';
import 'package:game_080_space_shooter/game/rules.dart';

void main() {
  final rules = ShooterRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('the player weapon defeats an enemy in reach', () {
    final s = ArenaSim(rules.build(planner.spec(3)).puzzle);
    final m = s.makeMob(kWalker, s.px, s.py - (usesMelee(s.kind) ? 90 : 300));
    s.mobs.add(m);
    for (var i = 0; i < 400 && s.mobs.contains(m); i++) {
      s.tick(ArcadeInput.idle);
    }
    expect(s.mobs.contains(m), isFalse);
    expect(s.kills, greaterThanOrEqualTo(1));
    expect(s.pickups.isNotEmpty || s.xp > 0 || s.plevel > 1, isTrue);
  });

  test('damage drains health, then a life; the booster clears nearby enemies', () {
    final s = ArenaSim(rules.build(planner.spec(4)).puzzle);
    final hp = s.php;
    s.hurtPlayer(10);
    expect(s.php, hp - 10);
    s.hurtPlayer(10000);
    expect(s.lives, 2);
    s.shield = 0;
    for (var i = 0; i < 5; i++) {
      s.mobs.add(s.makeMob(kWalker, s.px + 100 + i * 20, s.py));
    }
    final before = s.mobs.length;
    expect(s.useBooster(), isTrue);
    expect(s.mobs.length, lessThan(before));
  });

  test('levelling up applies an upgrade', () {
    final s = ArenaSim(rules.build(planner.spec(2)).puzzle);
    final need = s.xpNeed;
    for (var i = 0; i < need; i++) {
      s.pickups.add(Pickup(s.px, s.py, 0, 1));
    }
    s.tick(ArcadeInput.idle);
    expect(s.plevel, 2);
    expect(kUpgrades.contains(s.lastUpgrade), isTrue);
  });

  test('virtual joystick moves the player', () {
    final s = ArenaSim(rules.build(planner.spec(1)).puzzle);
    final x = s.px;
    s.tick(const ArcadeInput(down: true, x: 500, y: 800, tap: true));
    for (var i = 0; i < 10; i++) {
      s.tick(const ArcadeInput(down: true, x: 400, y: 800));
    }
    expect(s.px, lessThan(x));
  });
}
