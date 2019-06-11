package net.mullvad.mullvadvpn

import java.net.InetAddress

import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Binder
import android.os.IBinder

import net.mullvad.mullvadvpn.model.TunConfig

class MullvadVpnService : VpnService() {
    private val created = CompletableDeferred<Unit>()
    private val binder = LocalBinder()

    val asyncDaemon = startDaemon()
    val daemon
        get() = runBlocking { asyncDaemon.await() }

    override fun onCreate() {
        created.complete(Unit)
    }

    override fun onBind(intent: Intent): IBinder {
        return super.onBind(intent) ?: binder
    }

    override fun onDestroy() {
        asyncDaemon.cancel()
        created.cancel()
    }

    fun createTun(config: TunConfig): Int {
        val builder = Builder().apply {
            for (address in config.addresses) {
                addAddress(address, 32)
            }

            for (dnsServer in config.dnsServers) {
                addDnsServer(dnsServer)
            }

            for (route in config.routes) {
                addRoute(route.address, route.prefixLength.toInt())
            }

            setMtu(config.mtu)
        }

        val vpnInterface = builder.establish()

        return vpnInterface.detachFd()
    }

    fun bypass(socket: Int): Boolean {
        return protect(socket)
    }

    inner class LocalBinder : Binder() {
        val asyncDaemon
            get() = this@MullvadVpnService.asyncDaemon
    }

    private fun startDaemon() = GlobalScope.async(Dispatchers.Default) {
        created.await()
        ApiRootCaFile().extract(application)
        MullvadDaemon(this@MullvadVpnService)
    }
}
