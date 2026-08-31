# tamashii_network_cost

Private Android Flutter plugin used by Tamashii to classify the active network
for its torrent transfer policy. It reports a typed `NetworkStatus` containing
network cost, physical transport, and whether a VPN is active.

The Android implementation uses `ConnectivityManager` and reports one of:

- `offline`: there is no active Internet-capable network.
- `metered`: Android reports the active default network as metered.
- `unmetered`: Android reports the active default network as unmetered.
- `unknown`: Android cannot determine the active network's metering status.

The transport is reported independently as `offline`, `cellular`, `wifi`,
`other`, or `unknown`. Android includes a VPN's exposed physical underlay in
its `NetworkCapabilities`, so VPN-over-cellular and VPN-over-Wi-Fi remain
distinguishable. If a VPN does not expose its underlay, it is reported as
`isVpn: true` with an `unknown` transport. Cellular takes precedence if Android
reports both cellular and Wi-Fi, which prevents accidental mobile-data use.

Metering and transport are deliberately independent, but both are read from
the same callback-provided `NetworkCapabilities` snapshot. This prevents a VPN
underlay switch from pairing a new transport with stale metering information.
An active VPN can be reported as metered or unmetered while its exposed
cellular/Wi-Fi underlay is classified separately. No location or phone-state
permission is required.

Default-route handoffs emit a temporary `offline` status until Android supplies
the matching capabilities. Detector failures also report `offline`, ensuring a
consumer cannot briefly fail open while Wi-Fi changes to cellular.

The package intentionally has no non-Android implementation. Callers must only
create the platform client on Android.
