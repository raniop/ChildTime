package com.rani.tofy.i18n

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject
import java.util.Locale

/** עברית / English / Русский / العربية — same set and codes as AppLanguage.swift. */
enum class AppLanguage(val code: String, val native: String, val rtl: Boolean) {
    HE("he", "עברית", true), EN("en", "English", false), RU("ru", "Русский", false), AR("ar", "العربية", true);

    companion object {
        fun of(code: String?) = entries.firstOrNull { it.code == code }
        fun system(): AppLanguage = when (Locale.getDefault().language) {
            "iw", "he" -> HE; "ru" -> RU; "ar" -> AR; "en" -> EN; else -> HE
        }
    }
}

/**
 * tr() keyed by the Hebrew source string — the iOS catalog exported by
 * tools/android-strings.py. Placeholders are the catalog's own (%@, %lld,
 * %1$@ …); a missing translation falls back to the Hebrew key, like iOS.
 */
object I18n {
    var language by mutableStateOf(AppLanguage.HE)
        private set
    private var table: Map<String, Any> = emptyMap()
    private lateinit var app: Context

    fun init(context: Context) {
        app = context.applicationContext
        val saved = app.getSharedPreferences("tofy", Context.MODE_PRIVATE).getString("language", null)
        set(AppLanguage.of(saved) ?: AppLanguage.system(), persist = false)
    }

    fun set(lang: AppLanguage, persist: Boolean = true) {
        table = load(lang.code)
        language = lang
        if (persist) app.getSharedPreferences("tofy", Context.MODE_PRIVATE).edit().putString("language", lang.code).apply()
    }

    private fun load(code: String): Map<String, Any> = runCatching {
        val json = JSONObject(app.assets.open("i18n/$code.json").bufferedReader().use { it.readText() })
        buildMap {
            for (k in json.keys()) {
                when (val v = json.get(k)) {
                    is String -> put(k, v)
                    is JSONObject -> put(k, v.keys().asSequence().associateWith { v.getString(it) })
                }
            }
        }
    }.getOrDefault(emptyMap())

    fun tr(key: String, vararg args: Any): String {
        val entry = table[key]
        val template = when (entry) {
            is String -> entry
            is Map<*, *> -> {
                val n = args.firstOrNull { it is Number } as? Number
                val form = pluralForm(language.code, n?.toLong() ?: 0)
                (entry[form] ?: entry["other"]) as? String ?: key
            }
            else -> key
        }
        return format(template, args)
    }

    private val placeholder = Regex("%(?:(\\d+)\\$)?(@|lld|ld|d|lf|f|\\.\\d+f|#@[^@]+@)")

    private fun format(t: String, args: Array<out Any>): String {
        if (args.isEmpty()) return t.replace("%%", "%")
        var next = 0
        return placeholder.replace(t) { m ->
            val idx = m.groupValues[1].takeIf { it.isNotEmpty() }?.toInt()?.minus(1) ?: next++
            val a = args.getOrNull(idx) ?: return@replace ""
            val spec = m.groupValues[2]
            if (spec.endsWith("f") && a is Number) String.format(Locale.US, "%" + spec.removePrefix("l"), a.toDouble()) else a.toString()
        }.replace("%%", "%")
    }

    /** CLDR cardinal rules for the four languages. */
    private fun pluralForm(lang: String, n: Long): String = when (lang) {
        "ru" -> { val m10 = n % 10; val m100 = n % 100
            when { m10 == 1L && m100 != 11L -> "one"; m10 in 2..4 && m100 !in 12..14 -> "few"; else -> "many" } }
        "ar" -> { val m100 = n % 100
            when { n == 0L -> "zero"; n == 1L -> "one"; n == 2L -> "two"; m100 in 3..10 -> "few"; m100 in 11..99 -> "many"; else -> "other" } }
        "he" -> when (n) { 1L -> "one"; 2L -> "two"; else -> "other" }
        else -> if (n == 1L) "one" else "other"
    }
}

fun tr(key: String, vararg args: Any): String = I18n.tr(key, *args)
