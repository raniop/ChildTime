package com.rani.tofy.ui.contest

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * 🫙 A LIVE jar (iOS FamilyJar — Rani, 2026-10-24: "חייבים לעשות אותה חיה עם
 * כאילו מים זזים לפי תזוזת המכשיר"). The liquid keeps level with the real world
 * as the device tilts, sloshes past it and settles like a spring, waves harder
 * when shaken, and bubbles rise through it. No gravity sensor (an emulator) →
 * a gentle sway, so it never looks frozen. An empty jar is glass and lines only.
 */
@Composable
fun FamilyJar(fill: Double, stages: List<Double>, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val slosh = remember { JarSlosh() }
    var frame by remember { mutableLongStateOf(0L) }
    DisposableEffect(Unit) {
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val gravity = sm?.getDefaultSensor(Sensor.TYPE_GRAVITY)
        val linear = sm?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                when (e.sensor.type) {
                    Sensor.TYPE_GRAVITY -> { slosh.gx = e.values[0].toDouble(); slosh.gy = e.values[1].toDouble(); slosh.hasGravity = true }
                    Sensor.TYPE_LINEAR_ACCELERATION ->
                        slosh.shake = minOf(1.0, sqrt((e.values[0] * e.values[0] + e.values[1] * e.values[1] + e.values[2] * e.values[2]).toDouble()) / 9.81 * 1.5)
                }
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) = Unit
        }
        gravity?.let { sm.registerListener(listener, it, SensorManager.SENSOR_DELAY_GAME) }
        linear?.let { sm.registerListener(listener, it, SensorManager.SENSOR_DELAY_GAME) }
        onDispose { sm?.unregisterListener(listener) }
    }
    LaunchedEffect(Unit) {
        var last = 0L
        while (true) withFrameNanos { t ->
            val dt = if (last == 0L) 1.0 / 60 else ((t - last) / 1e9).coerceIn(0.0, 0.05)
            last = t
            slosh.step(dt)
            frame = t
        }
    }
    val measurer = rememberTextMeasurer()
    // (A Canvas is never mirrored: the jar is the same picture in every language.)
    BoxWithConstraints(modifier) {
        val lid = 18.dp
        Box(Modifier.align(Alignment.TopCenter).fillMaxWidth(0.62f).height(16.dp).clip(RoundedCornerShape(6.dp))
            .background(Brush.verticalGradient(listOf(Color(0xFFD9A06C), Color(0xFFA86E43)))))
        Canvas(Modifier.padding(top = lid).fillMaxWidth().height(maxHeight - lid)) {
            @Suppress("UNUSED_EXPRESSION") frame   // redraw every frame
            val w = size.width; val h = size.height
            fun pt(x: Double) = (x * density).toFloat()   // iOS points ≈ dp
            val corner = CornerRadius(16.dp.toPx())
            val shape = Path().apply { addRoundRect(RoundRect(0f, 0f, w, h, corner)) }
            drawPath(shape, Color.White.copy(alpha = 0.12f))
            val dash = PathEffect.dashPathEffect(floatArrayOf(pt(6.0), pt(5.0)))
            fun mark(f: Double, alpha: Float) {
                val y = (h * (1 - f * HEADROOM)).toFloat()
                drawLine(Color.White.copy(alpha = alpha), Offset(0f, y), Offset(w, y), strokeWidth = pt(2.0), pathEffect = dash)
            }
            val rim = Stroke(width = pt(2.5))
            if (fill <= 0.005) {
                drawPath(shape, Color.White.copy(alpha = 0.75f), style = rim)
                stages.forEach { mark(it, 0.85f) }
                return@Canvas
            }
            val level = h * (1 - minOf(fill, 1.0) * HEADROOM)
            val slope = tan(slosh.angle)
            val amp = (2.2 + 7 * slosh.energy) * density
            fun surface(x: Float, shift: Double): Float =
                (level - slope * (x - w / 2) + amp * sin(x / w * 2 * Math.PI * 1.3 + slosh.phase + shift)).toFloat()
            fun liquid(shift: Double) = Path().apply {
                moveTo(0f, h)
                var x = 0f
                while (x <= w) { lineTo(x, surface(x, shift)); x += 2f }
                lineTo(w, surface(w, shift)); lineTo(w, h); close()
            }
            clipPath(shape) {
                // Back wave (lighter, out of step), then the front one.
                drawPath(liquid(2.1), Color(0xFFFFC56B).copy(alpha = 0.55f))
                drawPath(liquid(0.0), Brush.verticalGradient(listOf(Color(0xFFFFD66B), Color(0xFFFF9F43)),
                    startY = (level - pt(10.0)).toFloat(), endY = h))
                // Bubbles rising through the liquid only.
                for (b in BUBBLES) {
                    val x = w * b.x
                    val top = surface(x, 0.0) + pt(6.0)
                    val travel = h - top
                    if (travel <= pt(10.0)) continue
                    val y = h - ((slosh.time * b.speed + b.seed) % 1.0).toFloat() * travel
                    val wobble = pt(sin(slosh.time * 3 + b.seed * 9) * 2)
                    drawCircle(Color.White.copy(alpha = 0.75f), pt(b.size.toDouble()), Offset(x + wobble, y), style = Stroke(pt(1.2)))
                }
                // Two stars riding the waves.
                for ((fx, shift) in listOf(0.32 to 0.0, 0.7 to 1.4)) {
                    val x = (w * fx).toFloat()
                    val r = measurer.measure("⭐", TextStyle(fontSize = 13.sp))
                    val y = surface(x, 0.0) - pt(2.0) + pt(sin(slosh.phase + shift) * 1.5)
                    drawText(r, topLeft = Offset(x - r.size.width / 2f, y - r.size.height / 2f))
                }
            }
            // The stage marks, painted on the glass over the liquid.
            stages.forEach { mark(it, if (it <= fill) 0.55f else 0.85f) }
            // Glass: a highlight and the rim.
            drawRoundRect(Color.White.copy(alpha = 0.28f), Offset(w * 0.12f, h * 0.1f), Size(pt(6.0), h * 0.6f), CornerRadius(pt(3.0)))
            drawPath(shape, Color.White.copy(alpha = 0.75f), style = rim)
        }
    }
}

/** A full jar fills this much of the glass — the last mark sits below the rim. */
const val HEADROOM = 0.82

private class Bubble(val x: Float, val speed: Double, val seed: Double, val size: Float)
private val BUBBLES = listOf(
    Bubble(0.22f, 0.32, 0.10, 3f), Bubble(0.45f, 0.24, 0.55, 2.2f), Bubble(0.63f, 0.38, 0.30, 3.4f),
    Bubble(0.80f, 0.28, 0.85, 2.4f), Bubble(0.35f, 0.42, 0.70, 1.8f), Bubble(0.55f, 0.30, 0.05, 2.8f),
)

/** The liquid's physics: a damped spring toward "level with the world" (iOS JarSlosh). */
internal class JarSlosh {
    var angle = 0.0; private set          // surface tilt on screen, radians
    var energy = 0.0; private set         // 0…1, how hard it is waving
    var phase = 0.0; private set
    var time = 0.0; private set
    private var velocity = 0.0
    @Volatile var gx = 0.0
    @Volatile var gy = 9.81
    @Volatile var hasGravity = false
    @Volatile var shake = 0.0

    fun step(dt: Double) {
        time += dt
        // Android reports gravity's reaction (upright: y = +g). The device rolled
        // clockwise by θ reads x = −g·sinθ, y = g·cosθ → the level shows as θ.
        var target = if (hasGravity) atan2(-gx, gy) else 0.3 * sin(time * 1.1) + 0.12 * sin(time * 2.7)
        target = target.coerceIn(-0.55, 0.55)
        // Underdamped spring: it overshoots the level a little, then settles.
        velocity += ((target - angle) * 55 - velocity * 3.2) * dt
        angle += velocity * dt
        energy = maxOf(energy * 0.97, minOf(1.0, abs(velocity) * 0.35 + shake))
        shake *= 0.9
        phase += dt * (2.0 + energy * 7)
    }
}
