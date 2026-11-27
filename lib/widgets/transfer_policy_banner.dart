import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii/theme/paper_lantern.dart';

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
        color: PaperLantern.wash,
        shape: const Border(
          left: BorderSide(width: 3, color: PaperLantern.red),
          bottom: BorderSide(color: PaperLantern.rule),
        ),
        child: ListTile(
          dense: true,
          leading: const Icon(
            Icons.pause_circle_outline,
            color: PaperLantern.red,
          ),
          title: Text(
            statusText,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: const Text(
            'Existing per-download pause choices are unchanged.',
          ),
        ),
      ),
    );
  }
}
