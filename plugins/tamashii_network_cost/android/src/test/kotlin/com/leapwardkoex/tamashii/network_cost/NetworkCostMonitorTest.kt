package com.leapwardkoex.tamashii.network_cost

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkCostMonitorTest {
    @Test
    fun classifierCoversOfflineAndUnknownStates() {
        assertStatus(
            NetworkSnapshot(hasActiveNetwork = false),
            NetworkCostValue.OFFLINE,
            NetworkTransportValue.OFFLINE,
        )
        assertStatus(
            NetworkSnapshot(
                hasActiveNetwork = true,
                hasInternetCapability = false,
                isVpn = true,
                hasCellularTransport = true,
            ),
            NetworkCostValue.OFFLINE,
            NetworkTransportValue.OFFLINE,
            isVpn = true,
        )
        assertStatus(
            NetworkSnapshot(hasActiveNetwork = true),
            NetworkCostValue.UNKNOWN,
            NetworkTransportValue.UNKNOWN,
        )
    }

    @Test
    fun classifierKeepsCostIndependentFromPhysicalTransport() {
        assertStatus(
            internetSnapshot(isMetered = true, hasWifiTransport = true),
            NetworkCostValue.METERED,
            NetworkTransportValue.WIFI,
        )
        assertStatus(
            internetSnapshot(isMetered = false, hasCellularTransport = true),
            NetworkCostValue.UNMETERED,
            NetworkTransportValue.CELLULAR,
        )
        assertStatus(
            internetSnapshot(isMetered = null, hasOtherTransport = true),
            NetworkCostValue.UNKNOWN,
            NetworkTransportValue.OTHER,
        )
    }

    @Test
    fun classifierIdentifiesVpnUnderlyingTransport() {
        assertStatus(
            internetSnapshot(
                isVpn = true,
                isMetered = true,
                hasCellularTransport = true,
            ),
            NetworkCostValue.METERED,
            NetworkTransportValue.CELLULAR,
            isVpn = true,
        )
        assertStatus(
            internetSnapshot(
                isVpn = true,
                isMetered = false,
                hasWifiTransport = true,
            ),
            NetworkCostValue.UNMETERED,
            NetworkTransportValue.WIFI,
            isVpn = true,
        )
        assertStatus(
            internetSnapshot(isVpn = true, isMetered = false),
            NetworkCostValue.UNMETERED,
            NetworkTransportValue.UNKNOWN,
            isVpn = true,
        )
    }

    @Test
    fun cellularWinsWhenAndroidReportsMultipleUnderlyingTransports() {
        assertStatus(
            internetSnapshot(
                isVpn = true,
                isMetered = true,
                hasCellularTransport = true,
                hasWifiTransport = true,
                hasOtherTransport = true,
            ),
            NetworkCostValue.METERED,
            NetworkTransportValue.CELLULAR,
            isVpn = true,
        )
    }

    @Test
    fun rapidVpnWifiToCellularTransitionIsNotDeduplicated() {
        val source = FakeNetworkStateSource(
            internetSnapshot(
                isVpn = true,
                isMetered = false,
                hasWifiTransport = true,
            ),
        )
        val monitor = NetworkStatusMonitor(source)
        val events = mutableListOf<NetworkStatusValue>()

        monitor.start(events::add)
        source.snapshot = internetSnapshot(
            isVpn = true,
            isMetered = true,
            hasCellularTransport = true,
        )
        source.emit()

        assertEquals(
            listOf(NetworkTransportValue.WIFI, NetworkTransportValue.CELLULAR),
            events.map(NetworkStatusValue::transport),
        )
        assertEquals(
            listOf(NetworkCostValue.UNMETERED, NetworkCostValue.METERED),
            events.map(NetworkStatusValue::cost),
        )
        assertTrue(events.all(NetworkStatusValue::isVpn))
    }

    @Test
    fun wireValueUsesStrictTypedMap() {
        assertEquals(
            mapOf(
                "cost" to "metered",
                "transport" to "cellular",
                "isVpn" to true,
            ),
            NetworkStatusValue(
                NetworkCostValue.METERED,
                NetworkTransportValue.CELLULAR,
                isVpn = true,
            ).toWireValue(),
        )
    }

    @Test
    fun monitorEmitsInitialValueAndDistinctStatusChangesOnly() {
        val source = FakeNetworkStateSource(
            internetSnapshot(isMetered = false, hasWifiTransport = true),
        )
        val monitor = NetworkStatusMonitor(source)
        val events = mutableListOf<NetworkStatusValue>()

        monitor.start(events::add)
        source.emit()
        source.snapshot = internetSnapshot(
            isVpn = true,
            isMetered = false,
            hasWifiTransport = true,
        )
        source.emit()
        source.emit()
        source.snapshot = internetSnapshot(
            isVpn = true,
            isMetered = true,
            hasCellularTransport = true,
        )
        source.emit()
        source.snapshot = NetworkSnapshot(hasActiveNetwork = false)
        source.emit()

        assertEquals(
            listOf(
                NetworkStatusValue(
                    NetworkCostValue.UNMETERED,
                    NetworkTransportValue.WIFI,
                    isVpn = false,
                ),
                NetworkStatusValue(
                    NetworkCostValue.UNMETERED,
                    NetworkTransportValue.WIFI,
                    isVpn = true,
                ),
                NetworkStatusValue(
                    NetworkCostValue.METERED,
                    NetworkTransportValue.CELLULAR,
                    isVpn = true,
                ),
                NetworkStatusValue(
                    NetworkCostValue.OFFLINE,
                    NetworkTransportValue.OFFLINE,
                    isVpn = false,
                ),
            ),
            events,
        )
        assertEquals(1, source.startCount)

        monitor.stop()
        source.snapshot = internetSnapshot(
            isMetered = false,
            hasWifiTransport = true,
        )
        source.emit()
        assertEquals(4, events.size)
        assertEquals(1, source.stopCount)
    }

    @Test
    fun restartUnregistersOldSubscriptionAndEmitsFreshSnapshot() {
        val source = FakeNetworkStateSource(
            internetSnapshot(isMetered = false, hasWifiTransport = true),
        )
        val monitor = NetworkStatusMonitor(source)
        val first = mutableListOf<NetworkStatusValue>()
        val second = mutableListOf<NetworkStatusValue>()

        monitor.start(first::add)
        source.snapshot = internetSnapshot(
            isMetered = true,
            hasCellularTransport = true,
        )
        monitor.start(second::add)

        assertEquals(1, first.size)
        assertEquals(NetworkTransportValue.WIFI, first.single().transport)
        assertEquals(1, second.size)
        assertEquals(NetworkTransportValue.CELLULAR, second.single().transport)
        assertEquals(2, source.startCount)
        assertEquals(1, source.stopCount)
    }

    @Test
    fun unavailableSourceFailsClosedAsOffline() {
        val source = FakeNetworkStateSource(
            internetSnapshot(isMetered = false, hasWifiTransport = true),
        ).apply {
            failCurrent = true
        }
        val monitor = NetworkStatusMonitor(source)

        val current = monitor.current()
        assertEquals(NetworkCostValue.OFFLINE, current.cost)
        assertEquals(NetworkTransportValue.OFFLINE, current.transport)
        assertFalse(current.isVpn)

        source.failStart = true
        val events = mutableListOf<NetworkStatusValue>()
        monitor.start(events::add)
        assertEquals(1, events.size)
        assertEquals(NetworkCostValue.OFFLINE, events.single().cost)
        assertEquals(NetworkTransportValue.OFFLINE, events.single().transport)
    }

    private fun assertStatus(
        snapshot: NetworkSnapshot,
        cost: NetworkCostValue,
        transport: NetworkTransportValue,
        isVpn: Boolean = false,
    ) {
        val status = classifyNetworkStatus(snapshot)
        assertEquals(cost, status.cost)
        assertEquals(transport, status.transport)
        assertEquals(isVpn, status.isVpn)
        if (isVpn) assertTrue(status.isVpn) else assertFalse(status.isVpn)
    }
}

private fun internetSnapshot(
    isVpn: Boolean = false,
    isMetered: Boolean?,
    hasCellularTransport: Boolean = false,
    hasWifiTransport: Boolean = false,
    hasOtherTransport: Boolean = false,
) = NetworkSnapshot(
    hasActiveNetwork = true,
    hasInternetCapability = true,
    isVpn = isVpn,
    isMetered = isMetered,
    hasCellularTransport = hasCellularTransport,
    hasWifiTransport = hasWifiTransport,
    hasOtherTransport = hasOtherTransport,
)

private class FakeNetworkStateSource(
    var snapshot: NetworkSnapshot,
) : NetworkStateSource {
    var startCount = 0
    var stopCount = 0
    var failCurrent = false
    var failStart = false
    private var listener: (() -> Unit)? = null

    override fun currentSnapshot(): NetworkSnapshot {
        if (failCurrent) throw IllegalStateException("unavailable")
        return snapshot
    }

    override fun start(onChanged: () -> Unit) {
        startCount += 1
        if (failStart) throw IllegalStateException("unavailable")
        listener = onChanged
    }

    override fun stop() {
        stopCount += 1
        listener = null
    }

    fun emit() = listener?.invoke() ?: Unit
}
