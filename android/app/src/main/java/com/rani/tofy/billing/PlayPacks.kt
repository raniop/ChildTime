package com.rani.tofy.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.BuildConfig
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.confirmedMerge
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.text.NumberFormat
import java.util.Currency

/**
 * PackStore.swift for Google Play — ⚽ question packs (forever, per child) and
 * 🌍 30-day world passes, bought on the PARENT's device behind the parent gate.
 * Consumable products: the first child in the family pays full price, every
 * further child the sibling price.
 *
 * After the server verified the token, the grant is written EXACTLY like
 * HouseholdManager.grantPack: children.packs (+ packExpiry for a pass),
 * households.ownedPacks, and the first-party sales ledger packPurchases/{order}.
 * Only then is the purchase consumed.
 */
object PlayPacks {
    private const val TAG = "TofyBilling"
    private val db get() = FirebaseFirestore.getInstance()

    private val _details = MutableStateFlow<Map<String, ProductDetails>>(emptyMap())
    val details: StateFlow<Map<String, ProductDetails>> = _details
    val didAttemptLoad = MutableStateFlow(false)
    val isPurchasing = MutableStateFlow(false)
    val lastError = MutableStateFlow<String?>(null)

    suspend fun load(context: Context) {
        BillingRepository.init(context)
        try {
            _details.value = BillingRepository.productDetails(PlayPack.allProductIds, ProductType.INAPP)
        } finally {
            didAttemptLoad.value = true
        }
    }

    /**
     * Every pack/pass product came back from Play. Prices are shown only as ONE
     * set — never a mix of a loaded price and a missing one (PackStore.allLoaded).
     */
    val allLoaded: Boolean get() = PlayPack.allProductIds.all { _details.value.containsKey(it) }

    /** The price on a card: Play's, or nothing. */
    fun displayPrice(pack: PlayPack): String? =
        if (allLoaded) _details.value[pack.productId]?.oneTimePurchaseOfferDetails?.formattedPrice else null

    /** One Play purchase sheet: a product and the children it is for. */
    data class Line(val details: ProductDetails, val childIDs: List<String>)

    /**
     * PackStore.priceLines: the first new child in a family that doesn't own
     * the pack at full price, every further child at the sibling price. Play
     * can't preset a quantity, so each sibling is its own purchase sheet — and
     * so each purchase knows exactly which child it pays for.
     */
    fun priceLines(pack: PlayPack, childIDs: List<String>, family: FamilyState = FamilyRepository.state.value): List<Line> {
        // A pass can always be bought again (renewal); a permanent pack only for children who don't have it.
        val newKids = if (pack.isPass) childIDs
            else childIDs.filter { id -> family.children.firstOrNull { it.id == id }?.hasPackRecord(pack) != true }
        if (newKids.isEmpty()) return emptyList()
        val familyOwns = !pack.isPass && (
            family.household?.ownedPacks?.contains(pack.id) == true || family.children.any { it.hasPackRecord(pack) })
        val lines = mutableListOf<Line>()
        var rest = newKids
        val full = _details.value[pack.productId]
        if (!familyOwns && full != null) { lines += Line(full, listOf(rest.first())); rest = rest.drop(1) }
        val sib = _details.value[pack.siblingProductId]
        if (sib != null) rest.forEach { lines += Line(sib, listOf(it)) }
        return lines
    }

    /** "₪14.90" — the total the parent will be charged, in Play's currency. */
    fun priceLabel(pack: PlayPack, childIDs: List<String>): String? {
        val lines = priceLines(pack, childIDs)
        if (lines.isEmpty()) return null
        val offers = lines.mapNotNull { it.details.oneTimePurchaseOfferDetails }
        if (offers.size != lines.size) return null
        if (offers.size == 1) return offers[0].formattedPrice
        val total = offers.sumOf { it.priceAmountMicros } / 1_000_000.0
        return runCatching {
            NumberFormat.getCurrencyInstance().apply { currency = Currency.getInstance(offers[0].priceCurrencyCode) }.format(total)
        }.getOrNull()
    }

    /** The result of a purchase: which children actually got the pack. */
    data class Result(val grantedChildIDs: List<String>, val complete: Boolean)

    /**
     * PackStore.purchase — one Play sheet per line; each verified purchase is
     * granted to ITS children before the next sheet opens. A cancel part-way
     * keeps what was already bought (iOS returns `granted`).
     */
    suspend fun purchase(activity: Activity, pack: PlayPack, childIDs: List<String>): Result {
        val lines = priceLines(pack, childIDs)
        if (lines.isEmpty()) return Result(childIDs, true)   // already owned — nothing to charge
        val hid = FamilyRepository.householdID ?: run {
            lastError.value = tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם."); return Result(emptyList(), false)
        }
        isPurchasing.value = true
        lastError.value = null
        val granted = mutableListOf<String>()
        try {
            for (line in lines) {
                val productId = line.details.productId
                // Remembered so a purchase that completes out-of-band (pending
                // payment, app killed mid-flow) still knows its children.
                savePending(productId, pack.id, line.childIDs)
                val params = BillingFlowParams.newBuilder()
                    .setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(line.details).build()))
                    .setObfuscatedAccountId(hid)
                    .build()
                when (val r = BillingRepository.launch(activity, params)) {
                    is BillingRepository.FlowResult.Done -> {
                        val p = r.purchases.firstOrNull { it.products.contains(productId) } ?: return Result(granted, false)
                        if (p.purchaseState == Purchase.PurchaseState.PENDING) {
                            lastError.value = BillingRepository.pendingMessage; return Result(granted, false)
                        }
                        if (!finish(p)) return Result(granted, false)
                        granted += line.childIDs
                    }
                    // An earlier purchase of this product was paid but never finished —
                    // complete it now, for the children chosen now.
                    BillingRepository.FlowResult.AlreadyOwned -> {
                        val old = BillingRepository.queryPurchases(ProductType.INAPP).firstOrNull { it.products.contains(productId) }
                        if (old == null || !finish(old)) return Result(granted, false)
                        granted += line.childIDs
                    }
                    else -> { lastError.value = BillingRepository.friendlyMessage(r); return Result(granted, false) }
                }
            }
            lastError.value = null
            return Result(granted, true)
        } finally {
            isPurchasing.value = false
        }
    }

    /** One finish at a time — the purchase flow and resume() can deliver the same purchase. */
    private val finishLock = kotlinx.coroutines.sync.Mutex()

    /**
     * Verify → grant once → consume. Also runs for purchases that finished
     * outside the flow (BillingRepository.resume / onPurchasesUpdated): those go
     * to the children of the remembered pending purchase, or — unknown — only
     * to the household (iOS: the same, `childIDs: []`).
     */
    suspend fun finish(p: Purchase): Boolean = finishLock.withLock { finishLocked(p) }

    private suspend fun finishLocked(p: Purchase): Boolean {
        if (p.purchaseState != Purchase.PurchaseState.PURCHASED) return false
        val productId = p.products.firstOrNull() ?: return false
        val pack = PlayPack.forProduct(productId) ?: return false
        val key = orderKey(p)
        if (isGranted(key)) { BillingRepository.consume(p); return true }
        val hid = BillingRepository.householdFor(p) ?: return false
        val v = BillingRepository.verify(p, hid)
        if (!v.ok) {
            if (v.reason == "consumed") { markGranted(key); return true }   // finished on an earlier run
            lastError.value = when (v.reason) {
                "network" -> BillingRepository.verifyPendingMessage
                "pending" -> BillingRepository.pendingMessage
                else -> tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם.")
            }
            return false
        }
        val pending = pending(productId)
        val kids = if (pending?.first == pack.id) pending.second else emptyList()
        // The server already holds this order's ledger → the grant landed on an earlier run.
        if (!v.granted) grant(pack, kids, productId, BillingRepository.price(_details.value[productId]), v.orderId ?: key, hid)
        markGranted(key)
        clearPending(productId)
        BillingRepository.consume(p)
        return true
    }

    /**
     * HouseholdManager.grantPack, field for field: the pack lands on each child
     * (confirmed + self-healing, like every parent→child write), the family is
     * marked as owning it (sibling price from now on), and the sale is logged in
     * the first-party ledger (no third-party analytics — Kids Category).
     */
    private suspend fun grant(pack: PlayPack, childIDs: List<String>, productId: String, price: Double?, transactionID: String, hid: String) {
        val family = FamilyRepository.state.value
        val now = nowSecs()
        for (cid in childIDs) {
            val fields = mutableMapOf<String, Any?>(
                "packs" to FieldValue.arrayUnion(pack.id),
                "packRequestedAt" to FieldValue.delete(), "packRequestedID" to FieldValue.delete(),
            )
            pack.durationDays?.let { days ->
                // A renewal stacks on the time left; an expired pass restarts now.
                val base = maxOf(family.children.firstOrNull { it.id == cid }?.packExpiry(pack) ?: 0.0, now)
                fields["packExpiry"] = mapOf(pack.id to base + days * 86_400.0)
                // The child asked for this world with Tofy+ — the pass answers it.
                fields["premiumRequestedAt"] = FieldValue.delete(); fields["premiumRequestedTopic"] = FieldValue.delete()
            }
            val out = ChildRepository.update(cid, fields)
            if (out == WriteOutcome.DENIED || out == WriteOutcome.ERROR) Log.w(TAG, "grantPack: child ${cid.take(8)} write FAILED ($out)")
        }
        val hhRef = db.collection("households").document(hid)
        var out = confirmedMerge(hhRef, mapOf("ownedPacks" to FieldValue.arrayUnion(pack.id)))
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(hhRef, mapOf("ownedPacks" to FieldValue.arrayUnion(pack.id))) }
        val sale = mutableMapOf<String, Any?>(
            "householdID" to hid, "packID" to pack.id, "productID" to productId,
            "childIDs" to childIDs, "transactionID" to transactionID,
            "at" to nowSecs(), "build" to BuildConfig.VERSION_CODE.toString(),
            "store" to "play",
        )
        price?.let { sale["price"] = it }
        FirebaseAuth.getInstance().currentUser?.uid?.let { sale["parentUID"] = it }
        runCatching { db.collection("packPurchases").document(transactionID).set(sale, SetOptions.merge()).await() }
            .onFailure { Log.w(TAG, "packPurchases ledger", it) }
    }

    // MARK: - Local bookkeeping (PackStore grantedTxIDs / pending)

    private val prefs get() = BillingRepository.prefs()

    private fun isGranted(key: String) = prefs.getStringSet("packs.granted", emptySet())!!.contains(key)
    private fun markGranted(key: String) {
        val s = prefs.getStringSet("packs.granted", emptySet())!!.toMutableSet().apply { add(key) }
        prefs.edit().putStringSet("packs.granted", s).apply()
    }

    private fun savePending(productId: String, packID: String, kids: List<String>) {
        prefs.edit().putString("packs.pending.$productId", JSONObject().put("pack", packID).put("children", JSONArray(kids)).toString()).apply()
    }
    private fun pending(productId: String): Pair<String, List<String>>? = runCatching {
        val o = JSONObject(prefs.getString("packs.pending.$productId", null) ?: return null)
        val a = o.getJSONArray("children")
        o.getString("pack") to (0 until a.length()).map { a.getString(it) }
    }.getOrNull()
    private fun clearPending(productId: String) { prefs.edit().remove("packs.pending.$productId").apply() }
}

/**
 * The order id Play gives a finished purchase; the server uses the same
 * fallback (`token-` + 24 hex of the token's SHA-256) when there is none.
 */
fun orderKey(p: Purchase): String = p.orderId?.takeIf { it.isNotBlank() }
    ?: "token-" + MessageDigest.getInstance("SHA-256").digest(p.purchaseToken.toByteArray()).joinToString("") { "%02x".format(it) }.take(24)
