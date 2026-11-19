import 'dart:math';

enum SpaceStatus { ready, playing, won, lost, paused }

class Ship {
  double x;
  double y;
  int hp;
  Ship(this.x, this.y, this.hp);
}

class Projectile {
  double x;
  double y;
  final bool hostile;
  Projectile(this.x, this.y, {this.hostile = false});
}

class Invader {
  double x;
  double y;
  int hp;
  Invader(this.x, this.y, this.hp);
}

/// Fixed-step deterministic simulation. Coordinates are normalized to [0, 1].
class SpaceEngine {
  final Random random;
  late Ship ship;
  final List<Invader> invaders = [];
  final List<Projectile> shots = [];
  int wave = 1;
  int score = 0;
  int lives = 3;
  int ticks = 0;
  double cooldown = 0;
  double spawnTimer = 0;
  double enemyShotTimer = 0;
  SpaceStatus status = SpaceStatus.ready;

  SpaceEngine({Random? random}) : random = random ?? Random() {
    reset();
  }

  void reset() {
    ship = Ship(0.5, 0.88, 3);
    invaders.clear();
    shots.clear();
    wave = 1;
    score = 0;
    lives = 3;
    ticks = 0;
    cooldown = 0;
    spawnTimer = 0;
    enemyShotTimer = 0;
    status = SpaceStatus.ready;
  }

  void start() {
    if (status == SpaceStatus.ready) status = SpaceStatus.playing;
  }

  void togglePause() {
    if (status == SpaceStatus.playing) {
      status = SpaceStatus.paused;
    } else if (status == SpaceStatus.paused) {
      status = SpaceStatus.playing;
    }
  }

  void moveTo(double x) {
    if (status != SpaceStatus.playing) return;
    ship.x = x.clamp(0.07, 0.93).toDouble();
  }

  bool shoot() {
    if (status != SpaceStatus.playing || cooldown > 0) return false;
    shots.add(Projectile(ship.x, ship.y - 0.05));
    cooldown = 0.28;
    return true;
  }

  void tick(double delta) {
    if (status != SpaceStatus.playing || delta <= 0) return;
    // Cap large background frame jumps to avoid tunnelling.
    final dt = delta.clamp(0.0, 0.05).toDouble();
    ticks++;
    cooldown = max(0.0, cooldown - dt);
    spawnTimer += dt;
    enemyShotTimer += dt;

    if (spawnTimer >= max(0.24, 0.85 - wave * 0.09)) {
      spawnTimer = 0;
      invaders.add(Invader(0.1 + random.nextDouble() * 0.8, -0.05,
        wave >= 3 ? 2 : 1));
    }

    for (final enemy in invaders) {
      enemy.y += dt * (0.16 + wave * 0.045);
    }
    for (final shot in shots) {
      shot.y += dt * (shot.hostile ? 0.55 : -0.85);
    }

    if (enemyShotTimer >= 1.15 && invaders.isNotEmpty) {
      enemyShotTimer = 0;
      final enemy = invaders[random.nextInt(invaders.length)];
      shots.add(Projectile(enemy.x, enemy.y + 0.04, hostile: true));
    }

    for (final shot in shots.where((s) => !s.hostile).toList()) {
      for (final enemy in invaders.toList()) {
        if ((shot.x - enemy.x).abs() < 0.064 &&
            (shot.y - enemy.y).abs() < 0.055) {
          enemy.hp--;
          shots.remove(shot);
          if (enemy.hp <= 0) {
            invaders.remove(enemy);
            score += 10;
            if (score >= wave * 100) {
              if (wave == 5) {
                status = SpaceStatus.won;
              } else {
                wave++;
              }
            }
          }
          break;
        }
      }
    }

    for (final shot in shots.where((s) => s.hostile).toList()) {
      if ((shot.x - ship.x).abs() < 0.065 &&
          (shot.y - ship.y).abs() < 0.057) {
        shots.remove(shot);
        _damage();
      }
    }
    for (final enemy in invaders.toList()) {
      if (enemy.y >= 0.98 ||
          ((enemy.x - ship.x).abs() < 0.09 &&
           (enemy.y - ship.y).abs() < 0.07)) {
        invaders.remove(enemy);
        _damage();
      }
    }
    shots.removeWhere((s) => s.y < -0.1 || s.y > 1.1);
  }

  void _damage() {
    if (status != SpaceStatus.playing) return;
    ship.hp--;
    if (ship.hp <= 0) {
      lives--;
      if (lives <= 0) {
        ship.hp = 0;
        status = SpaceStatus.lost;
      } else {
        ship.hp = 3;
        invaders.clear();
        shots.clear();
      }
    }
  }
}
