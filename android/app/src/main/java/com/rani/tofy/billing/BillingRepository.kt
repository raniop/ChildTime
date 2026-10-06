package com.rani.tofy.billing

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.consumePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * Google Play Billing — the shared plumbing under PlaySubscriptions (Tofy+),
 * PlayPacks (⚽ packs / 🌍 passes) and PlayDiamonds (💎), the Android twins of
 * SubscriptionManager / PackStore / StarPackStore.
 *
 * The rule that differs from iOS: NOTHING is granted on the client's word.
 * Every purchase token goes to the `verifyPlayPurchase` callable first; for
 * Tofy+ the SERVER writes households.premiumUntil, for packs and diamonds the
 * client then writes exactly what iOS writes. Only after that is the purchase
 * acknowledged (subscription) or consumed (one-time) — an unfinished purchase
 * is picked up again by [resume] on the next launch, and Google refunds one
 * that is never acknowledged within 3 days.
 *
 * Every purchase carries the household id as `obfuscatedAccountId` (iOS:
 * appAccountToken) so Real-Time Developer Notifications reach the family.
 */
object BillingRepository : PurchasesUpdatedListener {
    private const val TAG = "TofyBilling"
    private lateinit var app: Context
    private var client: BillingClient? = null
    private val connectLock = Mutex()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** The purchase flow in flight — Play answers on the listener, not the launch call. */
    private var inFlight: CompletableDeferred<FlowResult>? = null

    sealed class FlowResult {
        data class Done(val purchases: List<Purchase>) : FlowResult()
        data object Cancelled : FlowResult()
        data object AlreadyOwned : FlowResult()
        data class Failed(val code: Int) : FlowResult()
    }

    /** verifyPlayPurchase's answer. `granted` = the server already holds this pack's ledger. */
    data class Verify(val ok: Boolean, val reason: String?, val orderId: String?, val granted: Boolean, val expiresAt: Double?, val networkError: Boolean = false)

    /** Idempotent; any screen that sells calls it (the lead may also call it from TofyApp). */
    fun init(context: Context) {
        if (::app.isInitialized) return
        app = context.applicationContext
    }

    /** Granted order ids + the children of a purchase in flight — survives a killed app. */
    internal fun prefs() = app.getSharedPreferences("tofy.billing", Context.MODE_PRIVATE)

    private fun build(): BillingClient = BillingClient.newBuilder(app)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    /** Connect (or reconnect after Play dropped us). False = Play is unavailable on this device. */
    suspend fun connect(): Boolean = connectLock.withLock {
        val c = client ?: build().also { client = it }
        if (c.isReady) return@withLock true
        val ok = withTimeoutOrNull(15_000) {
            suspendCancellableCoroutine { cont ->
                c.startConnection(object : BillingClientStateListener {
                    override fun onBillingSetupFinished(result: BillingResult) {
                        if (cont.isActive) cont.resume(result.responseCode == BillingResponseCode.OK)
                    }
                    override fun onBillingServiceDisconnected() {
                        // Next call reconnects; nothing to do now.
                        if (cont.isActive) cont.resume(false)
                    }
                })
            }
        } ?: false
        if (!ok) { runCatching { c.endConnection() }; client = null }
        ok
    }

    /** ProductDetails by id; empty when Play is unreachable or the products aren't set up yet. */
    suspend fun productDetails(ids: List<String>, type: String): Map<String, ProductDetails> {
        if (ids.isEmpty() || !connect()) return emptyMap()
        val c = client ?: return emptyMap()
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(ids.map { QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(type).build() })
            .build()
        val r = c.queryProductDetails(params)
        if (r.billingResult.responseCode != BillingResponseCode.OK) Log.w(TAG, "productDetails: ${r.billingResult.debugMessage}")
        return r.productDetailsList.orEmpty().associateBy { it.productId }
    }

    /** Open Play's purchase sheet and wait for its answer. */
    suspend fun launch(activity: Activity, params: BillingFlowParams): FlowResult {
        if (!connect()) return FlowResult.Failed(BillingResponseCode.SERVICE_UNAVAILABLE)
        val c = client ?: return FlowResult.Failed(BillingResponseCode.SERVICE_UNAVAILABLE)
        val d = CompletableDeferred<FlowResult>()
        inFlight = d
        val r = c.launchBillingFlow(activity, params)
        if (r.responseCode != BillingResponseCode.OK) {
            inFlight = null
            return mapFailure(r.responseCode)
        }
        return d.await()
    }

    private fun mapFailure(code: Int): FlowResult = when (code) {
        BillingResponseCode.USER_CANCELED -> FlowResult.Cancelled
        BillingResponseCode.ITEM_ALREADY_OWNED -> FlowResult.AlreadyOwned
        else -> FlowResult.Failed(code)
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        val waiting = inFlight
        if (waiting != null && waiting.isActive) {
            inFlight = null
            waiting.complete(
                if (result.responseCode == BillingResponseCode.OK) FlowResult.Done(purchases.orEmpty()) else mapFailure(result.responseCode)
            )
            return
        }
        // Out of band: a pending purchase that completed later (cash at a store,
        // a family-payment approval), or a purchase from a promo code.
        if (result.responseCode == BillingResponseCode.OK && !purchases.isNullOrEmpty()) {
            scope.launch { purchases.forEach { route(it) } }
        }
    }

    /**
     * Finish every purchase Play still holds open: subscriptions not yet
     * acknowledged, one-time products not yet consumed. Call on app start /
     * Activity.onResume (Play's own recommendation) — the screens call it too.
     */
    fun resume(context: Context) {
        init(context)
        scope.launch {
            runCatching {
                queryPurchases(ProductType.SUBS).filter { !it.isAcknowledged }.forEach { route(it) }
                queryPurchases(ProductType.INAPP).forEach { route(it) }
            }.onFailure { Log.w(TAG, "resume", it) }
        }
    }

    private suspend fun route(p: Purchase) {
        if (p.purchaseState != Purchase.PurchaseState.PURCHASED) return
        val id = p.products.firstOrNull() ?: return
        when {
            ProductIds.isSubscription(id) -> PlaySubscriptions.finish(p)
            ProductIds.isStars(id) -> PlayDiamonds.finish(p)
            ProductIds.isPackOrPass(id) -> PlayPacks.finish(p)
        }
    }

    suspend fun queryPurchases(type: String): List<Purchase> {
        if (!connect()) return emptyList()
        val c = client ?: return emptyList()
        val r = c.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(type).build())
        return if (r.billingResult.responseCode == BillingResponseCode.OK) r.purchasesList else emptyList()
    }

    /** The family a purchase belongs to: the id we tagged it with, else this device's family. */
    fun householdFor(p: Purchase?): String? =
        p?.accountIdentifiers?.obfuscatedAccountId?.takeIf { it.isNotBlank() }
            ?: FamilyRepository.householdID
            ?: (KidSession.childDoc.value?.get("householdID") as? String)?.takeIf { it.isNotBlank() }

    /** Ask the server to check this token with Google before anything is granted. */
    suspend fun verify(p: Purchase, householdID: String): Verify {
        val productId = p.products.firstOrNull() ?: return Verify(false, "invalid", null, false, null)
        val data = hashMapOf(
            "householdID" to householdID,
            "productId" to productId,
            "purchaseToken" to p.purchaseToken,
            "type" to if (ProductIds.isSubscription(productId)) "subs" else "inapp",
        )
        return try {
            val res = FirebaseFunctions.getInstance().getHttpsCallable("verifyPlayPurchase").call(data).await()
            val m = res.getData() as? Map<*, *> ?: emptyMap<String, Any?>()
            Verify(
                ok = m["ok"] == true,
                reason = m["reason"] as? String,
                orderId = (m["orderId"] as? String) ?: p.orderId,
                granted = m["granted"] == true,
                expiresAt = (m["expiresAt"] as? Number)?.toDouble(),
            )
        } catch (e: Exception) {
            Log.w(TAG, "verify $productId", e)
            val code = (e as? FirebaseFunctionsException)?.code
            // permission-denied / invalid-argument are final; everything else retries on next resume.
            val final = code == FirebaseFunctionsException.Code.PERMISSION_DENIED || code == FirebaseFunctionsException.Code.INVALID_ARGUMENT
            Verify(false, if (final) "denied" else "network", p.orderId, false, null, networkError = !final)
        }
    }

    /** Subscriptions: tell Google we delivered (else it refunds after 3 days). */
    suspend fun acknowledge(p: Purchase): Boolean {
        if (p.isAcknowledged) return true
        if (!connect()) return false
        val c = client ?: return false
        val r = c.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build())
        if (r.responseCode != BillingResponseCode.OK) Log.w(TAG, "acknowledge: ${r.responseCode} ${r.debugMessage}")
        return r.responseCode == BillingResponseCode.OK
    }

    /** One-time products: consumed = delivered and buyable again (a second child, a renewal, more 💎). */
    suspend fun consume(p: Purchase): Boolean {
        if (!connect()) return false
        val c = client ?: return false
        val r = c.consumePurchase(ConsumeParams.newBuilder().setPurchaseToken(p.purchaseToken).build())
        if (r.billingResult.responseCode != BillingResponseCode.OK) Log.w(TAG, "consume: ${r.billingResult.responseCode} ${r.billingResult.debugMessage}")
        return r.billingResult.responseCode == BillingResponseCode.OK
    }

    /**
     * SubscriptionManager.friendlyMessage — a parent never sees a raw Play
     * string (they're English and developer-facing). Null = say nothing (cancel).
     */
    fun friendlyMessage(r: FlowResult): String? = when (r) {
        FlowResult.Cancelled, is FlowResult.Done -> null
        FlowResult.AlreadyOwned -> null
        is FlowResult.Failed -> when (r.code) {
            BillingResponseCode.SERVICE_UNAVAILABLE, BillingResponseCode.SERVICE_DISCONNECTED, BillingResponseCode.NETWORK_ERROR ->
                tr("אֵין חִבּוּר לָאִינְטֶרְנֶט. בִּדְקוּ אֶת הַחִבּוּר וְנַסּוּ שׁוּב.")
            else -> tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם.")
        }
    }

    /** Paid at Google, but our server hasn't confirmed it yet — never "you weren't charged". */
    val verifyPendingMessage: String
        get() = tr("הָרְכִישָׁה הִצְלִיחָה, וַאֲנַחְנוּ עוֹד מְאַמְּתִים אוֹתָהּ מוּל Google Play. הִיא תִּכָּנֵס לְתֹקֶף מֵעַצְמָהּ בְּעוֹד כַּמָּה רְגָעִים.")

    /** A purchase Play holds as PENDING (cash payment, family approval). */
    val pendingMessage: String
        get() = tr("הַהַזְמָנָה נִשְׁלְחָה לְאִשּׁוּר. הִיא תִּכָּנֵס לְתֹקֶף בָּרֶגַע שֶׁתְּאֻשַּׁר.")

    /** "Price in the store's currency" — micros → Double for the first-party sales ledger. */
    fun price(d: ProductDetails?): Double? = d?.oneTimePurchaseOfferDetails?.priceAmountMicros?.let { it / 1_000_000.0 }
}

/** The Activity behind a Compose context — launchBillingFlow needs one. */
tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
