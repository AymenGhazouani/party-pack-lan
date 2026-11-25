import 'package:flutter/material.dart';

import 'pixel_widgets.dart';

/// Pixel-styled confirm dialog. Returns true if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'YES',
  String cancelLabel = 'NO',
  bool danger = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'confirm',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, _, _) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, _) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return Transform.scale(
        scale: 0.8 + 0.2 * curved.value,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: PixelPanel(
              color: const Color(0xff2e2e44),
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PixelLabel(
                      title,
                      size: 13,
                      color: danger ? const Color(0xffef476f) : const Color(0xffffd166),
                    ),
                    const SizedBox(height: 12),
                    PixelLabel(message, size: 9, color: const Color(0xffe3e3f1)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: PixelButton(
                            label: cancelLabel,
                            face: const Color(0xff3f3f58),
                            textColor: Colors.white,
                            fontSize: 11,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PixelButton(
                            label: confirmLabel,
                            face: danger ? const Color(0xffef476f) : const Color(0xffffd166),
                            textColor: Colors.white,
                            fontSize: 11,
                            onTap: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
