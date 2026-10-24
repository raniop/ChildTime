package com.rani.tofy.data

/**
 * 🔒 "נעל עד שאשחרר" — the twin of iOS Models/ParentLock.swift (Rani,
 * 2026-10-24). The old "נעל עכשיו" only closed the window that was open — the
 * child opened again with their own minutes twelve minutes later (Emily,
 * 2026-10-22: locked at 18:22, reopened 18:34). This lock stays until a parent
 * releases it: from their phone, or with the parent code on the child's
 * device. Nothing is taken away — the minutes wait.
 *
 * Firestore shape (children/{id}.parentLock): { on: Bool, at: <unix secs> },
 * written ONLY by its own command (Commands.setParentLock, or the release on
 * the child's parent-gated controls) — never inside any other child write.
 */
data class ParentLock(val on: Boolean, val at: Double) {
    fun toMap(): Map<String, Any?> = mapOf("on" to on, "at" to at)

    companion object {
        fun from(d: Doc?): ParentLock? {
            d ?: return null
            return ParentLock(on = d.bool("on") ?: false, at = d.secs("at") ?: 0.0)
        }
    }
}
