package com.rani.tofy.ui.location

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import android.location.Geocoder
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.rani.tofy.data.Child
import com.rani.tofy.data.FamilyPlace
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.PlaceAlert
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.PageBar
import com.rani.tofy.ui.common.ChildAvatar
import com.rani.tofy.ui.home.stripNiqqud
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import java.util.Locale

private val Mint = Color(0xFF06D6A0)
private val Pink = Color(0xFFFF5FA8)
private val Orange = Color(0xFFFFA53A)

// MARK: - The map (OpenStreetMap)

private data class MapKid(val id: String, val initial: String, val girl: Boolean, val lat: Double, val lng: Double)

/** A white dot with the place's emoji, or a coloured disc with the child's initial. */
private fun dotIcon(ctx: Context, text: String, fill: Int, textColor: Int, sizeDp: Int): BitmapDrawable {
    val d = ctx.resources.displayMetrics.density
    val px = (sizeDp * d).toInt()
    val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val p = Paint(Paint.ANTI_ALIAS_FLAG)
    p.color = 0x33000000; c.drawCircle(px / 2f, px / 2f + 1.5f * d, px / 2f - 1.5f * d, p)
    p.color = fill; c.drawCircle(px / 2f, px / 2f, px / 2f - 2 * d, p)
    p.color = 0xFFFFFFFF.toInt(); p.style = Paint.Style.STROKE; p.strokeWidth = 2.5f * d
    if (fill != 0xFFFFFFFF.toInt()) c.drawCircle(px / 2f, px / 2f, px / 2f - 2.5f * d, p)
    p.style = Paint.Style.FILL; p.color = textColor; p.textAlign = Paint.Align.CENTER
    p.textSize = px * 0.5f; p.isFakeBoldText = true
    val fm = p.fontMetrics
    c.drawText(text, px / 2f, px / 2f - (fm.ascent + fm.descent) / 2, p)
    return BitmapDrawable(ctx.resources, bmp)
}

@Composable
private fun FamilyMap(kids: List<MapKid>, places: List<FamilyPlace>, modifier: Modifier, center: GeoPoint? = null,
                      zoom: Double = 15.5, onCenter: ((GeoPoint) -> Unit)? = null) {
    val ctx = LocalContext.current
    var fitted by remember { mutableStateOf("") }
    AndroidView(modifier = modifier, factory = { c ->
        MapView(c).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
            controller.setZoom(zoom)
            if (onCenter != null) addMapListener(object : org.osmdroid.events.MapListener {
                override fun onScroll(e: org.osmdroid.events.ScrollEvent?): Boolean { onCenter(mapCenter as GeoPoint); return true }
                override fun onZoom(e: org.osmdroid.events.ZoomEvent?): Boolean { onCenter(mapCenter as GeoPoint); return true }
            })
        }
    }, update = { map ->
        map.overlays.clear()
        for (p in places) {
            val circle = Polygon(map)
            circle.points = Polygon.pointsAsCircle(GeoPoint(p.lat, p.lng), p.radius)
            circle.fillPaint.color = 0x297B5CFA; circle.outlinePaint.color = 0xB37B5CFA.toInt(); circle.outlinePaint.strokeWidth = 4f
            circle.setOnClickListener { _, _, _ -> false }
            map.overlays.add(circle)
            if (onCenter == null) map.overlays.add(Marker(map).apply {
                position = GeoPoint(p.lat, p.lng); setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                icon = dotIcon(ctx, p.emoji, 0xFFFFFFFF.toInt(), 0xFF000000.toInt(), 28); title = p.name
            })
        }
        for (k in kids) map.overlays.add(Marker(map).apply {
            position = GeoPoint(k.lat, k.lng); setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
            icon = dotIcon(ctx, k.initial, if (k.girl) 0xFFFF5FA8.toInt() else 0xFF06B48A.toInt(), 0xFFFFFFFF.toInt(), 40)
        })
        val key = (kids.map { "${it.lat},${it.lng}" } + places.map { "${it.lat},${it.lng}" } + listOf("$center")).joinToString("|")
        if (key != fitted) {
            fitted = key
            if (center != null) map.controller.setCenter(center)
            else {
                val pts = kids.map { GeoPoint(it.lat, it.lng) } + places.map { GeoPoint(it.lat, it.lng) }
                when {
                    pts.size == 1 -> { map.controller.setZoom(15.5); map.controller.setCenter(pts[0]) }
                    pts.size > 1 -> map.post { runCatching { map.zoomToBoundingBox(BoundingBox.fromGeoPoints(pts).increaseByScale(1.6f), false) } }
                }
            }
        }
        map.invalidate()
    })
}

// MARK: - Parent: איפה הילדים

@Composable
fun ParentLocationScreen(focusChildID: String?, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val state by FamilyRepository.state.collectAsState()
    val fixes by LocationRepository.fixes.collectAsState()
    val beeps by LocationRepository.beeps.collectAsState()
    val addresses by LocationRepository.addresses.collectAsState()
    val kids = state.orderedChildren
    val places = state.household?.places ?: emptyList()
    var page by remember { mutableStateOf("map") }
    var consentFor by remember { mutableStateOf<Child?>(null) }
    var editing by remember { mutableStateOf<FamilyPlace?>(null) }
    val picked = remember { mutableStateMapOf<String, String>() }
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        LocationRepository.follow(kids.map { it.id })
        LocationRepository.refresh(kids.filter { LocationRepository.sharingOn(it) }.map { it.id })
        while (true) { delay(5000); tick++ }
    }
    @Suppress("UNUSED_EXPRESSION") tick; @Suppress("UNUSED_EXPRESSION") fixes; @Suppress("UNUSED_EXPRESSION") addresses

    BackHandler { when { editing != null -> editing = null; consentFor != null -> consentFor = null; page != "map" -> page = "map"; else -> onBack() } }
    editing?.let { p -> PlaceEditor(p, kids, places, onDone = { editing = null }); return }
    consentFor?.let { c -> ConsentPage(c, onDone = { consentFor = null }); return }
    if (page == "places") { PlacesPage(kids, places, onEdit = { editing = it }, onNew = { editing = newPlace(kids, places) }, onBack = { page = "map" }); return }

    val mapKids = kids.mapNotNull { c ->
        LocationRepository.shownFix(c, picked[c.id])?.let { f -> MapKid(c.id, stripNiqqud(c.name).take(1), c.isGirl, f.lat!!, f.lng!!) }
    }
    val focus = focusChildID?.let { id -> mapKids.firstOrNull { it.id == id } }?.let { GeoPoint(it.lat, it.lng) }

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            PageBar(tr("איפה הילדים"), onBack) {
                Text(tr("📍 מקומות"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp,
                    modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.22f))
                        .clickable { page = "places" }.padding(horizontal = 14.dp, vertical = 9.dp))
            }
            FamilyMap(mapKids, places, Modifier.fillMaxWidth().height(320.dp).clip(RoundedCornerShape(24.dp))
                .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(24.dp)), center = focus)
            for (c in kids) KidCard(ctx, c, places, picked, beeps[c.id]) { consentFor = c }
        }
    }
}

@Composable
private fun KidCard(ctx: Context, c: Child, places: List<FamilyPlace>, picked: MutableMap<String, String>,
                    beep: LocationRepository.Beep?, onConsent: () -> Unit) {
    val name = stripNiqqud(c.name)
    val sharing = LocationRepository.sharingOn(c)
    val all = (LocationRepository.fixes.value[c.id] ?: emptyList())
    val devices = all.filter { it.hasFix }
    val current = LocationRepository.shownFix(c, picked[c.id])
    val now = System.currentTimeMillis() / 1000.0
    val status = when {
        !sharing -> tr("המיקום כבוי")
        beep?.found != null && now - beep.found < 120 -> if (c.isGirl) tr("✅ %@ מצאה את הטלפון", name) else tr("✅ %@ מצא את הטלפון", name)
        current == null && all.any { it.permission == "denied" } -> tr("המיקום חסום בטלפון של %@ — מאשרים בהגדרות של הטלפון ← טופי ← מיקום", name)
        current == null -> tr("מחכה לאישור בטלפון של %@ — פותחים בו את טופי", name)
        else -> LocationRepository.whereLine(ctx, current, places)
    }
    Column(Modifier.fillMaxWidth().glassPane(22.dp, 0.16f, shadow = false).padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ChildAvatar(c, 48.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    Text(name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp)
                    if (current != null) {
                        Box(Modifier.size(4.dp).clip(CircleShape).background(Ink.secondary))
                        Text(LocationRepository.relative(current.at), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.5.sp,
                            color = if (now - current.at < 600) Color(0xFF9FF5DD) else Ink.secondary)
                    }
                }
                Text(status, color = Ink.secondary, fontFamily = Rounded, fontSize = 13.5.sp)
            }
            if (devices.size < 2) current?.battery?.let {
                Text("🔋 ${(it * 100).toInt()}%", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp,
                    modifier = Modifier.clip(RoundedCornerShape(12.dp)).background(Color.Black.copy(alpha = 0.18f)).padding(horizontal = 10.dp, vertical = 4.dp))
            }
        }
        if (current?.permission == "whenInUse") Text(tr("כדי לקבל התראות הגעה: בטלפון של %@ ← הגדרות ← טופי ← מיקום ← תמיד", name),
            color = Color(0xFFFFE58A), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.5.sp)
        if (devices.size > 1 && current != null) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (f in devices) {
                val on = f.deviceID == current.deviceID
                val label = LocationRepository.deviceName(f.kind) + (f.battery?.let { " · 🔋 ${(it * 100).toInt()}%" } ?: "")
                Text(label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, textAlign = TextAlign.Center,
                    maxLines = 1, modifier = Modifier.weight(1f).clip(RoundedCornerShape(12.dp))
                        .background(if (on) Color.White.copy(alpha = 0.32f) else Color.Black.copy(alpha = 0.14f))
                        .border(1.5.dp, if (on) Color.White.copy(alpha = 0.7f) else Color.Transparent, RoundedCornerShape(12.dp))
                        .clickable { picked[c.id] = f.deviceID }.padding(vertical = 10.dp))
            }
        }
        if (sharing) Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val ringing = beep != null && !beep.stop && beep.found == null && now - beep.at < 35
            Text(if (ringing) tr("⏹ עצירת הצפצוף") else tr("🔔 צפצוף"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black,
                fontSize = 16.sp, textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).background(Brush.horizontalGradient(listOf(Pink, Orange)))
                    .clickable { LocationRepository.beep(c.id, if (devices.size > 1) current?.deviceID else null, stop = ringing) }
                    .padding(vertical = 14.dp))
            Text(tr("↻ רענון"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.18f))
                    .clickable { LocationRepository.refresh(listOf(c.id)) }.padding(vertical = 14.dp))
        } else Text(tr("📍 הפעלת מיקום ל%@", name), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 16.sp,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.22f))
                .clickable(onClick = onConsent).padding(vertical = 14.dp))
    }
}

// MARK: - Consent

@Composable
private fun ConsentPage(c: Child, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var saving by remember { mutableStateOf(false) }
    val name = stripNiqqud(c.name)
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            PageBar("", onDone)
            Text("📍", fontSize = 44.sp)
            Text(tr("לדעת איפה %@ — בלי לשאול", name), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black,
                fontSize = 22.sp, textAlign = TextAlign.Center)
            Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.16f, shadow = false).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf(
                    "🗺️" to (if (c.isGirl) tr("מה נשמר: המיקום האחרון של הטלפון שלה, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום.")
                             else tr("מה נשמר: המיקום האחרון של הטלפון שלו, והגעה או יציאה מהמקומות שסימנתם. לא מסלול של כל היום.")),
                    "👪" to tr("מי רואה: רק ההורים במשפחה. שום דבר לא עובר לאף גורם אחר."),
                    "🗑️" to tr("כיבוי: מוחק מיד את המיקום השמור."),
                    "🔋" to tr("סוללה: מתעדכן כשהטלפון זז או כשמבקשים — בלי GPS שרץ כל הזמן."),
                ).forEach { (e, t) ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(e, fontSize = 20.sp); Text(t, color = Color.White, fontFamily = Rounded, fontSize = 14.5.sp)
                    }
                }
            }
            Text(if (c.isGirl) tr("בטלפון של %@ יופיע אישור מיקום, והיא תדע שהמיקום שלה גלוי לכם.", name)
                 else tr("בטלפון של %@ יופיע אישור מיקום, והוא ידע שהמיקום שלו גלוי לכם.", name),
                color = Ink.secondary, fontFamily = Rounded, fontSize = 13.sp)
            Text(tr("אישור והפעלת מיקום"), color = Color(0xFF4B3BC4), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp,
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Color.White)
                    .clickable(enabled = !saving) {
                        saving = true
                        scope.launch { LocationRepository.setSharing(c.id, true); saving = false; onDone() }
                    }.padding(vertical = 16.dp))
        }
    }
}

// MARK: - Places

private fun newPlace(kids: List<Child>, places: List<FamilyPlace>): FamilyPlace {
    val fix = kids.firstNotNullOfOrNull { LocationRepository.shownFix(it) }
    return FamilyPlace(name = "", emoji = "🏠", lat = fix?.lat ?: places.firstOrNull()?.lat ?: 32.0853,
        lng = fix?.lng ?: places.firstOrNull()?.lng ?: 34.7818, alerts = kids.associate { it.id to PlaceAlert(true, false) })
}

@Composable
private fun PlacesPage(kids: List<Child>, places: List<FamilyPlace>, onEdit: (FamilyPlace) -> Unit, onNew: () -> Unit, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var confirmStop by remember { mutableStateOf<Child?>(null) }
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            PageBar(tr("📍 מקומות"), onBack)
            Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.16f, shadow = false).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(tr("מקומות קבועים"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                if (places.isEmpty()) Text(tr("עוד אין מקומות. הוסיפו את הבית ואת בית הספר, ותקבלו התראה כשהילדים מגיעים ויוצאים."),
                    color = Ink.secondary, fontFamily = Rounded, fontSize = 14.5.sp)
                for (p in places) Row(Modifier.fillMaxWidth().clickable { onEdit(p) }.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(p.emoji, fontSize = 22.sp)
                    Text(p.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Text(tr("%lld מ׳", p.radius.toLong()), color = Ink.secondary, fontFamily = Rounded, fontSize = 13.sp)
                }
                Text(tr("＋ הוספת מקום"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 16.sp,
                    modifier = Modifier.clickable(onClick = onNew).padding(vertical = 8.dp))
            }
            val sharingKids = kids.filter { LocationRepository.sharingOn(it) }
            if (sharingKids.isNotEmpty()) Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.16f, shadow = false).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(tr("שיתוף מיקום"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                for (c in sharingKids) Text(tr("כיבוי המיקום של %@", stripNiqqud(c.name)), color = Color(0xFFFFB4C8), fontFamily = Rounded,
                    fontWeight = FontWeight.Bold, fontSize = 15.sp, modifier = Modifier.clickable { confirmStop = c }.padding(vertical = 6.dp))
            }
        }
    }
    confirmStop?.let { c ->
        androidx.compose.material3.AlertDialog(onDismissRequest = { confirmStop = null },
            text = { Text(tr("לכבות את שיתוף המיקום? המיקום השמור יימחק.")) },
            confirmButton = { androidx.compose.material3.TextButton({ scope.launch { LocationRepository.setSharing(c.id, false) }; confirmStop = null }) { Text(tr("כיבוי המיקום")) } },
            dismissButton = { androidx.compose.material3.TextButton({ confirmStop = null }) { Text(tr("ביטול")) } })
    }
}

@Composable
private fun PlaceEditor(start: FamilyPlace, kids: List<Child>, places: List<FamilyPlace>, onDone: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var place by remember { mutableStateOf(start) }
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<android.location.Address>>(emptyList()) }
    var center by remember { mutableStateOf(GeoPoint(start.lat, start.lng)) }
    var saving by remember { mutableStateOf(false) }
    val isNew = places.none { it.id == start.id }
    fun save(delete: Boolean) {
        saving = true
        val list = places.filter { it.id != place.id } + if (delete) emptyList() else listOf(place.copy(name = place.name.trim()))
        scope.launch { LocationRepository.savePlaces(list); saving = false; onDone() }
    }
    @Suppress("DEPRECATION")
    fun search() {
        val q = query.trim(); if (q.isEmpty()) return
        scope.launch {
            results = withContext(Dispatchers.IO) {
                runCatching { Geocoder(ctx, Locale(I18n.language.code)).getFromLocationName(q, 4) }.getOrNull() ?: emptyList()
            }
        }
    }
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            PageBar(if (isNew) tr("מקום חדש") else place.name, onDone) {
                Text(tr("שמירה"), color = Color(0xFF4B3BC4), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 15.sp,
                    modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White)
                        .clickable(enabled = !saving && place.name.isNotBlank()) { save(false) }.padding(horizontal = 16.dp, vertical = 9.dp))
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(query, { query = it }, Modifier.weight(1f), singleLine = true,
                    placeholder = { Text(tr("חיפוש כתובת או מקום")) }, shape = RoundedCornerShape(14.dp))
                Text(tr("חיפוש"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 15.sp,
                    modifier = Modifier.clickable { search() }.padding(8.dp))
            }
            if (results.isNotEmpty()) Column(Modifier.fillMaxWidth().glassPane(16.dp, 0.16f, shadow = false).padding(horizontal = 14.dp)) {
                for (a in results) Text(listOfNotNull(a.featureName, a.thoroughfare, a.locality).distinct().joinToString(" · "),
                    color = Color.White, fontFamily = Rounded, fontSize = 14.sp,
                    modifier = Modifier.fillMaxWidth().clickable {
                        place = place.copy(lat = a.latitude, lng = a.longitude, name = place.name.ifBlank { a.featureName ?: "" })
                        center = GeoPoint(a.latitude, a.longitude); results = emptyList()
                    }.padding(vertical = 10.dp))
            }
            Box(Modifier.fillMaxWidth().height(260.dp).clip(RoundedCornerShape(22.dp)), contentAlignment = Alignment.Center) {
                FamilyMap(emptyList(), listOf(place), Modifier.fillMaxSize(), center = center, zoom = 17.0) { g ->
                    place = place.copy(lat = g.latitude, lng = g.longitude)
                }
                Text("📍", fontSize = 34.sp, modifier = Modifier.offset(y = (-16).dp))
            }
            Text(tr("הזיזו את המפה כך שהסיכה על המקום"), color = Ink.secondary, fontFamily = Rounded, fontSize = 12.5.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally))
            Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.16f, shadow = false).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(tr("שם המקום"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                OutlinedTextField(place.name, { place = place.copy(name = it) }, Modifier.fillMaxWidth(), singleLine = true,
                    placeholder = { Text(tr("למשל: בית הספר")) }, shape = RoundedCornerShape(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (e in listOf("🏠", "🏫", "⚽", "🎨", "🎵", "👵", "🏊", "📍")) Text(e, fontSize = 22.sp, textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f).clip(RoundedCornerShape(10.dp))
                            .background(if (place.emoji == e) Mint.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.1f))
                            .clickable {
                                // An empty name takes the obvious one, in the app's language.
                                val defaults = mapOf("🏠" to tr("הבית"), "🏫" to tr("בית הספר"), "⚽" to tr("חוג"), "👵" to tr("סבא וסבתא"), "🏊" to tr("בריכה"))
                                val name = if (place.name.isBlank() || place.name in defaults.values) defaults[e] ?: place.name else place.name
                                place = place.copy(emoji = e, name = name)
                            }.padding(vertical = 8.dp))
                }
                Text(tr("גודל האזור"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (r in FamilyPlace.RADII) Text(tr("%lld מ׳", r.toLong()), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black,
                        fontSize = 15.sp, textAlign = TextAlign.Center, modifier = Modifier.weight(1f).clip(RoundedCornerShape(14.dp))
                            .background(if (place.radius == r) Mint.copy(alpha = 0.45f) else Color.White.copy(alpha = 0.12f))
                            .clickable { place = place.copy(radius = r) }.padding(vertical = 11.dp))
                }
            }
            Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.16f, shadow = false).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tr("התראה כש…"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                for (c in kids) {
                    val a = place.alerts[c.id] ?: PlaceAlert(false, false)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ChildAvatar(c, 30.dp)
                        Text(stripNiqqud(c.name), Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 16.sp)
                        Chip(if (c.isGirl) tr("מגיעה") else tr("מגיע"), a.arrive) { place = place.copy(alerts = place.alerts + (c.id to a.copy(arrive = !a.arrive))) }
                        Chip(if (c.isGirl) tr("יוצאת") else tr("יוצא"), a.leave) { place = place.copy(alerts = place.alerts + (c.id to a.copy(leave = !a.leave))) }
                    }
                }
            }
            if (!isNew) Text(tr("מחיקת המקום"), color = Color(0xFFFFB4C8), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 15.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally).clickable { save(true) }.padding(10.dp))
        }
    }
}

@Composable
private fun Chip(title: String, on: Boolean, onClick: () -> Unit) {
    Text(if (on) "$title ✓" else title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 13.5.sp,
        modifier = Modifier.clip(CircleShape).background(if (on) Mint.copy(alpha = 0.45f) else Color.White.copy(alpha = 0.12f))
            .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp))
}
