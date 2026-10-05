package com.rani.tofy.kid.content

import java.io.File

/** Reads the real exported assets straight from the source tree (unit tests run in app/). */
object ContentTestSupport {
    val assetsDir: File by lazy {
        listOf("src/main/assets", "app/src/main/assets").map(::File).first { File(it, "content/manifest.json").exists() }
    }

    val loader: (String) -> String? = { path -> File(assetsDir, "content/$path").takeIf { it.exists() }?.readText() }

    fun install(seed: Int = 1, prefs: ContentPrefs = MemoryContentPrefs()) {
        RemoteQuestionBank.replaceForTest(emptyMap())
        QuestionSource.initForTest(loader, prefs, kotlin.random.Random(seed))
        QuestionPacks.forceCloudSwitch = true
        QuestionPacks.setLiveForTest(emptySet())
    }
}
