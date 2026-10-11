package com.rani.tofy.ui.theme

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.google.firebase.firestore.Blob
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.DeviceRole
import com.rani.tofy.R
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * 🎨 A built-in backdrop — Backdrop.swift, one to one (same ids, same colours:
 * a child's pick travels between an iPhone and an Android by its id). Free,
 * every one of them. The one rule of the list: every gradient stop keeps at
 * least 3:1 contrast with white (BackdropTests on iOS enforces it).
 */
data class BackdropTheme(
    val id: String,
    val colors: List<Long>,
    val orbTop: Long,
    val orbBottom: Long,
    val orbOpacity: Float = 0.8f,
) {
    /** Pointed, as a child reads it; a parent's screen strips the points. Capitalised: it is a NAME. */
    val displayName: String
        get() = when (id) {
            "sunset" -> tr("שְׁקִיעָה"); "sea" -> tr("יָם"); "forest" -> tr("יַעַר"); "candy" -> tr("סֻכָּרִיָּה")
            "rainbow" -> tr("קֶשֶׁת"); "fire" -> tr("אֵשׁ"); "ice" -> tr("קֶרַח"); "grape" -> tr("עֲנָבִים")
            "mint" -> tr("מִנְתָּה"); "berry" -> tr("תּוּת"); "space" -> tr("חָלָל"); "night" -> tr("לַיְלָה")
            "calm" -> tr("רָגוּעַ"); "dark" -> tr("כֵּהֶה"); else -> tr("טוֹפִי")
        }.replaceFirstChar { it.uppercase() }

    companion object {
        /** The child's own photo (BackdropStore), stored under this id. */
        const val PHOTO = "photo"
        val tofy = BackdropTheme("tofy", listOf(0xFF7A5CFF, 0xFF5E60CE, 0xFF3E8BF0), 0xFFFF7BD3, 0xFF37E2D5)
        val all = listOf(
            tofy,
            BackdropTheme("sunset", listOf(0xFFF0683F, 0xFFD63A78, 0xFF6A35B5), 0xFFFFC857, 0xFFFF5FA8, 0.7f),
            BackdropTheme("sea", listOf(0xFF0E8FA8, 0xFF1565C0, 0xFF1B3FA0), 0xFF37E2D5, 0xFF6EC6FF, 0.7f),
            BackdropTheme("forest", listOf(0xFF1F9A63, 0xFF14746F, 0xFF0F4C75), 0xFFA8E063, 0xFF37E2D5, 0.6f),
            BackdropTheme("candy", listOf(0xFFF04FA0, 0xFFB14CE0, 0xFF6C5CE7), 0xFFFFD166, 0xFFFF8FB1, 0.7f),
            BackdropTheme("rainbow", listOf(0xFFE0457B, 0xFF7A5CFF, 0xFF1FA2A8), 0xFFFFC857, 0xFF37E2D5, 0.7f),
            BackdropTheme("fire", listOf(0xFFD9480F, 0xFFB3261E, 0xFF7A1F3D), 0xFFFFB703, 0xFFFF5E62, 0.6f),
            BackdropTheme("ice", listOf(0xFF2390C8, 0xFF2374C6, 0xFF274690), 0xFFA5F3FC, 0xFF7DD3FC, 0.6f),
            BackdropTheme("grape", listOf(0xFF7B2CBF, 0xFF5A189A, 0xFF3C096C), 0xFFE0AAFF, 0xFFFF6AD5, 0.6f),
            BackdropTheme("mint", listOf(0xFF12A594, 0xFF0E8C8C, 0xFF145C7A), 0xFFB8F2A8, 0xFF7FE7DC, 0.6f),
            BackdropTheme("berry", listOf(0xFFD6336C, 0xFFA61E4D, 0xFF5F1A4B), 0xFFFF8FAB, 0xFFF783AC, 0.6f),
            BackdropTheme("space", listOf(0xFF2A1B7A, 0xFF1B1464, 0xFF0B1026), 0xFF7A5CFF, 0xFF3E8BF0, 0.55f),
            BackdropTheme("night", listOf(0xFF123A7A, 0xFF132048, 0xFF0A1128), 0xFF4C6FFF, 0xFF37E2D5, 0.4f),
            BackdropTheme("calm", listOf(0xFF33405A, 0xFF283349, 0xFF1C2433), 0xFF5B7BB5, 0xFF3E8BF0, 0.28f),
            BackdropTheme("dark", listOf(0xFF1B1D24, 0xFF14161B, 0xFF0D0E12), 0xFF3A3F52, 0xFF2A2E3D, 0.35f),
        )
        fun find(id: String?) = all.firstOrNull { it.id == id } ?: tofy
    }

    val gradient: List<Color> get() = colors.map { Color(it) }
}

/**
 * 🖼 A built-in PICTURE backdrop — BackdropPicture in Backdrop.swift (same ids).
 * An illustrated scene bundled with the app, free; chosen and stored like a
 * colour backdrop, by its id ("pic-…": a build that does not know it falls
 * back to the default colours), and drawn like a photo of their own.
 */
data class BackdropPicture(val id: String, val full: Int, val wide: Int, val thumb: Int) {
    // `wide`: the same scene drawn wide, for a screen on its side — the tall one would show only its middle band there.
    /** Pointed, as a child reads it; a parent's screen strips the points. Capitalised: it is a NAME. */
    val displayName: String
        get() = when (id) {
            "pic-ocean" -> tr("מִתַּחַת לַמַּיִם"); "pic-forest" -> tr("יַעַר קָסוּם"); "pic-balloons" -> tr("כַּדּוּרִים פּוֹרְחִים")
            "pic-dino" -> tr("דִּינוֹזָאוּרִים"); "pic-candy" -> tr("מַמְתַּקִּים"); "pic-castle" -> tr("טִירָה")
            "pic-stadium" -> tr("אִצְטַדְיוֹן"); "pic-space" -> tr("חָלָל"); else -> tr("הַקֹּטֶב")
        }.replaceFirstChar { it.uppercase() }

    companion object {
        val all = listOf(
            BackdropPicture("pic-ocean", R.drawable.backdrop_pic_ocean, R.drawable.backdrop_pic_ocean_wide, R.drawable.backdrop_pic_ocean_thumb),
            BackdropPicture("pic-forest", R.drawable.backdrop_pic_forest, R.drawable.backdrop_pic_forest_wide, R.drawable.backdrop_pic_forest_thumb),
            BackdropPicture("pic-balloons", R.drawable.backdrop_pic_balloons, R.drawable.backdrop_pic_balloons_wide, R.drawable.backdrop_pic_balloons_thumb),
            BackdropPicture("pic-dino", R.drawable.backdrop_pic_dino, R.drawable.backdrop_pic_dino_wide, R.drawable.backdrop_pic_dino_thumb),
            BackdropPicture("pic-candy", R.drawable.backdrop_pic_candy, R.drawable.backdrop_pic_candy_wide, R.drawable.backdrop_pic_candy_thumb),
            BackdropPicture("pic-castle", R.drawable.backdrop_pic_castle, R.drawable.backdrop_pic_castle_wide, R.drawable.backdrop_pic_castle_thumb),
            BackdropPicture("pic-stadium", R.drawable.backdrop_pic_stadium, R.drawable.backdrop_pic_stadium_wide, R.drawable.backdrop_pic_stadium_thumb),
            BackdropPicture("pic-space", R.drawable.backdrop_pic_space, R.drawable.backdrop_pic_space_wide, R.drawable.backdrop_pic_space_thumb),
            BackdropPicture("pic-arctic", R.drawable.backdrop_pic_arctic, R.drawable.backdrop_pic_arctic_wide, R.drawable.backdrop_pic_arctic_thumb),
        )
        fun find(id: String?) = all.firstOrNull { it.id == id }
    }
}

/**
 * 🎨 Which backdrop this phone draws right now, and the photos behind it
 * (BackdropStore in Backdrop.swift).
 *
 * A CHILD's choice lives on the child doc (`backdropID` + `backdropUpdatedAt`,
 * epoch seconds; the fresher pick wins on iOS) so it follows them to every
 * device; a photo of their own sits in `children/{id}/backdrop/photo`
 * ({data: Blob, updatedAt}) and each device keeps a copy. The PARENT's choice
 * is this phone's own, and a parent's photo never leaves the phone.
 */
object BackdropStore {
    const val PARENT = "parent"
    private var prefs: SharedPreferences? = null
    private var dir: File? = null

    var parentID by mutableStateOf<String?>(null); private set
    /** Bumped when a photo file changed (picked here, or arrived from the cloud). */
    var photoRevision by mutableIntStateOf(0); private set
    /** A pick made here, shown at once — until the child doc echoes it back. */
    var pendingChildID by mutableStateOf<Pair<String, String>?>(null); private set
    private val photos = HashMap<String, ImageBitmap?>()
    private val fetching = HashSet<String>()

    fun init(ctx: Context) {
        prefs = ctx.applicationContext.getSharedPreferences("tofy.backdrop", Context.MODE_PRIVATE)
        dir = File(ctx.applicationContext.filesDir, "backdrops")
        res = ctx.applicationContext.resources
        parentID = prefs?.getString(PARENT, null)
    }

    /** Whose screens these are: the child playing here (their own device, or Kid Mode) — else the parent. */
    val ownerKey: String
        get() = DeviceRole.kidModeChildID
            ?: (if (DeviceRole.role == DeviceRole.Role.CHILD) DeviceRole.joinedChildID else null)
            ?: PARENT

    private fun file(key: String) = File(dir, "$key.jpg")
    private fun stamp(key: String) = java.lang.Double.longBitsToDouble(prefs?.getLong("stamp.$key", 0L) ?: 0L)
    private fun setStamp(key: String, v: Double) { prefs?.edit()?.putLong("stamp.$key", java.lang.Double.doubleToRawLongBits(v))?.apply() }

    fun photo(key: String): ImageBitmap? {
        if (photos.containsKey(key)) return photos[key]
        val f = file(key)
        val bmp = if (dir != null && f.exists()) runCatching { BitmapFactory.decodeFile(f.path)?.asImageBitmap() }.getOrNull() else null
        photos[key] = bmp
        return bmp
    }

    private var res: android.content.res.Resources? = null
    private val pictures = object : LinkedHashMap<String, ImageBitmap>(4, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, ImageBitmap>?) = size > 2
    }

    /**
     * A built-in picture, full size. Only the last two are kept (the screen's
     * own, and a child's while a parent picks for them) — nine of them decoded
     * would not fit in memory.
     */
    fun picture(p: BackdropPicture, wide: Boolean): ImageBitmap? {
        val key = if (wide) p.id + "/wide" else p.id
        pictures[key]?.let { return it }
        val r = res ?: return null
        val bmp = runCatching { BitmapFactory.decodeResource(r, if (wide) p.wide else p.full)?.asImageBitmap() }.getOrNull() ?: return null
        pictures[key] = bmp
        return bmp
    }

    /** The parent picks a built-in backdrop, or goes back to the photo already on this phone. */
    fun chooseForParent(id: String) {
        parentID = id
        prefs?.edit()?.putString(PARENT, id)?.apply()
    }

    fun childPicked(childID: String, id: String) { pendingChildID = childID to id }
    fun childEchoed(childID: String, id: String?) { if (pendingChildID == (childID to id)) pendingChildID = null }

    /** Small enough for one Firestore document and for a full-screen draw: ≤1400 px, under ~600 KB. */
    fun compress(src: Bitmap): ByteArray? = runCatching {
        val scale = minOf(1f, 1400f / maxOf(src.width, src.height).toFloat())
        val bmp = if (scale < 1f) Bitmap.createScaledBitmap(src, (src.width * scale).toInt().coerceAtLeast(1), (src.height * scale).toInt().coerceAtLeast(1), true) else src
        var quality = 70
        var out: ByteArray
        do {
            out = ByteArrayOutputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, quality, it); it.toByteArray() }
            quality -= 10
        } while (out.size > 600_000 && quality >= 30)
        out
    }.getOrNull()

    /** A new photo: keep a copy here; returns its stamp (epoch seconds), or null when it could not be saved. */
    suspend fun savePhoto(key: String, jpeg: ByteArray): Double? = withContext(Dispatchers.IO) {
        runCatching {
            dir?.mkdirs()
            file(key).writeBytes(jpeg)
            val now = System.currentTimeMillis() / 1000.0
            setStamp(key, now)
            photos[key] = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)?.asImageBitmap()
            now
        }.getOrNull()
    }.also { if (it != null) photoRevision++ }

    /** …and send a CHILD's photo to their other devices. */
    suspend fun upload(childID: String, jpeg: ByteArray, stamp: Double) {
        runCatching {
            FirebaseFirestore.getInstance().collection("children").document(childID)
                .collection("backdrop").document("photo")
                .set(mapOf("data" to Blob.fromBytes(jpeg), "updatedAt" to stamp)).await()
        }
    }

    /** The child chose a photo on ANOTHER device, newer than the copy here (or there is none) → bring it. */
    suspend fun fetchPhotoIfNeeded(childID: String, wanted: Double) {
        val have = stamp(childID)
        if ((photo(childID) != null && have + 1 >= wanted) || !fetching.add(childID)) return
        try {
            val doc = runCatching {
                FirebaseFirestore.getInstance().collection("children").document(childID)
                    .collection("backdrop").document("photo").get().await()
            }.getOrNull() ?: return
            val bytes = doc.getBlob("data")?.toBytes() ?: return
            val at = (doc.get("updatedAt") as? Number)?.toDouble() ?: wanted
            if (at + 1 < have) return                      // never an older picture over a newer one
            withContext(Dispatchers.IO) {
                runCatching {
                    dir?.mkdirs(); file(childID).writeBytes(bytes)
                    photos[childID] = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
                    setStamp(childID, at)
                }
            }
            photoRevision++
        } finally { fetching.remove(childID) }
    }
}
