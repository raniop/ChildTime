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
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.rani.tofy.ui.theme.BackdropStore
import com.rani.tofy.ui.theme.BackdropTheme
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import com.rani.tofy.ui.theme.rememberBackdropLook
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 🎨 BackdropPickerView.swift: every built-in backdrop, or a photo of your own
 * (camera or album) — for a child (`ownerKey` = their id, pointed Hebrew) and
 * for the parent (`ownerKey` = "parent"). Tapping one applies it at once: this
 * screen sits on the backdrop itself.
 */
@Composable
fun BackdropPickerScreen(ownerKey: String, householdID: String?, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val forChild = ownerKey != BackdropStore.PARENT
    fun word(s: String) = if (forChild) s else stripNiqqud(s)
    val look = rememberBackdropLook(ownerKey)
    BackdropStore.photoRevision
    val ownPhoto = BackdropStore.photo(ownerKey)
    val selected = when {
        look.photo != null -> BackdropTheme.PHOTO
        else -> look.theme.id
    }

    fun choose(id: String) {
        if (!forChild) { BackdropStore.chooseForParent(id); return }
        BackdropStore.childPicked(ownerKey, id)      // on screen now; the child doc follows
        scope.launch { JoinRepository.childWrite(ownerKey, householdID, mapOf("backdropID" to id, "backdropUpdatedAt" to nowSecs())) }
    }
    fun usePhoto(bitmap: Bitmap?) {
        bitmap ?: return
        scope.launch {
            val jpeg = withContext(Dispatchers.IO) { BackdropStore.compress(bitmap) } ?: return@launch
            val stamp = BackdropStore.savePhoto(ownerKey, jpeg) ?: return@launch
            if (!forChild) { BackdropStore.chooseForParent(BackdropTheme.PHOTO); return@launch }
            BackdropStore.childPicked(ownerKey, BackdropTheme.PHOTO)
            BackdropStore.upload(ownerKey, jpeg, stamp)   // the picture first, then the pointer to it
            JoinRepository.childWrite(ownerKey, householdID, mapOf("backdropID" to BackdropTheme.PHOTO, "backdropUpdatedAt" to stamp))
        }
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
    val columns = if (LocalConfiguration.current.smallestScreenWidthDp >= 600) 5 else 3

    BackHandler(onBack = onClose)
    Box(Modifier.fillMaxSize()) {
        BackdropLayer(look)
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
            LazyVerticalGrid(
                GridCells.Fixed(columns), Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 14.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (hasCamera) PhotoButton("📷", word(tr("לְצַלֵּם")), Modifier.weight(1f)) {
                            if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) launchCamera()
                            else cameraPermission.launch(Manifest.permission.CAMERA)
                        }
                        PhotoButton("🖼", word(tr("מֵהָאַלְבּוֹם")), Modifier.weight(1f)) {
                            library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }
                    }
                }
                if (ownPhoto != null) item {
                    Tile(word(tr("הַתְּמוּנָה שֶׁלִּי")), selected == BackdropTheme.PHOTO, { choose(BackdropTheme.PHOTO) }) {
                        Image(ownPhoto, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    }
                }
                items(BackdropTheme.all, key = { it.id }) { theme ->
                    Tile(word(theme.displayName), selected == theme.id, { choose(theme.id) }) {
                        BackdropLayer(BackdropLook(theme), scale = 0.3f)
                    }
                }
            }
        }
    }
}

@Composable
private fun PhotoButton(emoji: String, title: String, modifier: Modifier, onClick: () -> Unit) {
    Row(modifier.heightIn(min = 52.dp).glassPane(16.dp, 0.20f).clickable(onClick = onClick).padding(horizontal = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        Text(emoji, fontSize = 20.sp)
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun Tile(name: String, selected: Boolean, onClick: () -> Unit, art: @Composable () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(Modifier.fillMaxWidth().aspectRatio(0.62f).clip(shape)
        .border(if (selected) 3.dp else 1.dp, Color.White.copy(alpha = if (selected) 1f else 0.30f), shape)
        .clickable(onClick = onClick)) {
        art()
        Text(name, Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(Color.Black.copy(alpha = 0.28f)).padding(6.dp),
            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp,
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
