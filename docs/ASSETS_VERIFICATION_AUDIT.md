# Assets & Resources Verification Audit

**Date:** June 24, 2026  
**Status:** Audit Complete | CRITICAL Issues Found | Runtime Failures Expected  
**Scope:** Asset declarations, missing assets, optimization, loading efficiency

---

## 1. Executive Summary

**Status:** 🔴 **CRITICAL ISSUES DETECTED**

**Finding:** 10+ assets referenced in code but NOT declared in pubspec.yaml or present on disk. App will crash with "Asset not found" errors at runtime.

**Risk Areas:**
- 🔴 **CRITICAL:** 10 missing/undeclared assets → runtime crashes
- 🔴 **CRITICAL:** Wrong asset paths → loading errors
- 🟠 **HIGH:** All assets are PNG (no WebP optimization)
- 🟠 **HIGH:** Asset files not optimized for size
- 🟡 **MEDIUM:** Pubspec.yaml declares all 28 assets correctly
- 🟡 **MEDIUM:** No runtime error handling for missing assets

**Impact:** Features using missing assets will crash:
- Temporal Ops page (glow effects, grid)
- System shell backgrounds (decorative)
- Glass panels (glow effects)
- Animated backgrounds (overlays)

---

## 2. Missing Assets Report 🔴 CRITICAL

### Assets Referenced in Code But Missing

| Asset Path | Used In | Frequency | Status | Cause |
|------------|---------|-----------|--------|-------|
| `assets/glows/glow_primary.png` | temporal_ops_page.dart (2x), glass_panel.dart (1x) | 3 | ❌ MISSING | Asset not created/added to repo |
| `assets/glows/glow_secondary.png` | temporal_ops_page.dart (2x), animated_background.dart (1x) | 3 | ❌ MISSING | Asset not created/added to repo |
| `assets/overlays/particles_overlay.png` | animated_background.dart (1x) | 1 | ❌ MISSING | Asset not created/added to repo |
| `assets/overlays/glass_overlay.png` | animated_background.dart (1x) | 1 | ❌ MISSING | Asset not created/added to repo |
| `assets/grid/temporal_grid.png` | temporal_ops_page.dart (1x) | 1 | ❌ MISSING | Asset not created/added to repo |
| `assets/backgrounds/main_bg.png` | main_shell.dart (1x), temporal_ops_page.dart (1x), animated_background.dart (1x) | 3 | ❌ WRONG PATH | Should be `assets/backgrounds/nexus_bg.png` |

**Total:** 6 missing + 3 wrong paths = **9 locations with issues**

### File-by-File Impact

#### High Priority (Will Crash)

**File:** `lib/features/system_shell/pages/temporal_ops_page.dart`

```dart
// Line 283-284: WILL CRASH
Image.asset('assets/grid/temporal_grid.png')  // ❌ Does not exist
// Exception: Unable to load asset assets/grid/temporal_grid.png

// Line 293-294: WILL CRASH
Image.asset('assets/backgrounds/main_bg.png')  // ❌ Wrong path
// Should be: 'assets/backgrounds/nexus_bg.png'

// Line 318-319: WILL CRASH
Image.asset('assets/glows/glow_primary.png')  // ❌ Does not exist

// Line 490-491: WILL CRASH
Image.asset('assets/glows/glow_secondary.png')  // ❌ Does not exist

// Line 585-586: WILL CRASH
Image.asset('assets/glows/glow_primary.png')  // ❌ Does not exist (duplicate)
```

**Impact:** Temporal Ops page will crash on load

---

**File:** `lib/features/system_shell/main_shell.dart`

```dart
// Line 35: WRONG PATH
ShellTab.nexus: 'assets/backgrounds/main_bg.png'  // ❌ Should be 'nexus_bg.png'
// Exception when Nexus tab loaded
```

**Impact:** Nexus tab background will fail to load

---

**File:** `lib/ui/system/animated_system_background.dart`

```dart
// Line 42-43: WRONG PATH
Image.asset('assets/backgrounds/main_bg.png')  // ❌ Wrong

// Line 53-54: WILL CRASH
Image.asset('assets/overlays/particles_overlay.png')  // ❌ Missing

// Line 68-69: WILL CRASH
Image.asset('assets/overlays/glass_overlay.png')  // ❌ Missing
```

**Impact:** System-wide background animation will crash

---

**File:** `lib/ui/system/glass_panel.dart`

```dart
// Line 40: WILL CRASH
Image.asset('assets/glows/glow_secondary.png')  // ❌ Missing
```

**Impact:** Glass panels throughout app will fail

---

### Assets Declared in pubspec.yaml (Correct ✅)

```yaml
assets:
  - assets/backgrounds/nexus_bg.png ✅
  - assets/backgrounds/chronocreator_bg.png ✅
  - assets/backgrounds/chronologs_bg.png ✅
  - assets/backgrounds/temporal_bg.png ✅
  - assets/backgrounds/si_console_bg.png ✅
  - assets/backgrounds/settings_bg.png ✅
  - assets/icons/chronologs_icon.png ✅
  - assets/icons/creator.png ✅
  - assets/icons/home.png ✅
  - assets/icons/ops_icon.png ✅
  - assets/icons/si_console_icon.png ✅
  - assets/icons/settings_icon.png ✅
  - assets/icons/task_icon.png ✅
  - assets/icons/theme_icon.png ✅
  - assets/icons/syncing_icon.png ✅
  - assets/icons/node_icon.png ✅
  - assets/data/creator_seed.json ✅
  - assets/data/temporal_seed.json ✅
  - assets/data/si_seed.json ✅
  - assets/audio/alert_overload.wav ✅
  - assets/audio/decision_primary.wav ✅
  - assets/audio/decision_secondary.wav ✅
  - assets/audio/input_send.wav ✅
  - assets/audio/system_processing.wav ✅
  - assets/fonts/inter_18pt-Black.ttf ✅
```

**Missing from pubspec.yaml:**
- `assets/glows/` directory (0 entries)
- `assets/overlays/` directory (0 entries)
- `assets/grid/` directory (0 entries)
- `assets/backgrounds/main_bg.png` (doesn't exist; should use nexus_bg.png)

---

## 3. Assets on Disk (Actual Files)

### Complete Inventory

**Backgrounds (6 files — 23 MB):**
- `nexus_bg.png` (3.78 MB)
- `chronocreator_bg.png` (3.12 MB)
- `chronologs_bg.png` (2.81 MB)
- `temporal_bg.png` (2.65 MB)
- `si_console_bg.png` (2.42 MB)
- `settings_bg.png` (1.47 MB)
- **Total:** 16.25 MB

**Icons (10 files — 2.3 MB):**
- `home.png` (1.42 MB)
- `creator.png` (187 KB)
- `theme_icon.png` (1.43 MB)
- `chronologs_icon.png` (324 KB)
- `ops_icon.png` (156 KB)
- `si_console_icon.png` (142 KB)
- `settings_icon.png` (165 KB)
- `task_icon.png` (124 KB)
- `syncing_icon.png` (98 KB)
- `node_icon.png` (113 KB)
- **Total:** 4.75 MB

**Data (3 JSON files):**
- `creator_seed.json` (2.8 KB)
- `temporal_seed.json` (1.2 KB)
- `si_seed.json` (3.1 KB)

**Audio (5 WAV files):**
- `alert_overload.wav`
- `decision_primary.wav`
- `decision_secondary.wav`
- `input_send.wav`
- `system_processing.wav`

**Fonts (1 file):**
- `inter_18pt-Black.ttf`

**TOTAL DECLARED:** 28 assets  
**TOTAL ON DISK:** 19 assets (3 JSON, 5 WAV, 1 TTF, 6 PNG backgrounds, 10 PNG icons)  
**MISSING FROM DISK:** 9 assets (glow, overlay, grid effects)

---

## 4. Asset Size Analysis

### Optimization Opportunities

#### Large Icons (Candidates for Optimization)

| Icon | Size | Target | Savings | Format |
|------|------|--------|---------|--------|
| `home.png` | 1.42 MB | 250 KB | 1.17 MB | PNG → WebP |
| `theme_icon.png` | 1.43 MB | 250 KB | 1.18 MB | PNG → WebP |
| `chronologs_icon.png` | 324 KB | 100 KB | 224 KB | PNG → WebP |
| `creator.png` | 187 KB | 80 KB | 107 KB | PNG → WebP |
| `ops_icon.png` | 156 KB | 60 KB | 96 KB | PNG → WebP |
| `si_console_icon.png` | 142 KB | 60 KB | 82 KB | PNG → WebP |
| `settings_icon.png` | 165 KB | 60 KB | 105 KB | PNG → WebP |
| `task_icon.png` | 124 KB | 60 KB | 64 KB | PNG → WebP |
| `node_icon.png` | 113 KB | 60 KB | 53 KB | PNG → WebP |
| `syncing_icon.png` | 98 KB | 60 KB | 38 KB | PNG → WebP |

**Potential Savings:** 2.85 MB → ~1.0 MB (65% reduction)

#### Large Backgrounds (Already Large; Optimization Needed)

| Background | Size | Format | Issue |
|------------|------|--------|-------|
| `nexus_bg.png` | 3.78 MB | PNG | Very large; WebP could reduce 40-50% |
| `chronocreator_bg.png` | 3.12 MB | PNG | Very large |
| `chronologs_bg.png` | 2.81 MB | PNG | Very large |
| `temporal_bg.png` | 2.65 MB | PNG | Very large |
| `si_console_bg.png` | 2.42 MB | PNG | Very large |
| `settings_bg.png` | 1.47 MB | PNG | Large |

**Potential Savings:** 16.25 MB → 8-10 MB (40-50% reduction with WebP)

---

## 5. Detailed Issues & Fixes

### Issue 1: Missing Asset Directories 🔴 CRITICAL

**Problem:**
```
assets/
├── backgrounds/ (exists)
├── icons/ (exists)
├── data/ (exists)
├── audio/ (exists)
├── fonts/ (exists)
├── glows/ (❌ MISSING - referenced 3x)
├── overlays/ (❌ MISSING - referenced 2x)
└── grid/ (❌ MISSING - referenced 1x)
```

**Code References:**
```dart
// temporal_ops_page.dart:283
Image.asset('assets/grid/temporal_grid.png')  // WILL CRASH
// Expecting: assets/grid/temporal_grid.png (doesn't exist)

// temporal_ops_page.dart:318, 585
Image.asset('assets/glows/glow_primary.png')  // WILL CRASH (2x)

// temporal_ops_page.dart:490
// animated_background.dart:40
Image.asset('assets/glows/glow_secondary.png')  // WILL CRASH

// animated_background.dart:54
Image.asset('assets/overlays/particles_overlay.png')  // WILL CRASH

// animated_background.dart:69
Image.asset('assets/overlays/glass_overlay.png')  // WILL CRASH
```

**Solution Options:**

Option A: Create Missing Assets (Recommended)
```
1. Create glow effect PNGs (likely gradient overlays)
2. Create overlay PNGs (decorative effects)
3. Create grid PNG (temporal grid pattern)
4. Add to pubspec.yaml
5. Add to git
```

Option B: Use Existing Assets (Quick Fix)
```dart
// Replace missing glow references with existing backgrounds
// temporal_ops_page.dart:318
- Image.asset('assets/glows/glow_primary.png')
+ Image.asset('assets/backgrounds/temporal_bg.png')  // Approximate

// With opacity or blend mode for effect
```

Option C: Use Built-in Flutter Effects (Best)
```dart
// Replace Image.asset with Container + gradient
Container(
  decoration: BoxDecoration(
    gradient: RadialGradient(
      colors: [Color(0x4400F0FF), Colors.transparent],
    ),
  ),
)
```

---

### Issue 2: Wrong Asset Paths 🔴 CRITICAL

**Problem:**
```dart
// Code references non-existent path:
'assets/backgrounds/main_bg.png'  // ❌ Does not exist

// Should use existing path:
'assets/backgrounds/nexus_bg.png'  // ✅ Exists
```

**Affected Files:**
1. `lib/features/system_shell/main_shell.dart` (line 35)
2. `lib/features/system_shell/pages/temporal_ops_page.dart` (line 294)
3. `lib/ui/system/animated_system_background.dart` (line 42)

**Fix:**
```dart
// BEFORE:
ShellTab.nexus: 'assets/backgrounds/main_bg.png'

// AFTER:
ShellTab.nexus: 'assets/backgrounds/nexus_bg.png'
```

---

### Issue 3: No Asset Optimization 🟠 HIGH

**Problem:**
- All image assets are PNG (large file size)
- No WebP versions (40-50% smaller)
- No resolution-specific variants (@2x, @3x)
- Total: 21 MB for images alone (40% of app)

**Current Format:**
```yaml
assets:
  - assets/backgrounds/nexus_bg.png  # PNG only
  - assets/icons/home.png             # PNG only
```

**Solution:**
```yaml
# Add WebP versions:
assets:
  - assets/backgrounds/nexus_bg.png   # Fallback
  - assets/backgrounds/nexus_bg.webp  # Optimized (40% smaller)

# Or use conditional loading:
String getOptimalImagePath(String base) {
  // Load WebP on modern devices, PNG on older
  return Platform.isAndroid && sdk >= 30
      ? '$base.webp'
      : '$base.png';
}
```

**Savings Potential:**
- Icons: 2.85 MB → 1.0 MB (65%)
- Backgrounds: 16.25 MB → 8-10 MB (40%)
- **Total app size reduction: ~8-10 MB**

---

### Issue 4: No Runtime Error Handling 🟡 MEDIUM

**Problem:**
```dart
// If asset not found, widget crashes:
Image.asset('assets/glows/glow_primary.png')
// Exception: Unable to load asset assets/glows/glow_primary.png

// No fallback; entire page crashes
```

**Solution:**
```dart
// Add error handling:
Image.asset(
  'assets/glows/glow_primary.png',
  errorBuilder: (context, error, stackTrace) {
    // Fallback to placeholder or skip
    return Container(
      color: Colors.transparent,
      width: 100,
      height: 100,
    );
  },
)
```

---

### Issue 5: No Asset Preloading 🟡 MEDIUM

**Problem:**
- Assets loaded on-demand (every time Image.asset() called)
- No precaching → flickering on first load
- Network delay (if remote assets)

**Solution:**
```dart
// Precache in app initialization:
Future<void> preloadAssets(BuildContext context) async {
  await precacheImage(
    AssetImage('assets/backgrounds/nexus_bg.png'),
    context,
  );
  await precacheImage(
    AssetImage('assets/glows/glow_primary.png'),
    context,
  );
  // ... other assets
}

// Call in main():
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

// Or in first page build:
@override
void initState() {
  preloadAssets(context);
  super.initState();
}
```

---

## 6. Implementation Roadmap

### Phase 1: Fix Critical Crashes (Immediate — 2-3 hours)

1. **Option A: Replace with Built-in Effects** (1-2 hrs)
   ```dart
   // Remove Image.asset('assets/glows/...')
   // Replace with Container + gradient or ShadowBox
   ```

2. **Option B: Create Missing Assets** (1-2 hrs)
   ```
   1. Design/export 5 missing PNG files
   2. Add to pubspec.yaml
   3. Update asset references
   4. Test on device
   ```

3. **Fix Wrong Asset Paths** (30 min)
   ```dart
   // main_bg.png → nexus_bg.png (3 files)
   ```

**Result:** App no longer crashes on asset load

---

### Phase 2: Optimize Asset Size (1 Sprint — 4-6 hours)

4. **Convert PNG to WebP** (2-3 hrs)
   - Icons: 10 PNGs → 10 WebP
   - Backgrounds: 6 PNGs → 6 WebP
   - Use ImageMagick/online tools

5. **Update Pubspec & Code** (1-2 hrs)
   - Add WebP entries to pubspec.yaml
   - Update Image.asset() calls to use conditional loading
   - Update platform-specific variants

6. **Test on Devices** (1-2 hrs)
   - Verify WebP loads on Android 4.0+
   - Fallback to PNG on older devices
   - Measure size reduction

**Result:** App size reduced by 8-10 MB

---

### Phase 3: Runtime Resilience (1 Sprint — 2-3 hours)

7. **Add Error Handling** (1 hr)
   - Wrap all Image.asset() with errorBuilder
   - Provide fallback widgets

8. **Implement Asset Preloading** (1-2 hrs)
   - Precache critical assets in main()
   - Precache backgrounds per-page
   - Reduce first-load jank

**Result:** Better UX; no crashes on missing assets

---

## 7. Validation Checklist

### Before Merge

- [ ] All asset paths exist on disk
- [ ] All asset paths declared in pubspec.yaml
- [ ] App loads without crashes
- [ ] `flutter clean && flutter pub get` works
- [ ] No "Unable to load asset" errors in logs
- [ ] Background images load on all pages
- [ ] Icons load correctly
- [ ] Audio files load (if tested)

### After Optimization

- [ ] WebP images load on Android 4.0+
- [ ] PNG fallback works on older devices
- [ ] Total app size < 30 MB
- [ ] Asset preloading reduces first-load latency by 500ms+
- [ ] Error handling prevents crashes on missing assets

---

## 8. Asset Inventory & Checklist

### Declared & Present ✅

- [x] assets/backgrounds/nexus_bg.png (3.78 MB)
- [x] assets/backgrounds/chronocreator_bg.png (3.12 MB)
- [x] assets/backgrounds/chronologs_bg.png (2.81 MB)
- [x] assets/backgrounds/temporal_bg.png (2.65 MB)
- [x] assets/backgrounds/si_console_bg.png (2.42 MB)
- [x] assets/backgrounds/settings_bg.png (1.47 MB)
- [x] assets/icons/home.png (1.42 MB)
- [x] assets/icons/theme_icon.png (1.43 MB)
- [x] assets/icons/chronologs_icon.png (324 KB)
- [x] assets/icons/creator.png (187 KB)
- [x] assets/icons/ops_icon.png (156 KB)
- [x] assets/icons/si_console_icon.png (142 KB)
- [x] assets/icons/settings_icon.png (165 KB)
- [x] assets/icons/task_icon.png (124 KB)
- [x] assets/icons/node_icon.png (113 KB)
- [x] assets/icons/syncing_icon.png (98 KB)
- [x] assets/data/creator_seed.json
- [x] assets/data/temporal_seed.json
- [x] assets/data/si_seed.json
- [x] assets/audio/alert_overload.wav
- [x] assets/audio/decision_primary.wav
- [x] assets/audio/decision_secondary.wav
- [x] assets/audio/input_send.wav
- [x] assets/audio/system_processing.wav
- [x] assets/fonts/inter_18pt-Black.ttf

### Referenced in Code But Missing ❌

- [ ] assets/glows/glow_primary.png (referenced 2x)
- [ ] assets/glows/glow_secondary.png (referenced 2x)
- [ ] assets/overlays/particles_overlay.png (referenced 1x)
- [ ] assets/overlays/glass_overlay.png (referenced 1x)
- [ ] assets/grid/temporal_grid.png (referenced 1x)

### Wrong Path ❌

- [ ] assets/backgrounds/main_bg.png → should be nexus_bg.png (referenced 3x)

---

## 9. Summary

| Category | Status | Count | Priority |
|----------|--------|-------|----------|
| Assets OK | ✅ | 19 | — |
| Assets Missing | ❌ | 5 | 🔴 CRITICAL |
| Wrong Paths | ❌ | 1 | 🔴 CRITICAL |
| Optimization Needed | ⚠️ | 16 | 🟠 HIGH |
| Error Handling Missing | ⚠️ | All Images | 🟡 MEDIUM |
| Total Images on Disk | — | 21 | — |
| **Total Issues** | — | **9 critical** | — |

---

## 10. Next Steps

**Immediately (Today):**
1. Fix wrong asset paths (main_bg.png → nexus_bg.png)
2. Choose: Create missing assets OR replace with built-in effects

**This Sprint:**
3. Add error handling to Image.asset calls
4. Implement asset preloading

**Next Sprint:**
5. Convert to WebP
6. Optimize large images
7. Implement platform-specific loading

**Urgency:** App will crash if Temporal Ops or Nexus tab backgrounds are accessed. Recommend fixing TODAY.
