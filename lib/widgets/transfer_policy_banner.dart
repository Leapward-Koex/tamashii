import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tamashii/services/transfer_policy.dart';

/// Displays session-wide suspension separately from per-download pause state.
class TransferPolicyBanner extends StatelessWidget {
  const TransferPolicyBanner({
    required this.snapshot,
    this.platform,
    super.key,
  });

  static const Key bannerKey = ValueKey<String>('transferPolicyBanner');

  final TransferPolicySnapshot? snapshot;
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    final policy = snapshot;
    final effectivePlatform = platform ?? defaultTargetPlatform;
    if (effectivePlatform != TargetPlatform.android ||
        policy == null ||
        !policy.suspended) {
      return const SizedBox.shrink();
    }

    final statusText = transferPolicyStatusText(policy);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Downloads suspended: $statusText',
      child: Material(
        key: bannerKey,
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.pause_circle_outline),
          title: Text(statusText),
          subtitle: const Text(
            'Existing per-download pause choices are unchanged.',
          ),
        ),
      ),
    );
  }
}
