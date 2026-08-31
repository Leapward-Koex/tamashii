package com.leapwardkoex.tamashii.network_cost

internal enum class NetworkCostValue(val wireValue: String) {
    OFFLINE("offline"),
    METERED("metered"),
    UNMETERED("unmetered"),
    UNKNOWN("unknown"),
}

internal enum class NetworkTransportValue(val wireValue: String) {
    OFFLINE("offline"),
    CELLULAR("cellular"),
    WIFI("wifi"),
    OTHER("other"),
    UNKNOWN("unknown"),
}

internal data class NetworkStatusValue(
    val cost: NetworkCostValue,
    val transport: NetworkTransportValue,
    val isVpn: Boolean,
) {
    fun toWireValue(): Map<String, Any> = mapOf(
        "cost" to cost.wireValue,
        "transport" to transport.wireValue,
        "isVpn" to isVpn,
    )
}

internal data class NetworkSnapshot(
    val hasActiveNetwork: Boolean,
    val hasInternetCapability: Boolean? = null,
    val isVpn: Boolean? = null,
    val isMetered: Boolean? = null,
    val hasCellularTransport: Boolean? = null,
    val hasWifiTransport: Boolean? = null,
    val hasOtherTransport: Boolean? = null,
)

internal fun classifyNetworkStatus(snapshot: NetworkSnapshot): NetworkStatusValue {
    val isOffline = !snapshot.hasActiveNetwork || snapshot.hasInternetCapability == false
    val transport = when {
        isOffline -> NetworkTransportValue.OFFLINE
        snapshot.hasInternetCapability == null -> NetworkTransportValue.UNKNOWN
        // Cellular wins when Android reports more than one physical transport.
        snapshot.hasCellularTransport == true -> NetworkTransportValue.CELLULAR
        snapshot.hasWifiTransport == true -> NetworkTransportValue.WIFI
        snapshot.hasOtherTransport == true -> NetworkTransportValue.OTHER
        else -> NetworkTransportValue.UNKNOWN
    }

    val cost = when {
        isOffline -> NetworkCostValue.OFFLINE
        snapshot.hasInternetCapability == null -> NetworkCostValue.UNKNOWN
        snapshot.isMetered == true -> NetworkCostValue.METERED
        snapshot.isMetered == false -> NetworkCostValue.UNMETERED
        else -> NetworkCostValue.UNKNOWN
    }

    return NetworkStatusValue(
        cost = cost,
        transport = transport,
        isVpn = snapshot.isVpn == true,
    )
}

internal fun classifyNetworkCost(snapshot: NetworkSnapshot): NetworkCostValue =
    classifyNetworkStatus(snapshot).cost

internal interface NetworkStateSource {
    fun currentSnapshot(): NetworkSnapshot

    fun start(onChanged: () -> Unit)

    fun stop()
}

/** Classifies and de-duplicates source events without depending on Flutter. */
internal class NetworkStatusMonitor(
    private val source: NetworkStateSource,
) {
    private val lock = Any()
    private var listener: ((NetworkStatusValue) -> Unit)? = null
    private var lastEmitted: NetworkStatusValue? = null

    fun current(): NetworkStatusValue = try {
        classifyNetworkStatus(source.currentSnapshot())
    } catch (_: RuntimeException) {
        NetworkStatusValue(
            cost = NetworkCostValue.OFFLINE,
            transport = NetworkTransportValue.OFFLINE,
            isVpn = false,
        )
    }

    fun start(listener: (NetworkStatusValue) -> Unit) {
        val wasStarted = synchronized(lock) { this.listener != null }
        if (wasStarted) source.stop()

        synchronized(lock) {
            this.listener = listener
            lastEmitted = null
        }

        try {
            source.start(::refresh)
        } catch (_: RuntimeException) {
            emit(
                NetworkStatusValue(
                    cost = NetworkCostValue.OFFLINE,
                    transport = NetworkTransportValue.OFFLINE,
                    isVpn = false,
                ),
            )
            return
        }
        refresh()
    }

    fun stop() {
        val wasStarted = synchronized(lock) {
            val result = listener != null
            listener = null
            lastEmitted = null
            result
        }
        if (wasStarted) source.stop()
    }

    private fun refresh() = emit(current())

    private fun emit(status: NetworkStatusValue) {
        val callback = synchronized(lock) {
            if (listener == null || lastEmitted == status) return
            lastEmitted = status
            listener
        }
        callback?.invoke(status)
    }
}
