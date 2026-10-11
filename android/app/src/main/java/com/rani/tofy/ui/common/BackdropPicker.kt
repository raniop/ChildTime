package com.rani.tofy.ui.common

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.enforce.CameraPass
import com.rani.tofy.kid.ui.JoinRepository
import com.rani.tofy.ui.home.stripNiqqud
import com.rani.tofy.ui.theme.BackdropLayer
import com.rani.tofy.ui.theme.BackdropLook
import com.rani.tofy.ui.theme.BackdropPicture
import com.rani.tofy.ui.theme.BackdropStore
import com.rani.tofy.ui.theme.BackdropTheme
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.rememberBackdropLook
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 🎨 BackdropPickerView.swift, in its three tabs: 🖼 the built-in pictures,
 * 🎨 the built-in colours, 📷 a photo of your own (camera or album) — for a
 * child (`ownerKey` = their id, pointed Hebrew) and for the parent (`ownerKey`
 * = "parent"). Tapping one applies it at once: this screen sits on the
 * backdrop itself.
 */
@Composable
fun BackdropPickerScreen(ownerKey: String, householdID: String?, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val forChild = ownerKey != BackdropStore.PARENT
    fun word(s: String) = if (forChild) s else stripNiqqud(s)
    val look = rememberBackdropLook(ownerKey)
    BackdropStore.photoRevision
    val ownPhotos = BackdropStore.ownPhotos(ownerKey)
    val canAdd = BackdropStore.freePhotoID(ownerKey) != null
    val selected = look.id
    var tab by rememberSaveable { mutableStateOf(demoTab ?: 0) }
    var addMenu by remember { mutableStateOf(false) }
    var photoToRemove by remember { mutableStateOf<String?>(null) }

    fun choose(id: String) {
        if (!forChild) { BackdropStore.chooseForParent(id); return }
        BackdropStore.childPicked(ownerKey, id)      // on screen now; the child doc follows
        scope.launch { JoinRepository.childWrite(ownerKey, householdID, mapOf("backdropID" to id, "backdropUpdatedAt" to nowSecs())) }
    }
    /** A new photo into the first free place (up to six) — and it becomes the backdrop. */
    fun usePhoto(bitmap: Bitmap?) {
        bitmap ?: return
        scope.launch {
            val id = BackdropStore.freePhotoID(ownerKey) ?: return@launch
            val jpeg = withContext(Dispatchers.IO) { BackdropStore.compress(bitmap) } ?: return@launch
            val stamp = BackdropStore.savePhoto(ownerKey, id, jpeg) ?: return@launch
            if (!forChild) { BackdropStore.chooseForParent(id); return@launch }
            BackdropStore.childPicked(ownerKey, id)
            BackdropStore.upload(ownerKey, id, jpeg, stamp)   // the picture first, then the pointer to it
            JoinRepository.childWrite(ownerKey, householdID, mapOf("backdropID" to id, "backdropUpdatedAt" to stamp))
        }
    }
    /** Take one away — here and on the child's other devices. If it was the backdrop, the newest one left takes over (or the default). */
    fun removePhoto(id: String) {
        val wasChosen = selected == id
        BackdropStore.forget(ownerKey, id)
        if (wasChosen) choose(BackdropStore.ownPhotos(ownerKey).lastOrNull()?.id ?: BackdropTheme.tofy.id)
        if (forChild) scope.launch { BackdropStore.uploadRemoval(ownerKey, id) }
    }
    // A child's second device: the photos added on the other one.
    LaunchedEffect(tab) {
        val demo = demoPhotos
        if (demo != null) BackdropStore.seedDemoPhotos(ownerKey, demo)
        else if (tab == 2 && forChild) BackdropStore.syncPhotoSet(ownerKey)
    }

    // Full-size capture into our cache through the FileProvider (as the chore photo does).
    val shotFile = remember { File(ctx.cacheDir, "photos/backdrop.jpg") }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (forChild) CameraPass.disarm(ctx)          // back in Tofy — the camera is locked again
        if (ok && shotFile.exists()) scope.launch {
            usePhoto(withContext(Dispatchers.IO) { decode(ctx, Uri.fromFile(shotFile)).also { shotFile.delete() } })
        }
    }
    fun launchCamera() {
        val uri = runCatching {
            shotFile.parentFile?.mkdirs(); shotFile.delete()
            FileProvider.getUriForFile(ctx, ctx.packageName + ".files", shotFile)
        }.getOrNull() ?: return
        if (forChild) CameraPass.arm(ctx)             // 📸 the lock blocks every other app — let the camera through
        runCatching { camera.launch(uri) }.onFailure { if (forChild) CameraPass.disarm(ctx) }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> if (ok) launchCamera() }
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch { usePhoto(withContext(Dispatchers.IO) { decode(ctx, uri) }) }
    }
    val hasCamera = remember { ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) }
    // A phone on its side: more, smaller tiles — three across would each be taller than the screen.
    val columns = LocalConfiguration.current.let { if (it.smallestScreenWidthDp >= 600) 5 else if (it.screenWidthDp > it.screenHeightDp) 6 else 3 }

    BackHandler(onBack = onClose)
    Box(Modifier.fillMaxSize()) {
        // Deeper than on the other screens: the title and the tabs sit straight on the picture here.
        BackdropLayer(look, veil = 0.50f)
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp).padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f))
                    .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable(onClick = onClose), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Close, word(tr("סְגֹר")), tint = Color.White, modifier = Modifier.size(20.dp))
                }
                Text("🎨 " + word(if (forChild) tr("הָרֶקַע שֶׁלִּי") else tr("רֶקַע")), Modifier.weight(1f), color = Color.White,
                    fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.width(44.dp))
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp).padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(tr("🖼 תְּמוּנוֹת"), tr("🎨 צְבָעִים"), tr("📷 מִשֶּׁלִּי")).forEachIndexed { i, title ->
                    TabButton(word(title), tab == i, Modifier.weight(1f)) { tab = i }
                }
            }
            LazyVerticalGrid(
                GridCells.Fixed(columns), Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 14.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (tab == 0) items(BackdropPicture.all, key = { it.id }) { picture ->
                    Tile(word(picture.displayName), selected == picture.id, { choose(picture.id) }) {
                        Image(painterResource(picture.thumb), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    }
                }
                if (tab == 1) items(BackdropTheme.all, key = { it.id }) { theme ->
                    Tile(word(theme.displayName), selected == theme.id, { choose(theme.id) }) {
                        BackdropLayer(BackdropLook(theme), scale = 0.3f)
                    }
                }
                // No camera / album buttons on top (Rani, 2026-10-11): the ＋ tile is the way in.
                if (tab == 2 && !canAdd) item(span = { GridItemSpan(maxLineSpan) }) {
                    Text(word(tr("אֶפְשָׁר לִשְׁמוֹר עַד 6 תְּמוּנוֹת. כְּדֵי לְהוֹסִיף חֲדָשָׁה, מְסִירִים אַחַת.")), Modifier.fillMaxWidth(), color = Color.White,
                        fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, textAlign = TextAlign.Center)
                }
                if (tab == 2) items(ownPhotos, key = { it.id }) { photo ->
                    Box {
                        Tile("", selected == photo.id, { choose(photo.id) }) {
                            Image(photo.thumb, word(tr("הַתְּמוּנָה שֶׁלִּי")), Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                        }
                        // ✕ a 44dp target around a small mark
                        Box(Modifier.align(Alignment.TopStart).size(44.dp).clickable { photoToRemove = photo.id }, contentAlignment = Alignment.Center) {
                            Box(Modifier.size(28.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.62f))
                                .border(1.dp, Color.White.copy(alpha = 0.7f), CircleShape), contentAlignment = Alignment.Center) {
                                Icon(Icons.Filled.Close, word(tr("הֲסָרָה")), tint = Color.White, modifier = Modifier.size(15.dp))
                            }
                        }
                    }
                }
                if (tab == 2 && canAdd) item {
                    Box {
                        AddPhotoTile(word(tr("הוֹסָפַת תְּמוּנָה"))) {
                            if (hasCamera) addMenu = true
                            else library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }
                        DropdownMenu(addMenu, { addMenu = false }) {
                            DropdownMenuItem({ Text("📷 " + word(tr("לְצַלֵּם")), fontFamily = Rounded, fontWeight = FontWeight.Bold) }, {
                                addMenu = false
                                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) launchCamera()
                                else cameraPermission.launch(Manifest.permission.CAMERA)
                            })
                            DropdownMenuItem({ Text("🖼 " + word(tr("מֵהָאַלְבּוֹם")), fontFamily = Rounded, fontWeight = FontWeight.Bold) }, {
                                addMenu = false
                                library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                            })
                        }
                    }
                }
            }
        }
    }

    photoToRemove?.let { id ->
        AlertDialog(
            onDismissRequest = { photoToRemove = null },
            title = { Text(word(tr("לְהָסִיר אֶת הַתְּמוּנָה?")), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold) },
            confirmButton = { TextButton({ photoToRemove = null; removePhoto(id) }) { Text(word(tr("הֲסָרָה")), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, color = Color(0xFFD9364A)) } },
            dismissButton = { TextButton({ photoToRemove = null }) { Text(if (forChild) tr("בִּטּוּל") else tr("ביטול"), fontFamily = Rounded) } },
        )
    }
}

/** 🧪 `--es demoBackdropTab colours|mine` — screenshots. */
var demoTab: Int? = null
/** 🧪 `--ei demoBackdropPhotos N` — the "mine" tab with exactly N photos. */
var demoPhotos: Int? = null

/** One of the three tabs — a 16dp rounded button; the open one is white. */
@Composable
private fun TabButton(title: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(modifier.heightIn(min = 46.dp).clip(shape)
        .background(if (on) Color.White else Color.Black.copy(alpha = 0.28f))
        .border(1.dp, Color.White.copy(alpha = if (on) 0f else 0.30f), shape)
        .clickable(onClick = onClick).padding(horizontal = 6.dp), contentAlignment = Alignment.Center) {
        Text(title, color = if (on) Color(0xFF2A1E5C) else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
            fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/**
 * ＋ The empty place next to their photos IS the way to add one (Rani, 2026-10-11):
 * tap → camera or album; once added, a new empty place opens beside it, up to six.
 */
@Composable
private fun AddPhotoTile(text: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Column(Modifier.fillMaxWidth().aspectRatio(0.62f).clip(shape).background(Color.Black.copy(alpha = 0.24f))
        .drawBehind {
            val r = 16.dp.toPx()
            drawRoundRect(Color.White.copy(alpha = 0.85f), cornerRadius = CornerRadius(r, r),
                style = Stroke(2.dp.toPx() * 2, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx()))))
        }.clickable(onClick = onClick).padding(6.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White), contentAlignment = Alignment.Center) {
            Text("+", color = Color(0xFF2A1E5C), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 28.sp)
        }
        Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Composable
private fun Tile(name: String, selected: Boolean, onClick: () -> Unit, art: @Composable () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(Modifier.fillMaxWidth().aspectRatio(0.62f).clip(shape)
        .border(if (selected) 3.dp else 1.dp, Color.White.copy(alpha = if (selected) 1f else 0.30f), shape)
        .clickable(onClick = onClick)) {
        art()
        // A photo of their own has no caption.
        if (name.isNotEmpty()) Text(name, Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(Color.Black.copy(alpha = 0.28f)).padding(6.dp),
            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
            fontSize = if (name.length > 14) 10.sp else if (name.length > 11) 11.5.sp else 13.sp,   // a long name (ru) shrinks, as on iOS
            textAlign = TextAlign.Center, maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (selected) Box(Modifier.align(Alignment.TopEnd).padding(6.dp).size(22.dp).clip(CircleShape).background(Color(0xFF2FD67B)),
            contentAlignment = Alignment.Center) {
            Text("✓", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 13.sp)
        }
    }
}

/** A picked / captured image, downscaled while decoding (a 12-megapixel bitmap would not fit in memory twice). */
private fun decode(ctx: Context, uri: Uri): Bitmap? = runCatching {
    if (Build.VERSION.SDK_INT >= 28) {
        ImageDecoder.decodeBitmap(ImageDecoder.createSource(ctx.contentResolver, uri)) { dec, info, _ ->
            val s = info.size
            val scale = minOf(1f, 1800f / maxOf(s.width, s.height))
            dec.setTargetSize((s.width * scale).toInt().coerceAtLeast(1), (s.height * scale).toInt().coerceAtLeast(1))
            dec.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
    } else {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 1400) sample *= 2
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
    }
}.getOrNull()
