# iOS → Android Platform Mapping

> Reference guide for porting Who's There from Swift/SwiftUI to Kotlin/Jetpack Compose.
> Each section maps an iOS concept to its Android equivalent with notes on key differences.

---

## Language: Swift → Kotlin

| Swift | Kotlin | Notes |
|-------|--------|-------|
| `var` / `let` | `var` / `val` | Same concept — `val` is immutable like `let` |
| `String?` (optional) | `String?` (nullable) | Same `?` syntax, but Kotlin uses `!!` for force-unwrap (avoid it like `!` in Swift) |
| `guard let x = y else { return }` | `val x = y ?: return` | Elvis operator `?:` replaces guard-let in simple cases |
| `if let x = y { }` | `y?.let { x -> }` | Kotlin uses `let` scope function |
| `struct` (value type) | `data class` | Both are value types with auto equality/copy |
| `class` (reference type) | `class` | Same |
| `enum` with associated values | `sealed class` | Kotlin `enum class` can't hold associated data — use `sealed class` |
| `enum` (raw values only) | `enum class` | `enum class Color { RED, GREEN }` |
| `[String]` (Array) | `List<String>` / `MutableList<String>` | Use `listOf()` / `mutableListOf()` |
| `[String: Int]` (Dictionary) | `Map<String, Int>` / `MutableMap` | Use `mapOf()` / `mutableMapOf()` |
| `Set<String>` | `Set<String>` | Same concept |
| `extension Foo { }` | Extension functions: `fun Foo.bar() { }` | Same concept, different syntax |
| `protocol` | `interface` | Same concept |
| `throws` / `try` / `catch` | `throws` doesn't exist — use `try/catch` or `Result<T, E>` | Kotlin uses unchecked exceptions |
| `async/await` | `suspend fun` / coroutines | Very similar mental model — suspend replaces async |
| `Task { }` | `CoroutineScope.launch { }` or `viewModelScope.launch { }` | Launch coroutine on a scope |
| `@MainActor` | `Dispatchers.Main` / `.flowOn(Dispatchers.Main)` | Switch to main thread |
| `DispatchQueue.global()` | `Dispatchers.IO` | Background thread for Firestore, network |
| `typealias AppResult<T> = Result<T, AppError>` | `sealed class Result<T>` with `Success`/`Failure` subclasses | Kotlin doesn't have a built-in `Result` with custom error |
| String interpolation `"\(name)"` | `"$name"` or `"${name.length}"` | `${}` for expressions, `$` for simple variables |
| Trailing closure `foo { }` | Trailing lambda `foo { }` | Nearly identical syntax |
| Computed property `var x: Int { return 5 }` | `val x: Int get() = 5` | Same concept |

---

## Architecture: MVVM

| iOS (SwiftUI) | Android (Compose) | Notes |
|---------------|-------------------|-------|
| `ObservableObject` class | `ViewModel` class | Both are lifecycle-aware state holders |
| `@Published var x` | `private val _x = MutableStateFlow(...)` + `val x = _x.asStateFlow()` | StateFlow is the Kotlin equivalent of @Published |
| `@StateObject var vm` | `val vm: MyViewModel = viewModel()` | `viewModel()` in Compose gets or creates the ViewModel |
| `@ObservedObject var vm` | `val state by vm.myState.collectAsState()` | Collect StateFlow as Compose state |
| `@State var x` | `var x by remember { mutableStateOf(...) }` | Local composable state |
| `@Binding var x` | Pass lambda: `onXChanged: (T) -> Unit` | Compose prefers unidirectional data flow |
| `@Environment(\.dismiss)` | `val navController = rememberNavController()` then `navController.popBackStack()` | Navigation is explicit in Compose |
| `@EnvironmentObject` | Hilt dependency injection OR `CompositionLocalProvider` | Hilt is preferred for services |
| Service singleton `.shared` | `@Inject` via Hilt `@Singleton` | Use Hilt for all service injection |

---

## UI Framework: SwiftUI → Jetpack Compose

| SwiftUI | Compose | Notes |
|---------|---------|-------|
| `View` protocol | `@Composable` function | Functions, not types |
| `struct MyView: View { var body: some View { } }` | `@Composable fun MyScreen() { }` | No `body` property needed |
| `VStack` | `Column` | Vertical layout |
| `HStack` | `Row` | Horizontal layout |
| `ZStack` | `Box` | Overlapping layout |
| `Text("Hello")` | `Text("Hello")` | Same |
| `Image(systemName: "star")` | `Icon(Icons.Default.Star, contentDescription = "Star")` | Material icons instead of SF Symbols |
| `Button("Tap me") { }` | `Button(onClick = { }) { Text("Tap me") }` | Content is a composable lambda |
| `TextField("placeholder", text: $x)` | `OutlinedTextField(value = x, onValueChange = { x = it })` | State must be hoisted |
| `ScrollView` | `LazyColumn` (for lists) or `Column` in `verticalScroll` | Use LazyColumn for long lists |
| `List(items) { item in }` | `LazyColumn { items(list) { item -> } }` | LazyColumn is like UITableView |
| `ForEach(items) { item in }` | `items.forEach { item -> }` inside LazyColumn | Same concept |
| `NavigationStack` | `NavHost` + `composable("route") { }` | Route-based navigation |
| `NavigationLink` | `navController.navigate("route")` | Imperative navigation |
| `.sheet(isPresented: $x)` | `if (showSheet) { ModalBottomSheet { } }` or `Dialog { }` | Bottom sheets and dialogs in Compose |
| `.alert("Title", isPresented: $x)` | `AlertDialog(onDismissRequest = { }) { }` | Compose dialog composable |
| `.toolbar { ToolbarItem { } }` | `TopAppBar(actions = { IconButton { } })` | Material3 TopAppBar |
| `TabView` | `NavigationBar` + `NavigationBarItem` | Material3 bottom nav |
| `.padding()` | `Modifier.padding()` | Modifiers are chained differently |
| `.frame(maxWidth: .infinity)` | `Modifier.fillMaxWidth()` | Fill width |
| `.background(Color.blue)` | `Modifier.background(Color.Blue)` | Same concept |
| `.cornerRadius(12)` | `Modifier.clip(RoundedCornerShape(12.dp))` | Must clip to get rounded corners |
| `.opacity(0.5)` | `Modifier.alpha(0.5f)` | |
| `.onAppear { }` | `LaunchedEffect(Unit) { }` | Runs once when composable enters composition |
| `.onChange(of: x)` | `LaunchedEffect(x) { }` | Runs when `x` changes |
| `ShareLink(item: url)` | `val sendIntent = Intent(Intent.ACTION_SEND); startActivity(Intent.createChooser(...))` | Android share sheet |
| `ProgressView()` | `CircularProgressIndicator()` | |
| `Spacer()` | `Spacer(Modifier.weight(1f))` or `Spacer(Modifier.height(x.dp))` | |
| `.refreshable { }` (pull to refresh) | `PullToRefreshBox` (Material3 Compose) | |
| `.searchable(text: $query)` | `SearchBar` or `TextField` with search logic | No built-in searchable modifier |
| `@FocusState` | `FocusRequester` + `Modifier.focusRequester()` | Manual focus management |
| `HapticManager.light()` | `val vibrator = context.getSystemService(Vibrator::class.java)` + `VibrationEffect` | See HapticManager section below |

---

## Navigation

| iOS | Android | Notes |
|-----|---------|-------|
| `NavigationStack` | `NavHost` | Root navigation container |
| `NavigationLink(destination: DetailView())` | `navController.navigate("detail")` | String routes in Compose Nav |
| `.sheet(isPresented:)` | `ModalBottomSheet` or `Dialog` | Modal screens |
| `@Environment(\.dismiss) var dismiss; dismiss()` | `navController.popBackStack()` | Go back |
| Pass data via view init | Pass data as nav route args OR via ViewModel | Complex data should go through ViewModel, not nav args |

**Compose Navigation route setup:**
```kotlin
NavHost(navController, startDestination = "home") {
    composable("home") { HomeScreen(navController) }
    composable("groupDetail/{groupId}") { backStack ->
        val groupId = backStack.arguments?.getString("groupId")
        GroupDetailScreen(groupId, navController)
    }
}
```

---

## State Management

| iOS | Android |
|-----|---------|
| `@Published var groups: [Group] = []` | `private val _groups = MutableStateFlow<List<Group>>(emptyList())` |
| `@Published var isLoading = false` | `private val _isLoading = MutableStateFlow(false)` |
| Service singleton with @Published | `@HiltViewModel class GroupViewModel @Inject constructor(val repo: GroupRepository)` |
| SwiftUI auto-rerenders on @Published change | `collectAsState()` in composable triggers recomposition |

**Full ViewModel pattern:**
```kotlin
@HiltViewModel
class GroupViewModel @Inject constructor(
    private val repository: GroupRepository
) : ViewModel() {
    private val _groups = MutableStateFlow<List<LocationGroup>>(emptyList())
    val groups: StateFlow<List<LocationGroup>> = _groups.asStateFlow()

    fun loadGroups() {
        viewModelScope.launch {
            _groups.value = repository.fetchJoinedGroups()
        }
    }
}

// In Composable:
val groups by viewModel.groups.collectAsState()
```

---

## Firebase Auth

| iOS | Android |
|-----|---------|
| `Auth.auth().signInAnonymously()` | `Firebase.auth.signInAnonymously().await()` |
| `Auth.auth().currentUser?.uid` | `Firebase.auth.currentUser?.uid` |
| `ASAuthorizationAppleIDRequest` (native) | `OAuthProvider.newBuilder("apple.com")` → Chrome Custom Tab redirect |
| Sign in with Apple (native button) | Web-based OAuth flow (less polished, opens browser tab) |
| Sign in with Google (web-based on iOS) | `GoogleSignIn.getClient(context, gso).signIn()` (native, Credential Manager) |
| `Auth.auth().addStateDidChangeListener` | `Firebase.auth.addAuthStateListener { }` or `Firebase.auth.authStateChanges()` Flow |
| `auth.signOut()` | `Firebase.auth.signOut()` |

**Google Sign-In setup (Android, Credential Manager API):**
```kotlin
val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
    .requestIdToken(WEB_CLIENT_ID)  // From Firebase Console
    .requestEmail()
    .build()
val googleSignInClient = GoogleSignIn.getClient(context, gso)
```

**Apple Sign-In (Android — web redirect):**
```kotlin
val provider = OAuthProvider.newBuilder("apple.com")
    .addCustomParameter("locale", "en")
    .build()
Firebase.auth.startActivityForSignInWithProvider(activity, provider)
    .addOnSuccessListener { result -> /* handle */ }
```

---

## Firestore

The Kotlin Firestore API is nearly identical to Swift — same collection/document structure, same methods.

| iOS (Swift) | Android (Kotlin) |
|-------------|------------------|
| `db.collection("users").document(id).getDocument()` | `db.collection("users").document(id).get().await()` |
| `db.collection("groups").whereField("isPublic", isEqualTo: true)` | `db.collection("groups").whereEqualTo("isPublic", true)` |
| `try await ref.setData(from: model)` | `ref.set(model).await()` (with Kotlin data class) |
| `try await ref.updateData(["field": value])` | `ref.update("field", value).await()` |
| `FieldValue.arrayUnion([id])` | `FieldValue.arrayUnion(id)` |
| `FieldValue.arrayRemove([id])` | `FieldValue.arrayRemove(id)` |
| `try await ref.delete()` | `ref.delete().await()` |
| `ref.addSnapshotListener { snapshot, error in }` | `ref.addSnapshotListener { snapshot, error -> }` |
| `try? $0.data(as: LocationGroup.self)` | `snapshot.toObject(LocationGroup::class.java)` |
| `ListenerRegistration` | `ListenerRegistration` (same type) |
| Batch write: `let batch = db.batch()` | `val batch = db.batch()` |
| Transaction: `db.runTransaction { transaction in }` | `db.runTransaction { transaction -> }` |
| `SetOptions.merge()` → `setData(..., merge: true)` | `ref.set(data, SetOptions.merge()).await()` |

**Kotlin data class for Firestore (matches iOS CodingKeys exactly):**
```kotlin
data class LocationGroup(
    @DocumentId val id: String = "",
    val name: String = "",
    val emoji: String? = null,
    val isPublic: Boolean = true,
    val ownerId: String = "",
    val memberIds: List<String> = emptyList(),
    val boundary: List<Coordinate> = emptyList(),
    val centerLatitude: Double = 0.0,
    val centerLongitude: Double = 0.0,
    val presenceDisplayMode: String = "count",
    @ServerTimestamp val createdAt: Date? = null,
    val inviteCode: String? = null,
    val groupColor: String? = null
)
```

---

## Location & Geofencing

| iOS | Android |
|-----|---------|
| `CLLocationManager` | `FusedLocationProviderClient` (via Play Services) |
| `manager.requestWhenInUseAuthorization()` | Request `ACCESS_FINE_LOCATION` permission at runtime |
| `manager.requestAlwaysAuthorization()` | Request `ACCESS_BACKGROUND_LOCATION` **separately** after foreground granted |
| `manager.startUpdatingLocation()` | `fusedLocationClient.requestLocationUpdates(request, callback, looper)` |
| `manager.stopUpdatingLocation()` | `fusedLocationClient.removeLocationUpdates(callback)` |
| `CLCircularRegion` | `Geofence.Builder()` with lat/lng/radius |
| `manager.startMonitoring(for: region)` | `geofencingClient.addGeofences(request, pendingIntent)` |
| `manager.stopMonitoring(for: region)` | `geofencingClient.removeGeofences(listOf(id))` |
| `locationManager(_:didEnterRegion:)` delegate | `GeofenceBroadcastReceiver.onReceive()` + `GeofencingEvent.fromIntent(intent)` |
| Max **20** monitored regions (iOS limit) | Max **100** geofences per app |
| Geofences survive reboot automatically | **Must re-register on boot** via `BootReceiver` |
| Geofences survive app update automatically | **Must re-register after app update** |
| `kCLLocationAccuracyBest` | `Priority.PRIORITY_HIGH_ACCURACY` |

**Android geofence entry/exit handler:**
```kotlin
class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        val groupId = event.triggeringGeofences?.firstOrNull()?.requestId ?: return
        when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> { /* check in */ }
            Geofence.GEOFENCE_TRANSITION_EXIT  -> { /* check out */ }
        }
    }
}
```

**Required AndroidManifest entries:**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<receiver android:name=".service.GeofenceBroadcastReceiver" android:exported="false" />
<receiver android:name=".service.BootReceiver" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

---

## Maps

| iOS (MapKit) | Android (Google Maps Compose) |
|--------------|-------------------------------|
| `Map(position: $mapPosition)` | `GoogleMap(cameraPositionState = cameraPositionState)` |
| `MapPolygon(coordinates:)` | `Polygon(points = latLngList)` |
| `Annotation(title, coordinate:)` | `Marker(state = MarkerState(position = latLng))` |
| `UserAnnotation()` | `myLocationEnabled = true` on `GoogleMap` |
| `MKCoordinateRegion(center:, span:)` | `CameraPosition.fromLatLngZoom(latLng, zoom)` |
| `MapReader { proxy in proxy.convert(point, from: .local) }` | `googleMap.setOnMapClickListener { latLng -> }` |
| `.mapStyle(.standard)` | `MapProperties(mapType = MapType.NORMAL)` |
| No API key needed (uses Apple Maps) | Requires Google Maps API key in `AndroidManifest.xml` |

**API key setup in AndroidManifest.xml:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${MAPS_API_KEY}" />
```
Store key in `local.properties`: `MAPS_API_KEY=AIzaSy...`
Read it in `build.gradle.kts`: `manifestPlaceholders["MAPS_API_KEY"] = properties["MAPS_API_KEY"] ?: ""`

---

## Persistence (Local Storage)

| iOS | Android |
|-----|---------|
| `UserDefaults.standard` | `DataStore<Preferences>` (preferred) or `SharedPreferences` |
| `UserDefaults.standard.set(value, forKey: key)` | `dataStore.edit { prefs -> prefs[KEY] = value }` |
| `UserDefaults.standard.object(forKey: key)` | `dataStore.data.map { prefs -> prefs[KEY] }` |
| App Group shared UserDefaults (for widgets) | N/A — not porting widgets in V1 |

**DataStore setup:**
```kotlin
val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "whosthere_prefs")
val AUTO_CHECKOUT_KEY = stringPreferencesKey("auto_checkout_timers")
```

---

## Background Work

| iOS | Android |
|-----|---------|
| `Timer.scheduledTimer(withTimeInterval:)` | `WorkManager` for durable background work |
| Background app refresh | `WorkManager` periodic work request |
| Heartbeat every 15 min (PresenceService) | `PeriodicWorkRequest` with 15-min interval |
| Auto-checkout timer check on foreground | `ActivityLifecycleCallbacks.onActivityResumed()` |

**WorkManager periodic task:**
```kotlin
val heartbeatWork = PeriodicWorkRequestBuilder<PresenceHeartbeatWorker>(
    15, TimeUnit.MINUTES
).build()
WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "presence_heartbeat",
    ExistingPeriodicWorkPolicy.KEEP,
    heartbeatWork
)
```

---

## Push Notifications (FCM)

FCM works identically on iOS and Android — same Firebase project, same send API, same token storage pattern.

| iOS | Android |
|-----|---------|
| `UNUserNotificationCenter.requestAuthorization` | `NotificationManagerCompat.from(context).areNotificationsEnabled()` + system prompt |
| `Messaging.messaging().token` | `FirebaseMessaging.getInstance().token.await()` |
| `UNUserNotificationCenter.add(UNNotificationRequest)` | `NotificationManagerCompat.notify(id, notification)` |
| `AppDelegate.application(_:didReceiveRemoteNotification:)` | `FirebaseMessagingService.onMessageReceived(message)` |
| `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)` | `FirebaseMessagingService.onNewToken(token)` |

---

## Networking / Connectivity

| iOS | Android |
|-----|---------|
| `NWPathMonitor` (Network framework) | `ConnectivityManager` + `NetworkCallback` |
| `monitor.pathUpdateHandler = { path in }` | `connectivityManager.registerNetworkCallback(request, callback)` |
| `path.status == .satisfied` | `network != null` (callback's `onAvailable`) |

```kotlin
val connectivityManager = context.getSystemService(ConnectivityManager::class.java)
val callback = object : ConnectivityManager.NetworkCallback() {
    override fun onAvailable(network: Network) { isConnected = true }
    override fun onLost(network: Network) { isConnected = false }
}
connectivityManager.registerDefaultNetworkCallback(callback)
```

---

## Clipboard & Sharing

| iOS | Android |
|-----|---------|
| `UIPasteboard.general.string = code` | `clipboardManager.setPrimaryClip(ClipData.newPlainText("label", text))` |
| `ShareLink(item: url)` | `Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, url) }` |

```kotlin
// Clipboard
val clipboard = context.getSystemService(ClipboardManager::class.java)
clipboard.setPrimaryClip(ClipData.newPlainText("Invite Code", code))

// Share sheet
val intent = Intent.createChooser(
    Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, url)
        putExtra(Intent.EXTRA_SUBJECT, "Join ${group.name}")
    }, null
)
context.startActivity(intent)
```

---

## Haptics

| iOS (HapticManager) | Android |
|---------------------|---------|
| `UIImpactFeedbackGenerator(style: .light).impactOccurred()` | `vibrator.vibrate(VibrationEffect.createOneShot(50, 80))` |
| `UIImpactFeedbackGenerator(style: .medium)` | `vibrator.vibrate(VibrationEffect.createOneShot(80, 120))` |
| `UIImpactFeedbackGenerator(style: .heavy)` | `vibrator.vibrate(VibrationEffect.createOneShot(120, 200))` |
| `UINotificationFeedbackGenerator().notificationOccurred(.success)` | `vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 50, 50, 100), -1))` |

**HapticManager.kt:**
```kotlin
object HapticManager {
    fun light(context: Context) = vibrate(context, 50, 80)
    fun medium(context: Context) = vibrate(context, 80, 120)
    fun heavy(context: Context) = vibrate(context, 120, 200)

    private fun vibrate(context: Context, duration: Long, amplitude: Int) {
        val vibrator = context.getSystemService(Vibrator::class.java)
        vibrator?.vibrate(VibrationEffect.createOneShot(duration, amplitude))
    }
}
```

---

## Deep Links

| iOS | Android |
|-----|---------|
| `apple-app-site-association` file | `assetlinks.json` file (already created at `public/.well-known/assetlinks.json`) |
| `.onOpenURL { url in DeepLinkService.shared.handleURL(url) }` | Intent filter in `AndroidManifest.xml` + handle in `Activity.onNewIntent()` or `NavHost` |
| `pendingInviteCode` / `pendingGroupId` @Published | StateFlow in `DeepLinkViewModel` |

**AndroidManifest.xml intent filter:**
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="whostherefb.web.app"
          android:pathPrefix="/join/" />
    <data android:scheme="https"
          android:host="whostherefb.web.app"
          android:pathPrefix="/group/" />
</intent-filter>
```

---

## Dependency Injection

iOS uses manually-initialized singletons (`.shared`). Android uses **Hilt**.

| iOS | Android (Hilt) |
|-----|----------------|
| `static let shared = MyService()` | `@Singleton class MyRepository @Inject constructor(...)` |
| `FirestoreService.shared.doThing()` | `@Inject lateinit var repository: GroupRepository` in ViewModel |
| `@ObservedObject var service = MyService.shared` | `@HiltViewModel class VM @Inject constructor(val repo: Repo)` |

**Hilt module setup:**
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object FirebaseModule {
    @Provides @Singleton
    fun provideFirestore(): FirebaseFirestore = Firebase.firestore

    @Provides @Singleton
    fun provideAuth(): FirebaseAuth = Firebase.auth
}
```

---

## Error Handling

| iOS (`AppError` enum) | Android equivalent |
|-----------------------|-------------------|
| `enum AppError: LocalizedError` | `sealed class AppError : Exception()` |
| `case notAuthenticated` | `object NotAuthenticated : AppError()` |
| `case groupUpdateFailed(underlying: Error)` | `data class GroupUpdateFailed(val cause: Throwable) : AppError()` |
| `AppResult<T>` = `Result<T, AppError>` | `sealed class Result<T>` with `Success(val data: T)` and `Failure(val error: AppError)` |
| `.failure(AppError.notAuthenticated)` | `Result.Failure(AppError.NotAuthenticated)` |

---

## Color Palette

Port from `ColorPalette.swift` to Compose `Color`:

```kotlin
// Theme.kt
object WhosThereColors {
    val AppBlue      = Color(0xFF3A7BD5)  // Primary
    val AppNavy      = Color(0xFF1B2A4A)  // Dark / nav background
    val AppLightBlue = Color(0xFFE8F1FB)  // Light background
    val AppAmber     = Color(0xFFF5A623)  // Accent
    val AppCoral     = Color(0xFFFF6B4A)  // CTA buttons (create group, etc.)
    val AppGreen     = Color(0xFF34C759)  // Check-in / success
    val AppRed       = Color(0xFFFF3B30)  // Destructive / error
}
```

---

## Validation (Pure Logic — Direct Port)

These functions have no platform dependencies and can be ported line-by-line to Kotlin:

| Function | File | Notes |
|----------|------|-------|
| `validateDisplayName(_:)` | `Validation.swift` | 1-50 chars, no special chars |
| `validateGroupName(_:)` | `Validation.swift` | 1-100 chars |
| `validateMessage(_:)` | `Validation.swift` | 1-500 chars, profanity check |
| `validateBoundary(_:)` | `Validation.swift` | 3-100 points, area 100–1,000,000 m² |
| `calculatePolygonArea(_:)` | `Validation.swift` | Shoelace formula — pure math |
| `contains(coordinate:)` | `Group.swift` | Ray casting algorithm — pure math |

The profanity word list (`ProfanityList.swift`) is also a direct port — just a `Set<String>` of strings.

---

## Algorithms to Port (Point-in-Polygon & Area)

These are pure math with no platform dependencies. Copy from Swift and adjust syntax:

**Point-in-polygon (Ray Casting) — from `Group.swift`:**
```kotlin
fun LocationGroup.contains(coordinate: Coordinate): Boolean {
    val points = boundary
    if (points.size < 3) return false
    var inside = false
    var j = points.size - 1
    for (i in points.indices) {
        val xi = points[i].longitude; val yi = points[i].latitude
        val xj = points[j].longitude; val yj = points[j].latitude
        val intersect = ((yi > coordinate.latitude) != (yj > coordinate.latitude)) &&
            (coordinate.longitude < (xj - xi) * (coordinate.latitude - yi) / (yj - yi) + xi)
        if (intersect) inside = !inside
        j = i
    }
    return inside
}
```

**Polygon area (Shoelace formula) — from `Validation.swift`:**
```kotlin
fun calculatePolygonArea(boundary: List<Coordinate>): Double {
    val n = boundary.size
    if (n < 3) return 0.0
    val earthRadius = 6371000.0
    var area = 0.0
    for (i in boundary.indices) {
        val j = (i + 1) % n
        val lat1 = Math.toRadians(boundary[i].latitude)
        val lat2 = Math.toRadians(boundary[j].latitude)
        val lng1 = Math.toRadians(boundary[i].longitude)
        val lng2 = Math.toRadians(boundary[j].longitude)
        area += lng1 * Math.sin(lat2) - lng2 * Math.sin(lat1)
    }
    return Math.abs(area / 2.0) * earthRadius * earthRadius
}
```

---

## Gradle Dependencies (V1)

```kotlin
// libs.versions.toml
[versions]
firebase-bom = "33.0.0"
compose-bom = "2024.06.00"
hilt = "2.51"
maps-compose = "4.4.1"
play-services-location = "21.3.0"
play-services-auth = "21.2.0"
navigation-compose = "2.7.7"
lifecycle = "2.8.2"
datastore = "1.1.1"
coroutines = "1.8.1"
workmanager = "2.9.0"

[libraries]
firebase-bom = { group = "com.google.firebase", name = "firebase-bom", version.ref = "firebase-bom" }
firebase-auth = { group = "com.google.firebase", name = "firebase-auth-ktx" }
firebase-firestore = { group = "com.google.firebase", name = "firebase-firestore-ktx" }
firebase-messaging = { group = "com.google.firebase", name = "firebase-messaging-ktx" }
firebase-appcheck = { group = "com.google.firebase", name = "firebase-appcheck-playintegrity" }
play-auth = { group = "com.google.android.gms", name = "play-services-auth", version.ref = "play-services-auth" }
play-location = { group = "com.google.android.gms", name = "play-services-location", version.ref = "play-services-location" }
maps-compose = { group = "com.google.maps.android", name = "maps-compose", version.ref = "maps-compose" }
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }
navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation-compose" }
datastore = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }
workmanager = { group = "androidx.work", name = "work-runtime-ktx", version.ref = "workmanager" }
coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
coroutines-play = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-play-services", version.ref = "coroutines" }
```

---

*Last updated: 2026-03-05. See `FIRESTORE_SCHEMA.md` for the data layer contract.*
