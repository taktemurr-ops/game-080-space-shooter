import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/game_api.dart';
import '../core/game_rules.dart';
import 'arena_engine.dart';
import 'arena_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-080-space-shooter',
  title: const ['Uzay Nişancısı', 'Space Shooter', 'Weltraum-Shooter', 'Tirador Espacial', 'Tireur Spatial'],
  tagline: const ['Mermi yağmurundan sıyrıl, filoyu yok et!', 'Dodge the bullet storm, destroy the fleet!', 'Weiche aus, zerstöre die Flotte!', '¡Esquiva y destruye la flota!', 'Esquivez et détruisez la flotte !'],
  seedColor: const Color(0xFFFFB703),
  icon: Icons.rocket,
  rules: ShooterRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => ArenaSim((ctx.generated as GeneratedLevel<ArenaLevel>).puzzle),
    paint: paintArena,
    sound: arenaSound,
    boosterIcon: Icons.flash_on,
    boosterLabel: (l) => l == 'tr' ? 'Nova bombası' : 'Nova bomb',
    howTo: const ['Basılı tutup kaydır: gemi parmağının yönünde hareket eder. Ateş otomatik.', 'Hold and slide to steer the ship. It fires automatically.', 'Halten und ziehen zum Steuern.', 'Mantén y desliza para pilotar.', 'Maintenez et glissez pour piloter.'],
  ),
  tutorial: const [
    TutorialStep(Icons.open_with, ['Basılı tutup kaydırarak gemiyi yönlendir.', 'Hold and slide to steer.', 'Halten und ziehen.', 'Mantén y desliza.', 'Maintenez et glissez.']),
    TutorialStep(Icons.scatter_plot, ['Kırmızı mermilerden kaç; boss desen atar.', 'Dodge red bullets; bosses fire patterns.', 'Roten Kugeln ausweichen.', 'Esquiva las balas rojas.', 'Esquivez les balles rouges.']),
    TutorialStep(Icons.flash_on, ['Nova bombası ekrandaki mermileri siler.', 'The nova bomb clears bullets.', 'Nova-Bombe löscht Kugeln.', 'La bomba nova limpia balas.', 'La bombe nova efface les balles.']),
  ],
);
