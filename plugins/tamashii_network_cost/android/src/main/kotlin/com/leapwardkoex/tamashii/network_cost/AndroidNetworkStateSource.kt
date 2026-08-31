package com.leapwardkoex.tamashii.network_cost

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities

internal class AndroidNetworkStateSource(
    private val connectivityManager: ConnectivityManager,
) : NetworkStateSource {
    private val lock = Any()
    private var registered = false
    private var onChanged: (() -> Unit)? = null
    private var callbackNetwork: Network? = null
    private var callbackSnapshot: NetworkSnapshot? = null

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            synchronized(lock) {
                callbackNetwork = network
                // Fail closed while Android prepares the authoritative
                // capabilities snapshot for this new default route.
                callbackSnapshot = NetworkSnapshot(hasActiveNetwork = false)
            }
            // On API 26+ the matching capabilities callback follows. A brief
            // offline status is safer than allowing traffic with the previous
            // Wi-Fi status during a switch to cellular.
            notifyChanged()
        }

        override fun onLost(network: Network) {
            val changed = synchronized(lock) {
                if (callbackNetwork == network) {
                    callbackNetwork = null
                    callbackSnapshot = NetworkSnapshot(hasActiveNetwork = false)
                    true
                } else {
                    false
                }
            }
            if (changed) notifyChanged()
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities,
        ) {
            val snapshot = snapshotFromCapabilities(networkCapabilities)
            val changed = synchronized(lock) {
                if (callbackNetwork != network) {
                    false
                } else {
                    callbackSnapshot = snapshot
                    true
                }
            }
            if (changed) notifyChanged()
        }

        override fun onBlockedStatusChanged(network: Network, blocked: Boolean) =
            notifyChanged()
    }

    override fun currentSnapshot(): NetworkSnapshot {
        synchronized(lock) { callbackSnapshot }?.let { return it }

        val activeNetwork = connectivityManager.activeNetwork
            ?: return NetworkSnapshot(hasActiveNetwork = false)
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            ?: return NetworkSnapshot(hasActiveNetwork = false)
        return snapshotFromCapabilities(capabilities)
    }

    private fun snapshotFromCapabilities(
        capabilities: NetworkCapabilities,
    ): NetworkSnapshot {
        val hasInternet = capabilities.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_INTERNET,
        )
        val isVpn = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        val metered = if (hasInternet) {
            !capabilities.hasCapability(
                NetworkCapabilities.NET_CAPABILITY_NOT_METERED,
            )
        } else {
            null
        }

        return NetworkSnapshot(
            hasActiveNetwork = true,
            hasInternetCapability = hasInternet,
            isVpn = isVpn,
            isMetered = metered,
            hasCellularTransport = capabilities.hasTransport(
                NetworkCapabilities.TRANSPORT_CELLULAR,
            ),
            hasWifiTransport = capabilities.hasTransport(
                NetworkCapabilities.TRANSPORT_WIFI,
            ),
            hasOtherTransport = capabilities.hasAnyOtherTransport(),
        )
    }

    override fun start(onChanged: () -> Unit) {
        stop()
        synchronized(lock) { this.onChanged = onChanged }
        try {
            connectivityManager.registerDefaultNetworkCallback(callback)
            synchronized(lock) { registered = true }
        } catch (error: RuntimeException) {
            synchronized(lock) { this.onChanged = null }
            throw error
        }
    }

    override fun stop() {
        val shouldUnregister = synchronized(lock) {
            onChanged = null
            val result = registered
            registered = false
            callbackNetwork = null
            callbackSnapshot = null
            result
        }
        if (!shouldUnregister) return

        try {
            connectivityManager.unregisterNetworkCallback(callback)
        } catch (_: IllegalArgumentException) {
            // The framework may have already removed the callback.
        } catch (_: SecurityException) {
            // Detachment must remain safe if permission state changed.
        }
    }

    private fun notifyChanged() {
        val callback = synchronized(lock) { onChanged }
        callback?.invoke()
    }
}

private fun NetworkCapabilities.hasAnyOtherTransport(): Boolean =
    hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) ||
        hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ||
        hasTransport(NetworkCapabilities.TRANSPORT_WIFI_AWARE) ||
        hasTransport(NetworkCapabilities.TRANSPORT_LOWPAN) ||
        hasTransport(NetworkCapabilities.TRANSPORT_USB)
