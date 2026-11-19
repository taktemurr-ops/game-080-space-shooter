import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_080_space_shooter/game/space_engine.dart';

void main() {
  group('SpaceEngine', () {
    test('reset and start move through correct states', () {
      final g = SpaceEngine(random: Random(1));
      expect(g.status, SpaceStatus.ready);
      expect(g.ship.hp, 3);
      g.start();
      expect(g.status, SpaceStatus.playing);
      g.reset();
      expect(g.status, SpaceStatus.ready);
      expect(g.score, 0);
    });
    test('ship cannot move off screen', () {
      final g = SpaceEngine()..start();
      g.moveTo(-100);
      expect(g.ship.x, closeTo(0.07, 0.001));
      g.moveTo(100);
      expect(g.ship.x, closeTo(0.93, 0.001));
    });
    test('weapon cooldown prevents duplicate firing', () {
      final g = SpaceEngine()..start();
      expect(g.shoot(), true);
      expect(g.shoot(), false);
      expect(g.shots.length, 1);
      for (var i = 0; i < 20; i++) { g.tick(0.02); }
      expect(g.shoot(), true);
    });
    test('time step adds enemies', () {
      final g = SpaceEngine(random: Random(3))..start();
      for (var i = 0; i < 55; i++) { g.tick(0.02); }
      expect(g.invaders, isNotEmpty);
    });
    test('friendly shots destroy enemies and award score', () {
      final g = SpaceEngine(random: Random(4))..start();
      g.invaders.add(Invader(0.5, 0.5, 1));
      g.shots.add(Projectile(0.5, 0.5));
      g.tick(0.01);
      expect(g.invaders, isEmpty);
      expect(g.score, 10);
    });
    test('enemy shots reduce armor and lives', () {
      final g = SpaceEngine(random: Random(5))..start();
      for (var i = 0; i < 3; i++) {
        g.shots.add(Projectile(g.ship.x, g.ship.y, hostile: true));
        g.tick(0.01);
      }
      expect(g.ship.hp, 3);
      expect(g.lives, 2);
    });
    test('third life loss ends game', () {
      final g = SpaceEngine(random: Random(6))..start();
      for (var i = 0; i < 9; i++) {
        g.shots.add(Projectile(g.ship.x, g.ship.y, hostile: true));
        g.tick(0.01);
      }
      expect(g.status, SpaceStatus.lost);
      expect(g.lives, 0);
      expect(g.shoot(), false);
    });
    test('five waves complete in victory and lock simulation', () {
      final g = SpaceEngine(random: Random(7))..start();
      g.wave = 5;
      g.score = 490;
      g.invaders.add(Invader(0.5, 0.5, 1));
      g.shots.add(Projectile(0.5, 0.5));
      g.tick(0.01);
      expect(g.status, SpaceStatus.won);
      expect(g.score, 500);
      expect(g.shoot(), false);
    });
    test('pause prevents time progression and firing', () {
      final g = SpaceEngine()..start();
      g.togglePause();
      final before = g.ticks;
      g.tick(0.04);
      expect(g.ticks, before);
      expect(g.shoot(), false);
      g.togglePause();
      expect(g.status, SpaceStatus.playing);
    });
  });
}
