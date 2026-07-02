# Asset Sizing Policy & Optimization Guidelines

## Quick Policy Summary

This document defines acceptable asset sizes and optimization strategies for ChronoSpark Flutter app.

### Size Limits by Category

| Category | Max Size | Target | Rationale |
|----------|----------|--------|-----------|
| **Icons** | 300 KB | < 100 KB | Lightweight, fast decode, low GPU memory |
| **Backgrounds** | 1.5 MB | < 800 KB | Gradients, minimize decode time |
| **Overlays/Particles** | 300 KB | < 150 KB | Frequently rendered, high jank risk |
| **Audio** | 1 MB per file | 200-500 KB | Compressed codec (AAC, MP3) |
| **Fonts** | 500 KB per font | 300 KB | Subset characters, strip unused glyphs |
| **Total Assets Bundle** | 20 MB | 15 MB | App package size, startup load |

## Optimization Techniques

### Images (PNG/JPG)

1. **WebP Conversion** (Priority: HIGH)
   - Reduces 40-50% vs PNG at same quality
   - All backgrounds and large icons: convert to WebP + fallback PNG
   - Command: `cwebp -q 80 input.png -o output.webp`
   - Use `Image.memory()` with conditional decoding or `pubspec.yaml` asset variants

2. **Resolution Downsampling** (Priority: HIGH for backgrounds)
   - Backgrounds used as screens are 1080px wide max
   - Current: chronocreator_bg.png 3.12 MB → likely 2000+ px
   - Resize to 1200x1200 max
   - Command: `convert input.png -resize 1200x1200 output.png`

3. **PNG Optimization** (Priority: MEDIUM)
   - Strip metadata, compress better
   - Command: `pngquant --quality 70-90 input.png --output output.png`
   - Or: `pngcrush -res 72 input.png output.png`

4. **Icon Optimization** (Priority: HIGH)
   - Current: Multiple 1+ MB icon files (unusual)
   - Investigate: are these actually raster icons or vectors exported as PNG?
   - Action: Convert to SVG + `flutter_svg` package OR resize to 200x200 max for raster
   - Command: `convert icon.png -resize 200x200 icon_small.png`

### Audio Files

1. **Codec Selection** (Priority: HIGH)
   - WAV (uncompressed) should be converted to AAC or MP3
   - system_processing.wav (0.34 MB) → AAC at 64-96 kbps target
   - Command: `ffmpeg -i input.wav -c:a aac -b:a 96k output.m4a`

2. **Bitrate** (Priority: MEDIUM)
   - Notification sounds: 64 kbps sufficient
   - UI feedback: 96 kbps max
   - Background ambient: 128 kbps max

### Fonts

1. **Subsetting** (Priority: MEDIUM)
   - Check if Inter_18pt-Black.ttf includes unused glyphs
   - Use `fonttools` or online subsetter for target character set
   - Example: keep only Latin + Extended Latin, strip CJK if unused

### Flutter Image Asset Configuration

Update `pubspec.yaml` to enable caching and decode-on-demand:

```yaml
flutter:
  assets:
    - assets/backgrounds/
    - assets/icons/
    - assets/audio/
    - assets/data/
    - assets/fonts/
    - assets/legal/
```

Use `Image.asset()` with `fit`, `width`, `height` to constrain GPU memory:

```dart
Image.asset(
  'assets/backgrounds/chronocreator_bg.png',
  fit: BoxFit.cover,
  width: 1080,
  height: 1920,
  filterQuality: FilterQuality.low, // Reduce decode jank
);
```

## Current Issues (Measured)

### Immediate Priorities (Size > 1.5 MB)

1. **chronocreator_bg.png** (3.12 MB)
   - Likely 2000+ px raster, single-use background
   - Target: 1.5 MB via WebP + downsampling to 1200px
   - Estimated Savings: ~1.2 MB (38% reduction)

2. **settings_bg.png** (1.47 MB)
   - Target: 800 KB via WebP + quality reduction
   - Estimated Savings: ~600 KB (40% reduction)

3. **nexus_bg.png** (1.42 MB)
   - Target: 800 KB (same approach)
   - Estimated Savings: ~600 KB

4. **theme_icon.png** (1.43 MB)
   - Likely a raster icon; convert to SVG if possible
   - If must be raster, downsize to 256x256 (50 KB target)
   - Estimated Savings: ~1.3 MB (90% reduction)

5. **home.png** (1.42 MB)
   - Similar pattern; likely icon or home screen preview
   - Downsize to 300x300 if icon, or apply WebP if background
   - Estimated Savings: ~800 KB

### Secondary Issues (Size 300-1000 KB)

- Multiple icons in 300-500 KB range → batch WebP conversion
- Audio files in WAV format → convert to AAC 96 kbps

## Execution Steps

### Phase 1: Analyze & Report (Automated)
```bash
dart run scripts/analyze_assets.dart
# Outputs: scripts/asset_analysis_report.json + console summary
```

### Phase 2: Image Optimization (External Tools)
1. Install tools: `brew install imagemagick cwebp`
2. For each file > 1 MB:
   - Downsize to target resolution
   - Convert to WebP
   - Keep fallback PNG for older Android/iOS
3. Update asset references in code if paths change

### Phase 3: Font & Audio (As Needed)
1. Subset fonts if unused glyphs detected
2. Convert WAV to AAC using FFmpeg

### Phase 4: Measurement & Validation
```bash
# Measure new bundle size
flutter build apk --release && du -sh build/app/outputs/flutter-apk/app-release.apk

# Check startup time
flutter run --profile && # Profile panel shows Time to Persistent Frame
```

## Success Metrics

- **Total Assets**: < 15 MB (currently ~28 MB, target 47% reduction)
- **Largest Background**: < 1 MB (currently 3.12 MB, target 68% reduction)
- **Icon Assets**: < 100 KB each (currently many > 500 KB, target 80% reduction)
- **Startup Time**: Time to Persistent Frame < 2s on mid-range device (Pixel 3a / iPhone 8)
- **GPU Memory**: Asset decode footprint < 50 MB (critical for low-end phones)

## Notes

- Keep WebP + PNG fallback for broad device support (older Android versions may not support WebP)
- Profile on actual devices, not just emulator (memory pressure differs)
- Re-run analyze_assets.dart after optimization to validate improvements
- Consider lazy-loading screens: defer background assets for tabs not yet visited
