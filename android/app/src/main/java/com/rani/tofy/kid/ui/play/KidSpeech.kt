package com.rani.tofy.kid.ui.play

import android.content.Context
import android.speech.tts.TextToSpeech
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.tr
import java.util.Locale

/**
 * SpeechReader.swift — reads questions & answers aloud in the CONTENT language.
 * One shared engine so a new tap cancels the previous utterance instead of
 * stacking voices. The engine starts asynchronously (like iOS resolving its
 * voice off the main thread); a line asked for before it's ready is spoken
 * the moment it is.
 */
object KidSpeech {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: Pair<String, AppLanguage>? = null

    fun init(context: Context) {
        if (tts != null) return
        tts = TextToSpeech(context.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                tts?.setSpeechRate(0.9f)   // a touch slower for kids
                tts?.setPitch(1.05f)
                pending?.let { (t, l) -> pending = null; utter(t, l) }
            }
        }
    }

    fun speak(text: String, lang: AppLanguage) {
        val clean = cleanForSpeech(text)
        if (clean.isEmpty()) return
        if (!ready) { pending = clean to lang; return }
        utter(clean, lang)
    }

    private fun utter(text: String, lang: AppLanguage) {
        val t = tts ?: return
        val locale = when (lang) {
            AppLanguage.HE -> Locale("he", "IL")
            AppLanguage.EN -> Locale.US
            AppLanguage.RU -> Locale("ru", "RU")
            AppLanguage.AR -> Locale("ar")
        }
        val r = t.setLanguage(locale)
        // Some engines still only know Hebrew under its legacy "iw" code.
        if (lang == AppLanguage.HE && (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED)) t.setLanguage(Locale("iw", "IL"))
        t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tofy.read")
    }

    /** Question, then each answer — number first ("מִסְפָּר 1. קָטָן"), or by order when every answer is a number. */
    fun readQuestion(prompt: String, options: List<String>, lang: AppLanguage) = speak(spokenScript(prompt, options), lang)

    fun stop() { pending = null; tts?.stop() }

    private val ordinals: List<String>
        get() = listOf(tr("רִאשׁוֹנָה"), tr("שְׁנִיָּה"), tr("שְׁלִישִׁית"), tr("רְבִיעִית"), tr("חֲמִישִׁית"), tr("שִׁשִּׁית"))

    fun spokenScript(prompt: String, options: List<String>): String {
        val numeric = options.isNotEmpty() && options.all { it.trim().toIntOrNull() != null }
        val parts = mutableListOf(prompt)
        options.forEachIndexed { i, opt ->
            parts += if (numeric) tr("תְּשׁוּבָה %@", ordinals[minOf(i, ordinals.size - 1)]) else tr("מִסְפָּר %lld", i + 1)
            parts += opt
        }
        return parts.joined()
    }

    private fun List<String>.joined() = joinToString(". ")

    /**
     * Math symbols → words (−/×/÷/= are otherwise silent), emoji dropped (the
     * voice reads their names), geresh / quote marks removed.
     */
    fun cleanForSpeech(raw: String): String {
        var m = raw
        m = m.replace("= ?", " ${tr("כַּמָּה זֶה")} ")
        m = m.replace("=?", " ${tr("כַּמָּה זֶה")} ")
        m = m.replace("+", " ${tr("וְעוֹד")} ")
        m = m.replace("−", " ${tr("פָּחוֹת")} ")
        m = m.replace("×", " ${tr("כָּפוּל")} ")
        m = m.replace("÷", " ${tr("חֶלְקֵי")} ")
        m = m.replace("=", " ${tr("שָׁוֶה")} ")
        val sb = StringBuilder()
        var i = 0
        while (i < m.length) {
            val cp = m.codePointAt(i)
            val drop = cp in 0x1F000..0x1FAFF || cp in 0x2600..0x27BF || cp in 0x2B00..0x2BFF ||
                cp in 0x2190..0x21FF || cp in 0x2300..0x23FF || cp in 0xFE00..0xFE0F || cp == 0x200D
            if (!drop) sb.appendCodePoint(cp)
            i += Character.charCount(cp)
        }
        val junk = setOf('\'', '‘', '’', '׳', '"', '“', '”', '„', '״', '«', '»', '`', '´')
        return sb.filterNot { it in junk }.split(' ', '\n', '\t').filter { it.isNotEmpty() }.joinToString(" ").trim()
    }
}
