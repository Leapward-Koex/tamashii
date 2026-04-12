import 'dart:async';

import 'package:flutter/material.dart';

Future<T> runWithDownloadPreparationDialog<T>({
  required BuildContext context,
  required Future<T> Function() action,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const AlertDialog(
            title: Text('Preparing download'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Flexible(child: Text('Working out download folder...')),
              ],
            ),
          ),
    ),
  );

  await Future<void>.delayed(Duration.zero);

  try {
    return await action();
  } finally {
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }
}
