package com.rani.tofy.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.tasks.await
import kotlin.math.roundToInt

/**
 * SubscriptionManager.swift for Google Play — Tofy+ (family plan, monthly /
 * yearly). Entitlement is the household's `premiumUntil`, written by the
 * SERVER after it verified the token (verifyPlayPurchase) and kept current by
 * Play's Real-Time Developer Notifications (playRtdn) — renewals, cancels,
 * expiry and refunds reach every device of the family even if nobody opens the
 * app. So unlike iOS there is no publishPremium / clearPremiumIfSelfPublished
 * on the client: "is premium" is simply `household.isPremium`.
 */
object PlaySubscriptions {
    /** One plan on the paywall: the base plan's recurring price, plus the offer to buy with. */
    data class Plan(
        val id: String,
        val details: ProductDetails,
        val offerToken: String,
        val price: String,
        val priceMicros: Long,
        val freeTrial: Boolean,
    ) {
        /** Product.hebrewName */
        val name: String get() = if (id == ProductIds.MONTHLY) tr("חודשי") else tr("שנתי")
        /** Product.pricePerPeriod — "₪24.90 / חודש" */
        val pricePerPeriod: String get() = if (id == ProductIds.MONTHLY) tr("%@ / חודש", price) else tr("%@ / שנה", price)
    }

    private val _plans = MutableStateFlow<List<Plan>>(emptyList())
    val plans: StateFlow<List<Plan>> = _plans
    val isLoading = MutableStateFlow(false)
    val isPurchasing = MutableStateFlow(false)
    val lastError = MutableStateFlow<String?>(null)
    /**
     * The yearly plan carries a free-trial offer Play says this account may use,
     * AND the founder's knob allows it (config/conversion.storeKitTrial — under
     * the 14-day gift model it's OFF: never promise "7 ימים חינם" on top).
     */
    val yearlyIntroEligible = MutableStateFlow(false)

    suspend fun load(context: Context) {
        BillingRepository.init(context)
        isLoading.value = true
        try {
            val trialAllowed = runCatching {
                FirebaseFirestore.getInstance().collection("config").document("conversion").get().await().getBoolean("storeKitTrial")
            }.getOrNull() ?: false
            val d = BillingRepository.productDetails(ProductIds.SUBSCRIPTIONS, ProductType.SUBS)
            // Monthly → yearly, the paywall's order.
            _plans.value = ProductIds.SUBSCRIPTIONS.mapNotNull { id -> d[id]?.let { plan(it, trialAllowed) } }
            yearlyIntroEligible.value = _plans.value.firstOrNull { it.id == ProductIds.YEARLY }?.freeTrial == true
            if (_plans.value.isNotEmpty()) lastError.value = null
        } finally {
            isLoading.value = false
        }
    }

    private fun plan(d: ProductDetails, trialAllowed: Boolean): Plan? {
        val offers = d.subscriptionOfferDetails ?: return null
        val base = offers.firstOrNull { it.offerId == null } ?: offers.firstOrNull() ?: return null
        // Play lists only the offers this account is eligible for — a returning
        // subscriber simply gets no free-trial offer back.
        val trial = if (!trialAllowed) null else offers.firstOrNull { o ->
            o.offerId != null && o.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L }
        }
        val recurring = base.pricingPhases.pricingPhaseList.lastOrNull() ?: return null
        return Plan(d.productId, d, (trial ?: base).offerToken, recurring.formattedPrice, recurring.priceAmountMicros, trial != null)
    }

    /**
     * Product.savingsBadge — "חסוך 33%" computed from the two live prices, never
     * written down (the US store's saving is 44%, Israel's 33%).
     */
    fun savingsBadge(plan: Plan): String? {
        if (plan.id != ProductIds.YEARLY) return null
        val monthly = _plans.value.firstOrNull { it.id == ProductIds.MONTHLY } ?: return null
        val twelve = monthly.priceMicros * 12.0
        val yearly = plan.priceMicros.toDouble()
        if (twelve <= 0 || yearly >= twelve) return null
        val percent = ((twelve - yearly) / twelve * 100).roundToInt()
        if (percent < 5) return null
        return tr("חסוך %lld%%", percent)
    }

    /**
     * Buy a plan. True once the server confirmed it and wrote the family's
     * premium (the paywall then celebrates and closes).
     */
    suspend fun purchase(activity: Activity, plan: Plan): Boolean {
        val hid = FamilyRepository.householdID ?: run {
            lastError.value = tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם."); return false
        }
        isPurchasing.value = true
        try {
            val params = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(plan.details).setOfferToken(plan.offerToken).build()
                ))
                // Tag the purchase with the family so RTDN (renew, cancel, refund) reach the right household.
                .setObfuscatedAccountId(hid)
            // Switching plans (monthly ↔ yearly) REPLACES the running subscription,
            // like an App Store subscription group — never two paid plans at once.
            val running = BillingRepository.queryPurchases(ProductType.SUBS)
                .firstOrNull { it.purchaseState == Purchase.PurchaseState.PURCHASED && it.products.firstOrNull() != plan.id }
            if (running != null) {
                params.setSubscriptionUpdateParams(
                    BillingFlowParams.SubscriptionUpdateParams.newBuilder()
                        .setOldPurchaseToken(running.purchaseToken)
                        .setSubscriptionReplacementMode(BillingFlowParams.SubscriptionUpdateParams.ReplacementMode.WITH_TIME_PRORATION)
                        .build()
                )
            }
            return when (val r = BillingRepository.launch(activity, params.build())) {
                is BillingRepository.FlowResult.Done -> {
                    val p = r.purchases.firstOrNull { it.products.contains(plan.id) } ?: r.purchases.firstOrNull()
                    when {
                        p == null -> false
                        p.purchaseState == Purchase.PurchaseState.PENDING -> { lastError.value = BillingRepository.pendingMessage; false }
                        else -> finish(p)
                    }
                }
                // Already subscribed on this Google account: re-verify it for this family.
                BillingRepository.FlowResult.AlreadyOwned -> restore()
                else -> { lastError.value = BillingRepository.friendlyMessage(r); false }
            }
        } finally {
            isPurchasing.value = false
        }
    }

    /**
     * Server-verify, then acknowledge. Also the path for out-of-band and
     * restored purchases (BillingRepository.resume / onPurchasesUpdated).
     */
    suspend fun finish(p: Purchase): Boolean {
        if (p.purchaseState != Purchase.PurchaseState.PURCHASED) return false
        val hid = BillingRepository.householdFor(p) ?: return false
        val v = BillingRepository.verify(p, hid)
        if (v.ok) {
            BillingRepository.acknowledge(p)
            lastError.value = null
            return true
        }
        // A real, finished purchase that is simply over (expired) is still acknowledged.
        if (v.reason == "expired") BillingRepository.acknowledge(p)
        lastError.value = when (v.reason) {
            "network" -> BillingRepository.verifyPendingMessage
            "pending" -> BillingRepository.pendingMessage
            "expired" -> null
            else -> tr("לֹא הִצְלַחְנוּ לְהַשְׁלִים אֶת הָרְכִישָׁה כָּרֶגַע. נַסּוּ שׁוּב בְּעוֹד רֶגַע — לֹא חֻיַּבְתֶּם.")
        }
        return false
    }

    /**
     * "שחזר רכישה קיימת" — re-read Play's subscriptions for this Google account
     * and let the server re-apply them to the family. True when one is active.
     */
    suspend fun restore(): Boolean {
        lastError.value = null
        val subs = BillingRepository.queryPurchases(ProductType.SUBS).filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
        var any = false
        for (p in subs) if (finish(p)) any = true
        if (!any && lastError.value == null) lastError.value = tr("לֹא מָצָאנוּ מִנּוּי פָּעִיל בְּחֶשְׁבּוֹן Google Play הַזֶּה.")
        return any
    }

    // MARK: - First-party funnel (HouseholdManager.notePaywallSource / notePurchaseStarted)

    /** Where the parent came from — the server stamps it as purchaseSource when a purchase lands. */
    fun notePaywallSource(source: String) {
        val hid = FamilyRepository.householdID ?: return
        FirebaseFirestore.getInstance().collection("households").document(hid).set(
            mapOf("lastPaywallSource" to source, "paywallViews" to FieldValue.increment(1),
                "funnel" to mapOf("paywall" to FieldValue.increment(1))),
            SetOptions.merge(),
        )
    }

    fun notePurchaseStarted() {
        val hid = FamilyRepository.householdID ?: return
        FirebaseFirestore.getInstance().collection("households").document(hid).set(
            mapOf("purchaseStarted" to nowSecs(), "funnel" to mapOf("purchaseStarted" to FieldValue.increment(1))),
            SetOptions.merge(),
        )
    }
}
