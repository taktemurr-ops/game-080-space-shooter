import 'dart:async';
import 'package:flutter/material.dart';
import 'game/space_engine.dart';

void main() => runApp(const SpaceShooterApp());

class SpaceShooterApp extends StatelessWidget {
  const SpaceShooterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Space Shooter',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigoAccent, brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const SpaceShooterScreen(),
  );
}

class SpaceShooterScreen extends StatefulWidget {
  const SpaceShooterScreen({super.key});

  @override
  State<SpaceShooterScreen> createState() => _SpaceShooterScreenState();
}

class _SpaceShooterScreenState extends State<SpaceShooterScreen> {
  final SpaceEngine game = SpaceEngine();
  Timer? loop;
  bool firing = false;

  @override
  void initState() {
    super.initState();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || game.status != SpaceStatus.playing) return;
      setState(() {
        if (firing) game.shoot();
        game.tick(0.016);
      });
    });
  }

  @override
  void dispose() {
    loop?.cancel();
    super.dispose();
  }

  void begin() => setState(() {
    if (game.status == SpaceStatus.won ||
        game.status == SpaceStatus.lost) game.reset();
    game.start();
  });

  Widget controlButton(String name, VoidCallback action,
      {bool enabled = true}) => FilledButton.tonal(
        onPressed: enabled ? action : null, child: Text(name));

  @override
  Widget build(BuildContext context) {
    final playing = game.status == SpaceStatus.playing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPACE SHOOTER'),
        actions: [
          IconButton(
            tooltip: playing ? 'Pause' : 'Resume',
            onPressed: playing || game.status == SpaceStatus.paused
                ? () => setState(game.togglePause) : null,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Restart',
            onPressed: () => setState(() { firing = false; game.reset(); }),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: Text('WAVE ${game.wave}/5   SCORE ${game.score}   '
              'LIVES ${game.lives}   ARMOR ${game.ship.hp}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center)),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: playing
                  ? (details) => setState(() {
                      game.moveTo(details.localPosition.dx /
                        constraints.maxWidth);
                    }) : null,
              onTapDown: playing
                  ? (details) => setState(() {
                      game.moveTo(details.localPosition.dx /
                        constraints.maxWidth);
                    }) : null,
              child: CustomPaint(
                key: const ValueKey('space-arena'),
                painter: SpacePainter(game),
                child: const SizedBox.expand(),
              ),
            );
          })),
          if (!playing) Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Text(switch (game.status) {
                SpaceStatus.ready => 'Defend the galaxy! Move and fire.',
                SpaceStatus.paused => 'Paused',
                SpaceStatus.won => 'Victory! Five waves cleared.',
                SpaceStatus.lost => 'Game over. Try again!',
                SpaceStatus.playing => '',
              }, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              controlButton(
                game.status == SpaceStatus.paused ? 'Resume' :
                game.status == SpaceStatus.ready ? 'Start game' : 'Play again',
                game.status == SpaceStatus.paused
                    ? () => setState(game.togglePause) : begin),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Move left',
                  onPressed: playing
                    ? () => setState(() => game.moveTo(game.ship.x - 0.09))
                    : null,
                  icon: const Icon(Icons.arrow_back)),
                Listener(
                  onPointerDown: playing
                    ? (_) => setState(() { firing = true; game.shoot(); })
                    : null,
                  onPointerUp: (_) => setState(() => firing = false),
                  onPointerCancel: (_) => setState(() => firing = false),
                  child: FilledButton.icon(
                    onPressed: playing
                        ? () => setState(game.shoot) : null,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('FIRE'),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Move right',
                  onPressed: playing
                    ? () => setState(() => game.moveTo(game.ship.x + 0.09))
                    : null,
                  icon: const Icon(Icons.arrow_forward)),
              ]),
          ),
          const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Text('Drag across the arena to steer. Hold FIRE to shoot.',
              textAlign: TextAlign.center)),
        ]),
      ))),
    );
  }
}

class SpacePainter extends CustomPainter {
  final SpaceEngine game;
  SpacePainter(this.game);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
      Paint()..color = const Color(0xFF080E22));
    for (var i = 0; i < 75; i++) {
      final x = ((i * 73) % 101) / 101 * size.width;
      final y = ((i * 43) % 97) / 97 * size.height;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.8 : 0.9,
        Paint()..color = Colors.white.withValues(alpha: 0.4));
    }
    Offset point(double x, double y) =>
        Offset(x * size.width, y * size.height);
    final ship = point(game.ship.x, game.ship.y);
    final shipPath = Path()
      ..moveTo(ship.dx, ship.dy - 19)
      ..lineTo(ship.dx - 16, ship.dy + 14)
      ..lineTo(ship.dx + 16, ship.dy + 14)
      ..close();
    canvas.drawPath(shipPath, Paint()..color = Colors.cyanAccent);
    for (final enemy in game.invaders) {
      canvas.drawCircle(point(enemy.x, enemy.y), 13,
        Paint()..color = enemy.hp > 1 ? Colors.deepOrange : Colors.redAccent);
      canvas.drawCircle(point(enemy.x, enemy.y), 5,
        Paint()..color = Colors.white70);
    }
    for (final shot in game.shots) {
      final p = point(shot.x, shot.y);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 5, height: 17),
          const Radius.circular(2)),
        Paint()..color = shot.hostile ? Colors.orangeAccent : Colors.lightGreenAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpacePainter oldDelegate) => true;
}
