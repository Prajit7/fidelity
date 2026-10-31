# fidelity

**Keep your app smooth on cheap phones without making it ugly on good ones.**

Glassy blur, soft shadows and particle effects look great on a flagship
phone and make a budget Android lag. `fidelity` measures real frame timings
while your app runs, and steps those effects down when frames start
dropping, then back up once the device recovers.

```
 high   ──▶ jank detected ──▶  medium  ──▶ still janky ──▶  low
  ▲                                                          │
  └──────────── smooth for a while (cautiously) ◀────────────┘
```

* **Reacts live**, not once at launch. A phone that's fine when cold may
  struggle after ten minutes of gaming or while charging.
* **Uses the real frame budget**: 16.7 ms at 60 Hz, 8.3 ms at 120 Hz.
* **Doesn't flicker**: steps down fast, steps up slowly, and backs off
  further each time an upgrade fails.
* **Pure Dart, no platform code, no dependencies.**

## Install

```yaml
dependencies:
  fidelity: ^0.1.0
```

## Quick start

Wrap your app once:

```dart
void main() => runApp(const FidelityScope(child: MyApp()));
```

Use the drop-in widgets:

```dart
AdaptiveBlur(
  sigma: 24,
  tint: Colors.white24,
  fallbackColor: Colors.white.withValues(alpha: 0.9), // used at low
  borderRadius: BorderRadius.circular(20),
  child: const Text('Frosted card'),
)

AdaptiveDecoratedBox(            // shadows soften at medium, vanish at low
  decoration: BoxDecoration(boxShadow: [...]),
  child: ...,
)
```

Or decide yourself:

```dart
final level = Fidelity.of(context);           // rebuilds on change

final particles = level.pick(high: 300, medium: 100, low: 0);

FidelitySwitch(
  high: const LottieHero(),
  low: const StaticHeroImage(),
)

FidelityBuilder(
  builder: (context, level, child) =>
      level >= FidelityLevel.medium ? ShaderBackground(child: child) : child!,
  child: content,
)
```

## What each level means

That's up to you. A sensible rule of thumb:

| Level    | Blur          | Shadows        | Motion & effects          |
|----------|---------------|----------------|---------------------------|
| `high`   | full          | full           | everything                |
| `medium` | lighter       | one, softer    | fewer particles, no shaders |
| `low`    | solid panels  | none           | essentials only           |

## Plugging in other signals

The governor only sees frame timings. Give it anything else through
`ceiling`, an upper limit on the measured level:

```dart
final governor = FidelityGovernor();

// battery_plus, a thermal plugin, a "Reduce effects" switch in settings...
governor.ceiling = batterySaverOn ? FidelityLevel.medium : null;

runApp(FidelityScope.value(governor: governor, child: const MyApp()));
```

## Debug overlay

```dart
MaterialApp(
  builder: (context, child) =>
      FidelityDebugOverlay(enabled: kDebugMode, child: child!),
)
```

It shows a pill like `MEDIUM · auto · jank 18% · 16.7ms`. Tap it to lock a
level (auto → low → medium → high → auto) so you can design every level
without needing a slow phone.

## Tuning

```dart
FidelityScope(
  min: FidelityLevel.medium,          // never go below medium
  policy: const FidelityPolicy(
    windowSize: 60,                   // frames per measurement window
    downgradeJankRatio: 0.15,         // ≥15% janky frames → step down
    upgradeJankRatio: 0.03,           // ≤3% → counts as a stable window
    stableWindowsToUpgrade: 4,        // stable windows before stepping up
    cooldown: Duration(seconds: 2),   // ignore frames right after a change
  ),
  child: const MyApp(),
)
```

A frame counts as janky when its build (UI thread) or raster time goes over
the frame budget. Measurement pauses while the app is in the background, and
the first frames after resume are skipped.

## Testing your app

`Fidelity.of` returns `high` when there's no `FidelityScope`, so existing
widget tests keep working. To test a specific level:

```dart
final governor = FidelityGovernor()..lock(FidelityLevel.low);
await tester.pumpWidget(
  FidelityScope.value(governor: governor, child: const MyApp()),
);
```

## Example

`example/` has a glass-style demo with a **stress** slider that adds work
to every frame, so you can watch the levels change live.
