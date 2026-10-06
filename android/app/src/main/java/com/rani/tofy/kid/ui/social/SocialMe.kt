package com.rani.tofy.kid.ui.social

import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.data.Child
import com.rani.tofy.i18n.I18n
import com.rani.tofy.kid.core.KidSession

/**
 * "Who am I" for the social screens — the iOS ProfileStore.active /
 * ProgressStore.shared / AuthManager reads, answered from the bound KidSession.
 */
internal object SocialMe {
    /** ProfileStore.activeID?.uuidString — the bound child. */
    val id: String? get() = KidSession.boundChildID
    /** AuthManager.userID (anonymous on a child device, the parent in Kid Mode). */
    val uid: String? get() = FirebaseAuth.getInstance().currentUser?.uid
    val isSignedIn: Boolean get() = uid != null
    val child: Child? get() { val cid = id ?: return null; return KidSession.childDoc.value?.let { Child.from(cid, it) } }
    val name: String get() = child?.name ?: ""
    /** Parent switch (child doc `friendsEnabled`, missing = on): friends + leaderboards for this child. */
    val friendsEnabled: Boolean get() = (com.rani.tofy.kid.core.KidSession.childDoc.value?.get("friendsEnabled") as? Boolean) ?: true
    val character3DID: String? get() = child?.character3DID
    val isGirl: Boolean get() = child?.isGirl == true
    val householdID: String? get() = child?.householdID?.takeIf { it.isNotEmpty() }
    /** ProgressStore.shared.stars — the live local count. */
    val stars: Int get() = KidSession.state.value?.snapshot?.stars ?: 0
    /** LanguageStore.shared.current.rawValue */
    val language: String get() = I18n.language.code

    /** Gendered.g(male, female) — the child's own form. */
    fun g(male: String, female: String) = if (isGirl) female else male
}
