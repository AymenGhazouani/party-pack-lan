import 'package:flutter/material.dart';

import '../model/models.dart';
import '../state/app_controller.dart';
import '../ui/avatar_view.dart';
import '../ui/pixel_widgets.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final result = app.lastResult;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final sorted = [...?result?.results]
          ..sort((a, b) => a.placement.compareTo(b.placement));
        PlayerInfo? playerById(int id) {
          for (final p in app.players) {
            if (p.id == id) return p;
          }
          return null;
        }

        return Scaffold(
          backgroundColor: const Color(0xff16161e),
          body: Stack(
            children: [
              const Positioned.fill(child: _ResultsBackdrop()),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PixelLabel(
                      'ROUND ${app.round} RESULTS',
                      size: 14,
                      color: const Color(0xff4cc9f0),
                    ),
                    const SizedBox(height: 14),
                    if (result != null && result.coOp)
                      PixelLabel(
                        result.coOpSuccess
                            ? 'TEAM VICTORY!'
                            : 'THE FIRE WINS…',
                        size: 20,
                        color: result.coOpSuccess
                            ? const Color(0xff06d6a0)
                            : const Color(0xffef476f),
                      ),
                    const SizedBox(height: 12),
                    PixelPanel(
                      color: const Color(0xff232338),
                      child: SizedBox(
                        width: 480,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final r in sorted)
                              _ResultRow(
                                placement: r.placement,
                                name: playerById(r.playerId)?.name ?? 'P',
                                avatarId: playerById(r.playerId)?.avatarId ?? 0,
                                points: r.points,
                                total: result?.totals[r.playerId] ?? 0,
                                coOp: result?.coOp ?? false,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (app.amHost)
                      PixelButton(
                        label: app.lastRoundIsFinal
                            ? 'FINAL RESULTS'
                            : 'NEXT ROUND',
                        face: const Color(0xffffd166),
                        fontSize: 14,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 44, vertical: 16),
                        onTap: app.resultsNext,
                      )
                    else
                      const PixelLabel('WAITING FOR HOST…',
                          size: 11, color: Color(0xff777788)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.placement,
    required this.name,
    required this.avatarId,
    required this.points,
    required this.total,
    required this.coOp,
  });

  final int placement;
  final String name;
  final int avatarId;
  final int points;
  final int total;
  final bool coOp;

  @override
  Widget build(BuildContext context) {
    final medal = switch (placement) {
      1 => const Color(0xffffd166),
      2 => const Color(0xffc9c9d6),
      3 => const Color(0xffd78c2b),
      _ => const Color(0xff555566),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (!coOp)
            Container(
              width: 34,
              alignment: Alignment.center,
              child: PixelLabel('#$placement',
                  size: 11, color: medal),
            ),
          AvatarView(avatarId: avatarId, scale: 3),
          const SizedBox(width: 12),
          Expanded(
            child: PixelLabel(name.toUpperCase(),
                size: 10, color: Colors.white),
          ),
          PixelLabel('+$points',
              size: 12, color: const Color(0xff06d6a0)),
          const SizedBox(width: 12),
          PixelLabel('$total TOTAL',
              size: 8, color: const Color(0xff9a9aa8)),
        ],
      ),
    );
  }
}

class _ResultsBackdrop extends StatelessWidget {
  const _ResultsBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [Color(0xff232338), Color(0xff16161e)],
        ),
      ),
    );
  }
}
