package com.rani.tofy.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.withLock

/**
 * StarPackStore.swift for Google Play — consumable 💎 diamond packs (60 / 200 /
 * 500), bought on the CHILD's device (or Kid Mode) behind the parent gate.
 * 💎 are the spendable shop currency; ⭐ stars are rank-only and never sold.
 *
 * Granted exactly like iOS (ProgressStore.addDiamonds → the child's progress
 * snapshot, synced), but only after the server verified the token; consumed
 * last, so an interrupted purchase is finished on the next launch.
 */
object PlayDiamonds {
    private val _products = MutableStateFlow<List<ProductDetails>>(emptyList())
    val products: StateFlow<List<ProductDetails>> = _products
    val isLoading = MutableStateFlow(false)
    /** A load attempt finished — "still loading" vs "loaded, but nothing available". */
    val didAttemptLoad = MutableStateFlow(false)
    val isPurchasing = MutableStateFlow(false)
    val lastError = MutableStateFlow<String?>(null)
    /** The 💎 just granted, for the celebration; the UI resets it to null. */
    val lastGrantedDiamonds = MutableStateFlow<Int?>(null)

    suspend fun load(context: Context) {
        BillingRepository.init(context)
        isLoading.value = true
        try {
            val d = BillingRepository.productDetails(ProductIds.STARS, ProductType.INAPP)
            _products.value = d.values.sortedBy { ProductIds.diamonds(it.productId) }
        } finally {
            isLoading.value = false
            didAttemptLoad.value = true
        }
    }

    /** Best-value badge for the middle pack. */
    fun isBestValue(d: ProductDetails) = d.productId == ProductIds.STARS_MEDIUM

    suspend fun purchase(activity: Activity, d: ProductDetails, householdID: String?): Boolean {
        val hid = householdID ?: BillingRepository.householdFor(null) ?: run {
            lastError.value = tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם."); return false
        }
        isPurchasing.value = true
        try {
            val params = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(d).build()))
                .setObfuscatedAccountId(hid)
                .build()
            return when (val r = BillingRepository.launch(activity, params)) {
                is BillingRepository.FlowResult.Done -> {
                    val p = r.purchases.firstOrNull { it.products.contains(d.productId) } ?: return false
                    if (p.purchaseState == Purchase.PurchaseState.PENDING) { lastError.value = BillingRepository.pendingMessage; false }
                    else finish(p)
                }
                BillingRepository.FlowResult.AlreadyOwned -> {
                    // A paid pack never consumed (app killed) — deliver it now.
                    BillingRepository.queryPurchases(ProductType.INAPP).firstOrNull { it.products.contains(d.productId) }?.let { finish(it) } ?: false
                }
                else -> { lastError.value = BillingRepository.friendlyMessage(r); false }
            }
        } finally {
            isPurchasing.value = false
        }
    }

    /** One finish at a time — the purchase flow and resume() can deliver the same purchase. */
    private val finishLock = kotlinx.coroutines.sync.Mutex()

    /** Verify → credit once → consume. Also the out-of-band / resume path. */
    suspend fun finish(p: Purchase): Boolean = finishLock.withLock { finishLocked(p) }

    private suspend fun finishLocked(p: Purchase): Boolean {
        if (p.purchaseState != Purchase.PurchaseState.PURCHASED) return false
        val productId = p.products.firstOrNull() ?: return false
        val amount = ProductIds.diamonds(productId) * maxOf(1, p.quantity)
        if (amount <= 0) return false
        val key = orderKey(p)
        val prefs = BillingRepository.prefs()
        val granted = prefs.getStringSet("stars.granted", emptySet())!!
        if (key in granted) { BillingRepository.consume(p); return true }
        // No child bound on this device (e.g. a parent phone outside Kid Mode):
        // leave it unconsumed — it is delivered where the child plays.
        if (KidSession.engine() == null) return false
        val hid = BillingRepository.householdFor(p) ?: return false
        val v = BillingRepository.verify(p, hid)
        if (!v.ok) {
            if (v.reason == "consumed") return true
            lastError.value = when (v.reason) {
                "network" -> BillingRepository.verifyPendingMessage
                "pending" -> BillingRepository.pendingMessage
                else -> tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם.")
            }
            return false
        }
        KidSession.edit { it.addDiamonds(amount) } ?: return false
        prefs.edit().putStringSet("stars.granted", granted.toMutableSet().apply { add(key) }).apply()
        KidSession.pushNow()
        lastGrantedDiamonds.value = amount
        lastError.value = null
        BillingRepository.consume(p)
        return true
    }
}
