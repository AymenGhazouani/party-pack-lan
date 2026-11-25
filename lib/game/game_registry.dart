enum GameMode { ffa, teams, coop }

enum JoystickAxis { both, x, none }

class GameControls {
  const GameControls({
    this.axis = JoystickAxis.both,
    this.actionLabel,
    this.dash = false,
    this.mash = false,
  });

  final JoystickAxis axis;

  /// If non-null, show a hold-to-act button (spray) with this label.
  final String? actionLabel;

  /// Show a dash button (edge-triggered with cooldown).
  final bool dash;

  /// Show/replace action area with a big MASH button.
  final bool mash;

  bool get needsJoystick => axis != JoystickAxis.none;
}

class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.goal,
    required this.controls,
  });

  final String id;
  final String title;
  final String subtitle;
  final GameMode mode;

  /// One-line goal shown during the countdown.
  final String goal;
  final GameControls controls;
}

const GameInfo sumoPush = GameInfo(
  id: 'sumo_push',
  title: 'SUMO PUSH',
  subtitle: 'Shove rivals off the ring',
  mode: GameMode.ffa,
  goal: 'LAST ONE STANDING!',
  controls: GameControls(dash: true),
);

const GameInfo tugOfWar = GameInfo(
  id: 'tug_of_war',
  title: 'TUG OF WAR',
  subtitle: 'Teams mash to pull the rope',
  mode: GameMode.teams,
  goal: 'PULL THE ROPE TO YOUR SIDE!',
  controls: GameControls(axis: JoystickAxis.none, mash: true),
);

const GameInfo gemCatch = GameInfo(
  id: 'gem_catch',
  title: 'GEM CATCH',
  subtitle: 'Catch gems, dodge bombs',
  mode: GameMode.ffa,
  goal: 'MOST GEMS IN 45s WINS!',
  controls: GameControls(axis: JoystickAxis.x),
);

const GameInfo fireBrigade = GameInfo(
  id: 'fire_brigade',
  title: 'FIRE BRIGADE',
  subtitle: 'Team up to drown the blaze',
  mode: GameMode.coop,
  goal: 'PUT THE FIRE OUT TOGETHER!',
  controls: GameControls(actionLabel: 'SPRAY'),
);

const List<GameInfo> kGames = [sumoPush, tugOfWar, gemCatch, fireBrigade];

GameInfo? gameById(String id) {
  for (final g in kGames) {
    if (g.id == id) return g;
  }
  return null;
}

String modeTag(GameMode mode) => switch (mode) {
      GameMode.ffa => 'FFA',
      GameMode.teams => 'TEAMS',
      GameMode.coop => 'CO-OP',
    };
