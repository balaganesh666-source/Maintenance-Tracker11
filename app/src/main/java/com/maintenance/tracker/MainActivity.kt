package com.maintenance.tracker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.math.max

// ------------------------------------------------------------
// Data
// ------------------------------------------------------------

data class Service(val day: Long, val km: Int, val cost: Int, val note: String)

data class Tracked(
    val id: String,
    val name: String,
    val emoji: String,
    val months: Int,
    val intervalKm: Int,
    val km: Int,
    val baseDay: Long,
    val baseKm: Int,
    val services: List<Service>
) {
    fun total(): Int = services.sumOf { it.cost }
}

data class Status(val frac: Float, val level: Int, val text: String)

data class Preset(val emoji: String, val label: String, val months: Int, val km: Int)

val presets = listOf(
    Preset("🚗", "Car", 6, 5000),
    Preset("🏍️", "Bike", 3, 3000),
    Preset("❄️", "AC", 6, 0),
    Preset("🧺", "Washing machine", 12, 0),
    Preset("💧", "Water filter", 6, 0),
    Preset("📦", "Other", 6, 0)
)

fun Tracked.status(today: Long): Status {
    val last = services.maxByOrNull { it.day }
    val lastDay = last?.day ?: baseDay
    val lastKm = if (last != null && last.km > 0) last.km else baseKm
    var frac = 0f
    val parts = mutableListOf<String>()
    if (months > 0) {
        val next = LocalDate.ofEpochDay(lastDay).plusMonths(months.toLong()).toEpochDay()
        val total = (next - lastDay).coerceAtLeast(1L)
        frac = max(frac, (today - lastDay).toFloat() / total.toFloat())
        val left = next - today
        parts += if (left >= 0) "$left days left" else "${-left} days overdue"
    }
    if (intervalKm > 0) {
        frac = max(frac, (km - lastKm).toFloat() / intervalKm.toFloat())
        val left = lastKm + intervalKm - km
        parts += if (left >= 0) "$left km left" else "${-left} km over"
    }
    val level = when {
        frac >= 1f -> 2
        frac >= 0.85f -> 1
        else -> 0
    }
    val text = if (parts.isEmpty()) "No schedule set" else parts.joinToString(" · ")
    return Status(frac.coerceIn(0f, 1f), level, text)
}

fun money(n: Int): String = "₹" + "%,d".format(n)

fun fmtDay(day: Long): String =
    LocalDate.ofEpochDay(day).format(DateTimeFormatter.ofPattern("dd MMM yyyy"))

fun statusColor(level: Int): Color = when (level) {
    2 -> Color(0xFFEF4B5F)
    1 -> Color(0xFFFFA62B)
    else -> Color(0xFF2FB67C)
}

// ------------------------------------------------------------
// Storage (SharedPreferences + JSON, works offline)
// ------------------------------------------------------------

object Store {
    private const val PREFS = "maintenance"
    private const val KEY = "items"

    fun load(c: Context): List<Tracked> {
        val raw = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { toTracked(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun save(c: Context, list: List<Tracked>) {
        val arr = JSONArray()
        list.forEach { arr.put(toJson(it)) }
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }

    private fun toJson(t: Tracked): JSONObject {
        val services = JSONArray()
        t.services.forEach {
            services.put(
                JSONObject()
                    .put("day", it.day)
                    .put("km", it.km)
                    .put("cost", it.cost)
                    .put("note", it.note)
            )
        }
        return JSONObject()
            .put("id", t.id)
            .put("name", t.name)
            .put("emoji", t.emoji)
            .put("months", t.months)
            .put("intervalKm", t.intervalKm)
            .put("km", t.km)
            .put("baseDay", t.baseDay)
            .put("baseKm", t.baseKm)
            .put("services", services)
    }

    private fun toTracked(o: JSONObject): Tracked {
        val arr = o.getJSONArray("services")
        val services = (0 until arr.length()).map {
            val s = arr.getJSONObject(it)
            Service(s.getLong("day"), s.getInt("km"), s.getInt("cost"), s.getString("note"))
        }
        return Tracked(
            o.getString("id"), o.getString("name"), o.getString("emoji"),
            o.getInt("months"), o.getInt("intervalKm"), o.getInt("km"),
            o.getLong("baseDay"), o.getInt("baseKm"), services
        )
    }
}

// ------------------------------------------------------------
// Daily reminder check
// ------------------------------------------------------------

class DueWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val today = LocalDate.now().toEpochDay()
        val due = Store.load(applicationContext).filter { it.status(today).level >= 1 }
        if (due.isNotEmpty()) notifyDue(applicationContext, due)
        return Result.success()
    }
}

fun notifyDue(ctx: Context, due: List<Tracked>) {
    val nm = ctx.getSystemService(NotificationManager::class.java)
    if (Build.VERSION.SDK_INT >= 26) {
        nm.createNotificationChannel(
            NotificationChannel("due", "Service reminders", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }
    val pi = PendingIntent.getActivity(
        ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
    )
    val names = due.joinToString(", ") { it.name }
    val n = NotificationCompat.Builder(ctx, "due")
        .setSmallIcon(android.R.drawable.ic_popup_reminder)
        .setContentTitle("Service due: $names")
        .setContentText("Tap to open your maintenance tracker")
        .setContentIntent(pi)
        .setAutoCancel(true)
        .build()
    nm.notify(1, n)
}

// ------------------------------------------------------------
// Activity
// ------------------------------------------------------------

class MainActivity : ComponentActivity() {
    private val askNotifications =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "due-check",
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<DueWorker>(1, TimeUnit.DAYS).build()
        )

        setContent { AppTheme { MaintenanceApp() } }
    }
}

// ------------------------------------------------------------
// Theme
// ------------------------------------------------------------

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val scheme = if (isSystemInDarkTheme()) {
        darkColorScheme(
            primary = Color(0xFF9C8CFF),
            background = Color(0xFF12111A),
            surface = Color(0xFF1E1C2B),
            onBackground = Color(0xFFEDEBFF),
            onSurface = Color(0xFFEDEBFF)
        )
    } else {
        lightColorScheme(
            primary = Color(0xFF5B4BDB),
            background = Color(0xFFF5F3FF),
            surface = Color.White,
            onBackground = Color(0xFF1B1830),
            onSurface = Color(0xFF1B1830)
        )
    }
    MaterialTheme(colorScheme = scheme, content = content)
}

// ------------------------------------------------------------
// Small reusable pieces
// ------------------------------------------------------------

fun Modifier.bounceClick(onClick: () -> Unit): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val s by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "bounce"
    )
    this.scale(s).clickable(interactionSource = source, indication = null, onClick = onClick)
}

@Composable
fun Ring(frac: Float, color: Color, emoji: String, diameter: Dp, stroke: Dp) {
    val anim = remember { Animatable(0f) }
    LaunchedEffect(frac) {
        anim.animateTo(frac.coerceIn(0f, 1f), tween(900, easing = FastOutSlowInEasing))
    }
    val track = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
    Box(Modifier.size(diameter), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val sw = stroke.toPx()
            val topLeft = Offset(sw / 2, sw / 2)
            val arc = Size(this.size.width - sw, this.size.height - sw)
            drawArc(
                color = track, startAngle = 0f, sweepAngle = 360f, useCenter = false,
                topLeft = topLeft, size = arc, style = Stroke(sw, cap = StrokeCap.Round)
            )
            drawArc(
                color = color, startAngle = -90f, sweepAngle = 360f * anim.value, useCenter = false,
                topLeft = topLeft, size = arc, style = Stroke(sw, cap = StrokeCap.Round)
            )
        }
        Text(emoji, fontSize = (diameter.value * 0.4f).sp)
    }
}

@Composable
fun Pill(text: String) {
    Box(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.2f))
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(text, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun AnimatedMoney(target: Int) {
    val a = remember { Animatable(0f) }
    LaunchedEffect(target) {
        a.animateTo(target.toFloat(), tween(1000, easing = FastOutSlowInEasing))
    }
    Text(
        money(a.value.toInt()),
        color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold
    )
}

@Composable
fun Header(spent: Int, attention: Int, count: Int) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF5B4BDB), Color(0xFF9B6BFF))))
            .padding(22.dp)
    ) {
        Column {
            Text(
                "Maintenance Tracker",
                color = Color.White.copy(alpha = 0.85f), fontSize = 14.sp, fontWeight = FontWeight.Medium
            )
            Spacer(Modifier.height(10.dp))
            AnimatedMoney(spent)
            Text("spent on upkeep this year", color = Color.White.copy(alpha = 0.85f), fontSize = 14.sp)
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Pill("$count items")
                Pill(if (attention == 0) "All good ✓" else "$attention need attention")
            }
        }
    }
}

@Composable
fun EmptyState() {
    val inf = rememberInfiniteTransition(label = "empty")
    val dy by inf.animateFloat(
        initialValue = 0f, targetValue = -14f,
        animationSpec = infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "dy"
    )
    Column(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("🛠️", fontSize = 64.sp, modifier = Modifier.offset(y = dy.dp))
        Spacer(Modifier.height(12.dp))
        Text("Nothing tracked yet", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(
            "Tap “+ Add item” to track your car, bike, AC and more.",
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}

@Composable
fun ItemCard(t: Tracked, today: Long, index: Int, onClick: () -> Unit) {
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(index * 70L)
        shown = true
    }
    AnimatedVisibility(
        visible = shown,
        enter = fadeIn(tween(400)) + slideInVertically(tween(400)) { it / 3 }
    ) {
        val st = t.status(today)
        val color = statusColor(st.level)
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .bounceClick(onClick),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Ring(st.frac, color, t.emoji, 72.dp, 7.dp)
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(t.name, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(2.dp))
                    Text(st.text, color = color, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Spent ${money(t.total())}",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}

@Composable
fun StatCard(label: String, value: String, modifier: Modifier) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Text(
                label, fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
fun HistoryRow(s: Service, onDelete: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(fmtDay(s.day), fontWeight = FontWeight.Bold)
                val sub = listOfNotNull(
                    if (s.km > 0) "${s.km} km" else null,
                    s.note.ifBlank { null }
                ).joinToString(" · ")
                if (sub.isNotEmpty()) {
                    Text(
                        sub, fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
            Text(money(s.cost), fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(10.dp))
            Text(
                "✕", color = Color(0xFFEF4B5F),
       modifier = Modifier
                    .clickable { onDelete() }
                    .padding(6.dp)
            )
        }
    }
}

// ------------------------------------------------------------
// Dialogs
// ------------------------------------------------------------

@Composable
fun Field(label: String, value: String, onChange: (String) -> Unit, number: Boolean = false) {
    OutlinedTextField(
        value = value,
        onValueChange = { onChange(if (number) it.filter(Char::isDigit) else it) },
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = if (number) KeyboardType.Number else KeyboardType.Text
        ),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    )
}

@Composable
fun Dlg(
    title: String,
    confirm: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title, fontWeight = FontWeight.Bold) },
        text = {
            Column(
                Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                content = content
            )
        },
        confirmButton = { TextButton(onClick = onConfirm) { Text(confirm) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        shape = RoundedCornerShape(28.dp)
    )
}

@Composable
fun AddItemDialog(onSave: (Tracked) -> Unit, onDismiss: () -> Unit) {
    var preset by remember { mutableStateOf(presets[0]) }
    var name by remember { mutableStateOf("") }
    var months by remember { mutableStateOf(presets[0].months.toString()) }
    var kmInt by remember { mutableStateOf(presets[0].km.toString()) }
    var cur by remember { mutableStateOf("") }

    Dlg(
        title = "Add item",
        confirm = "Save",
        onConfirm = {
            val c = cur.toIntOrNull() ?: 0
            onSave(
                Tracked(
                    id = UUID.randomUUID().toString(),
                    name = name.ifBlank { preset.label },
                    emoji = preset.emoji,
                    months = months.toIntOrNull() ?: 0,
                    intervalKm = kmInt.toIntOrNull() ?: 0,
                    km = c,
                    baseDay = LocalDate.now().toEpochDay(),
                    baseKm = c,
                    services = emptyList()
                )
            )
        },
        onDismiss = onDismiss
    ) {
        Text("What are you tracking?", fontWeight = FontWeight.SemiBold)
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            presets.forEach { p ->
                FilterChip(
                    selected = preset == p,
                    onClick = {
                        preset = p
                        months = p.months.toString()
                        kmInt = if (p.km > 0) p.km.toString() else ""
                    },
                    label = { Text("${p.emoji} ${p.label}") }
                )
            }
        }
        Field("Name (optional)", name, { name = it })
        Field("Repeat every (months)", months, { months = it }, true)
        Field("Repeat every (km), vehicles only", kmInt, { kmInt = it }, true)
        Field("Current km reading, vehicles only", cur, { cur = it }, true)
    }
}

@Composable
fun ServiceDialog(
    t: Tracked,
    onSave: (cost: Int, km: Int, daysAgo: Int, note: String) -> Unit,
    onDismiss: () -> Unit
) {
    var cost by remember { mutableStateOf("") }
    var km by remember { mutableStateOf(if (t.km > 0) t.km.toString() else "") }
    var ago by remember { mutableStateOf("0") }
    var note by remember { mutableStateOf("") }

    Dlg(
        title = "Service done",
        confirm = "Save",
        onConfirm = {
            onSave(cost.toIntOrNull() ?: 0, km.toIntOrNull() ?: 0, ago.toIntOrNull() ?: 0, note)
        },
        onDismiss = onDismiss
    ) {
        Field("Cost (₹)", cost, { cost = it }, true)
        if (t.intervalKm > 0 || t.km > 0) {
            Field("Odometer (km)", km, { km = it }, true)
        }
        Field("Done how many days ago? (0 = today)", ago, { ago = it }, true)
        Field("Note (e.g. engine oil changed)", note, { note = it })
    }
}

@Composable
fun KmDialog(t: Tracked, onSave: (Int) -> Unit, onDismiss: () -> Unit) {
    var km by remember { mutableStateOf(if (t.km > 0) t.km.toString() else "") }
    Dlg(
        title = "Update km",
        confirm = "Save",
        onConfirm = { onSave(km.toIntOrNull() ?: t.km) },
        onDismiss = onDismiss
    ) {
        Field("Current km reading", km, { km = it }, true)
    }
}

// ------------------------------------------------------------
// Screens
// ------------------------------------------------------------

@Composable
fun HomeScreen(list: List<Tracked>, today: Long, onOpen: (String) -> Unit, onAdd: () -> Unit) {
    val year = LocalDate.now().year
    val spent = list.flatMap { it.services }
        .filter { LocalDate.ofEpochDay(it.day).year == year }
        .sumOf { it.cost }
    val attention = list.count { it.status(today).level >= 1 }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 110.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item { Header(spent, attention, list.size) }
            if (list.isEmpty()) {
                item { EmptyState() }
            }
            itemsIndexed(list, key = { _, t -> t.id }) { i, t ->
                ItemCard(t, today, i) { onOpen(t.id) }
            }
        }
        ExtendedFloatingActionButton(
            onClick = onAdd,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(20.dp),
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = Color.White,
            shape = RoundedCornerShape(20.dp)
        ) {
            Text("+ Add item", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun DetailScreen(
    t: Tracked,
    today: Long,
    onBack: () -> Unit,
    onAddService: (cost: Int, km: Int, daysAgo: Int, note: String) -> Unit,
    onUpdateKm: (Int) -> Unit,
    onDeleteService: (Service) -> Unit,
    onDeleteItem: () -> Unit
) {
    var showService by remember { mutableStateOf(false) }
    var showKm by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    val st = t.status(today)
    val color = statusColor(st.level)
    val history = t.services.sortedByDescending { it.day }
    val last = history.firstOrNull()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surface)
                        .clickable { onBack() },
                    contentAlignment = Alignment.Center
                ) {
                    Text("←", fontSize = 22.sp)
                }
                Spacer(Modifier.width(12.dp))
                Text(t.name, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            }
        }
        item { Ring(st.frac, color, t.emoji, 170.dp, 14.dp) }
        item {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(st.text, color = color, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Text(
                    if (last == null) "No service logged yet" else "Last service: ${fmtDay(last.day)}",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatCard("Spent", money(t.total()), Modifier.weight(1f))
                StatCard("Services", t.services.size.toString(), Modifier.weight(1f))
                StatCard("Odometer", if (t.km > 0) "${t.km} km" else "-", Modifier.weight(1f))
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = { showService = true },
                    modifier = Modifier
                        .weight(1f)
                        .height(52.dp),
                    shape = RoundedCornerShape(16.dp)
                ) { Text("✔ Service done", fontWeight = FontWeight.Bold) }
                if (t.intervalKm > 0 || t.km > 0) {
                    OutlinedButton(
                        onClick = { showKm = true },
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp),
                        shape = RoundedCornerShape(16.dp)
                    ) { Text("Update km") }
                }
            }
        }
        item {
            Text(
                "History",
                modifier = Modifier.fillMaxWidth(),
                fontSize = 18.sp, fontWeight = FontWeight.Bold
            )
        }
        if (history.isEmpty()) {
            item {
                Text(
                    "Nothing yet. Tap “Service done” after your next service.",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }
        items(history) { s ->
            HistoryRow(s) { onDeleteService(s) }
        }
        item {
            TextButton(onClick = { confirmDelete = true }) {
                Text("Delete this item", color = Color(0xFFEF4B5F))
            }
        }
    }

    if (showService) {
        ServiceDialog(
            t = t,
            onSave = { cost, km, ago, note ->
                showService = false
                onAddService(cost, km, ago, note)
            },
            onDismiss = { showService = false }
        )
    }
    if (showKm) {
        KmDialog(
            t = t,
            onSave = { km ->
                showKm = false
                onUpdateKm(km)
            },
            onDismiss = { showKm = false }
        )
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete ${t.name}?") },
            text = { Text("All its service history will be removed.") },
            confirmButton = {
                TextButton(onClick = { confirmDelete = false; onDeleteItem() }) {
                    Text("Delete", color = Color(0xFFEF4B5F))
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("Cancel") }
            }
        )
    }
}

// ------------------------------------------------------------
// App root
// ------------------------------------------------------------

@Composable
fun MaintenanceApp() {
    val ctx = LocalContext.current
    var list by remember { mutableStateOf(Store.load(ctx)) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    var showAdd by remember { mutableStateOf(false) }
    val today = LocalDate.now().toEpochDay()

    fun commit(newList: List<Tracked>) {
        list = newList
        Store.save(ctx, newList)
    }

    BackHandler(enabled = selectedId != null) { selectedId = null }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        AnimatedContent(
            targetState = selectedId,
            transitionSpec = {
                if (targetState != null) {
                    (slideInHorizontally(tween(350)) { it } + fadeIn(tween(350))) togetherWith
                        (slideOutHorizontally(tween(350)) { -it / 3 } + fadeOut(tween(350)))
                } else {
                    (slideInHorizontally(tween(350)) { -it / 3 } + fadeIn(tween(350))) togetherWith
                        (slideOutHorizontally(tween(350)) { it } + fadeOut(tween(350)))
                }
            },
            label = "nav"
        ) { id ->
            val current = list.find { it.id == id }
            if (id == null || current == null) {
                HomeScreen(
                    list = list,
                    today = today,
                    onOpen = { selectedId = it },
                    onAdd = { showAdd = true }
                )
            } else {
                DetailScreen(
                    t = current,
                    today = today,
                    onBack = { selectedId = null },
                    onAddService = { cost, km, ago, note ->
                        commit(list.map {
                            if (it.id == current.id) {
                                it.copy(
                                    services = it.services + Service(today - ago, km, cost, note),
                                    km = max(it.km, km)
                                )
                            } else it
                        })
                    },
                    onUpdateKm = { km ->
                        commit(list.map { if (it.id == current.id) it.copy(km = km) else it })
                    },
                    onDeleteService = { s ->
                        commit(list.map {
                            if (it.id == current.id) it.copy(services = it.services - s) else it
                        })
                    },
                    onDeleteItem = {
                        selectedId = null
                        commit(list.filter { it.id != current.id })
                    }
                )
            }
        }
    }

    if (showAdd) {
        AddItemDialog(
            onSave = {
                showAdd = false
                commit(list + it)
            },
            onDismiss = { showAdd = false }
        )
    }
}
