import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamashii/services/transfer_policy.dart';
import 'package:tamashii/widgets/transfer_policy_banner.dart';
import 'package:tamashii_network_cost/tamashii_network_cost.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required TransferPolicySnapshot snapshot,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransferPolicyBanner(snapshot: snapshot, platform: platform),
        ),
      ),
    );
  }

  testWidgets('shows the Android offline suspension status', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBanner(
      tester,
      snapshot: evaluateTransferPolicy(
        networkStatus: const NetworkStatus(
          cost: NetworkCost.offline,
          transport: NetworkTransport.offline,
          isVpn: false,
        ),
        allowMeteredDownloads: true,
        allowMobileData: true,
      ),
    );

    expect(find.byKey(TransferPolicyBanner.bannerKey), findsOneWidget);
    expect(find.text('Waiting for network'), findsOneWidget);
    expect(
      find.text('Existing per-download pause choices are unchanged.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Downloads suspended: Waiting for network')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows the Android metered suspension status', (tester) async {
    await pumpBanner(
      tester,
      snapshot: evaluateTransferPolicy(
        networkStatus: const NetworkStatus(
          cost: NetworkCost.metered,
          transport: NetworkTransport.wifi,
          isVpn: false,
        ),
        allowMeteredDownloads: false,
        allowMobileData: false,
      ),
    );

    expect(find.byKey(TransferPolicyBanner.bannerKey), findsOneWidget);
    expect(find.text('Waiting for an unmetered connection'), findsOneWidget);
  });

  testWidgets('shows the Android mobile-data suspension status', (
    tester,
  ) async {
    await pumpBanner(
      tester,
      snapshot: evaluateTransferPolicy(
        networkStatus: const NetworkStatus(
          cost: NetworkCost.unmetered,
          transport: NetworkTransport.cellular,
          isVpn: true,
        ),
        allowMeteredDownloads: true,
        allowMobileData: false,
      ),
    );

    expect(find.byKey(TransferPolicyBanner.bannerKey), findsOneWidget);
    expect(find.text('Waiting for Wi-Fi'), findsOneWidget);
  });

  testWidgets('hides the Android banner while transfers are allowed', (
    tester,
  ) async {
    await pumpBanner(
      tester,
      snapshot: evaluateTransferPolicy(
        networkStatus: const NetworkStatus(
          cost: NetworkCost.metered,
          transport: NetworkTransport.wifi,
          isVpn: false,
        ),
        allowMeteredDownloads: true,
        allowMobileData: false,
      ),
    );

    expect(find.byKey(TransferPolicyBanner.bannerKey), findsNothing);
    expect(find.text('Downloading over a metered connection'), findsNothing);
  });

  testWidgets('hides a suspended policy on Windows', (tester) async {
    await pumpBanner(
      tester,
      platform: TargetPlatform.windows,
      snapshot: evaluateTransferPolicy(
        networkStatus: const NetworkStatus(
          cost: NetworkCost.offline,
          transport: NetworkTransport.offline,
          isVpn: false,
        ),
        allowMeteredDownloads: false,
        allowMobileData: false,
      ),
    );

    expect(find.byKey(TransferPolicyBanner.bannerKey), findsNothing);
    expect(find.text('Waiting for network'), findsNothing);
  });
}
