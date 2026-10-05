package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.serialization.Serializable
import java.util.UUID

// The content layer reuses the parent side's Topic / Difficulty enums
// (ui/child/Topics.kt) so every raw id — Firestore keys, asset keys, the
// adaptive-level map — is spelled in exactly one place.

/**
 * One hand-curated multiple-choice item — BankQuestion (QuestionBanks.swift) in
 * the cloud wire shape (RemoteQuestionBank.Item) plus its topic. `tier` is
 * already resolved for built-ins (inline tier, else QuestionDifficultyTags,
 * else medium — done by tools/export-android-content.py).
 */
@Serializable
data class BankItem(
    val id: String = "",
    val prompt: String,
    val correctAnswer: String,
    val distractors: List<String>,
    val tier: String? = null,
    val gradeLo: Int,
    val gradeHi: Int,
    /** "en"/"ru"/"ar"; null = Hebrew (cloud items written before languages). */
    val lang: String? = null,
    val topic: String = "",
    /** SkillCatalog tag ("fractions", "mul"…); built-in bank items carry none. */
    val skill: String? = null,
    /** Cloud only: anything but "approved" never reaches a child. */
    val status: String? = null,
)

/** A bank question ready for selection: BankQuestion.swift + its resolved difficulty. */
data class BankQuestion(
    val prompt: String,
    val correctAnswer: String,
    val distractors: List<String>,
    val difficulty: Difficulty,
    val gradeLo: Int,
    val gradeHi: Int,
    val skill: String? = null,
) {
    fun inGrade(g: Int) = g in gradeLo..gradeHi

    /** Distance from a grade to this item's window (0 inside it) — makeFromBank.windowDistance. */
    fun gradeDistance(g: Int) = if (inGrade(g)) 0 else minOf(kotlin.math.abs(gradeLo - g), kotlin.math.abs(gradeHi - g))

    /** QuestionMemory.promptKey — prompt + answer, so shared prompts ("מי לא שייך?") stay distinct. */
    val key: String get() = "$prompt|$correctAnswer"
}

/** 📖 ReadingContent.ReadingPassage — `gradeLo…gradeHi` is already the resolved gradeWindow. */
@Serializable
data class PassageItem(
    val id: String,
    val tier: String,
    val gradeLo: Int,
    val gradeHi: Int,
    val text: String,
    val lang: String? = null,
    val questions: List<BankItem>,
)

data class ReadingPassage(
    val id: String,
    val tier: Difficulty,
    val gradeLo: Int,
    val gradeHi: Int,
    val text: String,
    val questions: List<BankQuestion>,
) {
    fun inGrade(g: Int) = g in gradeLo..gradeHi
}

/** Question.swift — what the runner shows. `id` mirrors the iOS per-instance UUID. */
data class Question(
    val topic: Topic,
    val prompt: String,
    val options: List<String>,
    val correctIndex: Int,
    /** What to read aloud for visual (pre-reader) prompts; null → the prompt itself. */
    val spoken: String? = null,
    /** 📖 The passage this question is about, rendered above the prompt. */
    val passage: String? = null,
    /** SkillCatalog tag for the parent report; null = untagged. */
    val skill: String? = null,
    val id: String = UUID.randomUUID().toString(),
) {
    val correctAnswer: String get() = options[correctIndex]
    val readAloudText: String get() = spoken ?: prompt

    /** Dedup key matching QuestionMemory's (QuestionRunnerView.sessionKey). */
    val sessionKey: String get() = "$prompt|${options.getOrElse(correctIndex) { "" }}"

    /**
     * Question.isSelfContainedPrompt — false for passage questions and the
     * group-less "מי לא שייך" family (they need the full option set).
     */
    val isSelfContainedPrompt: Boolean
        get() {
            if (passage != null) return false
            val p = stripNiqqud(prompt)
            return !(p.contains("לא שיך") || p.contains("לא שייך"))
        }

    companion object {
        fun stripNiqqud(s: String): String =
            s.filterNot { it.code in 0x0591..0x05C7 }
    }
}

fun difficultyOf(raw: String?): Difficulty? = Difficulty.of(raw)
