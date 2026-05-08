# Persist — Master Design System

The single source of truth for visual + interaction language across **iOS, watchOS, and WidgetKit**. Page-specific overrides live in `design-system/pages/`. If a page file exists, it overrides the corresponding section here.

> Goal: own the "fitness app" category. Award-winning means *legibility under sweat, motion under glance, motivation under fatigue*. Tokens, not screens, are what travel between iPhone, Watch, and Widgets.

---

## 1. Brand Posture

| Axis | Persist |
|------|---------|
| Voice | Coach who's seen it all — direct, calm, never preachy |
| Energy | High contrast > saturated; one strong accent action color |
| Typography | Rounded SF for metrics, system default for prose |
| Motion | Spring physics, never linear; respects Reduced Motion |
| Density | Phones: room to breathe. Watch/Widget: every glyph earns its pixel. |

Anti-patterns: gamified emoji, slogans on hero ("CRUSH IT 💪"), faux-3D weight plates, neon gradients, Spinner-only loading > 300ms.

---

## 2. Color Tokens

All colors live in `Assets.xcassets/Colors/` so light/dark adaptation is automatic. **Never hardcode hex inside views.**

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `BYOWBackground` | `#F3F4F7` | `#0B1220` | App background. Avoid pure white / pure black (OLED smear). |
| `SurfaceCard` | `#FFFFFF` | `#11…` | Card / elevated surfaces. |
| `BYOWOrange` | `#EE4B0F` | `#EE4B0F` | Primary action / streak / "live" emphasis. |
| `BYOWOrangeDark` | `#C53D0C` | `#C53D0C` | Pressed state, gradient pair for avatars. |
| `BYOWOrangeTint` | adaptive | adaptive | 12% wash for selected chips, badges. |
| `BYOWTeal` | `#7EBFC7` | `#7EBFC7` | Recovery / nutrition / secondary action. |
| `BYOWTealTint` | adaptive | adaptive | Bridge-week banner, Nutrition accent backdrop. |
| `InkPrimary` | `#0F172A` | `#F1F5F9` | Body and headline text. ≥4.5:1 against background in both modes. |
| `InkSecondary` | `#334155` | `#CBD5E1` | Subtitles, captions. |
| `InkMuted` | `#64748B` | `#94A3B8` | Hints, ≥3:1. |
| `BYOWDivider` | adaptive | adaptive | Hairlines. |
| `SemanticSuccess / Warning / Error` | adaptive | adaptive | Status only. Always paired with icon — color is never the only signal. |

### Cross-surface guidance

- **Watch:** drop `BYOWBackground` and use pure black for OLED power; keep `InkPrimary` (white) and `BYOWOrange` accent. Cards collapse to background-less rows.
- **Widget (Lock Screen):** monochrome accentable — only use `.widgetAccentable()` modifier on the most important glyph (streak count, percent complete). Color is decided by the user's Lock Screen tint.
- **Widget (Home Screen, large/medium):** full color tokens allowed; respect `.widgetBackground(.byowBackground)`.

---

## 3. Typography

Defined in `DesignSystem/Font+BYOW.swift`. **Always use a token; never `Font.system(...)` inline.**

| Token | Style | Use |
|-------|-------|-----|
| `display` | Largest title, bold | Greeting on Today |
| `title1 / title2 / title3` | Bold → semibold | Section headers, card headlines |
| `body / bodyBold` | Regular / semibold | Default reading |
| `caption` | Caption | Date, metadata |
| `label` | Caption2 + smallCaps + semibold | Pill labels ("BRIDGE WEEK", "REST DAY") |
| `metric` | Title2 rounded + monospaced digits | In-card numbers (sets, reps) |
| `metricLarge` | LargeTitle rounded mono digits | Hero metrics (today's volume) |
| `metricHero` | 64pt rounded mono digits | Logger's active set |
| `watchTitle / watchMetric` | Headline / Title3 rounded | watchOS complication body / metric |
| `widgetCaption` | Caption2 semibold | Widget secondary text |
| `mono` | Subheadline monospaced | Plan IDs / debug |

Rules:

1. Numeric values that update (timer, weight, reps) **must** use a `metric*` token — tabular figures prevent layout jitter.
2. Honor Dynamic Type up to AccessibilityXXL. If a layout breaks, switch to multi-line, never truncate metric values.
3. Headlines max two lines; never truncate critical user data.

---

## 4. Spacing & Radius

`DesignSystem/Spacing.swift` exposes the 4-pt scale: `xxs(4) xs(8) sm(12) md(16) lg(24) xl(32) xxl(48)` plus `cardCorner(16) buttonCorner(12)`. The 8-pt rhythm carries over to Watch and Widget — only the *scale step* used per surface differs:

| Surface | Default outer padding | Card inner padding | Default radius |
|---------|----------------------|--------------------|----------------|
| iPhone (regular) | `md` (16) | `md` (16) | `cardCorner` (16) |
| iPhone (compact / list row) | `sm` (12) | `sm` (12) | 12 |
| Watch | `xs` (8) | `xs` (8) | 12 |
| Widget (small / medium) | `sm` (12) | `xs` (8) | 16 (system) |
| Widget (lock screen) | system | system | system |

**Never** use a non-token spacing value in views.

---

## 5. Elevation

`DesignSystem/Elevation.swift` defines `.flat / .card / .raised / .floating`. Pick one — no ad-hoc `.shadow(...)`.

| Level | Use |
|-------|-----|
| `flat` | Lists, full-bleed sections, watchOS, Widgets. |
| `card` | Standard `.cardStyle()` (already wired). |
| `raised` | WorkoutHeroCard, primary CTA group. |
| `floating` | Sheets, alerts, overlay menus. |

Watch and Widgets force `.flat` — depth is implied by tint contrast and `.widgetAccentable()`.

---

## 6. Motion

`DesignSystem/Motion.swift`:

| Token | Curve | Use |
|-------|-------|-----|
| `Motion.press` | Spring 0.28 / 0.86 | All `Pressable` / `ButtonStyle` press feedback (scale 0.97). |
| `Motion.standard` | Cubic-bezier 0.16, 1, 0.3, 1, 220ms | Card/state changes, chip selection. |
| `Motion.hero` | Spring 0.42 / 0.82 | Sheet / hero entrance. |
| `Motion.pulse` | EaseInOut 1.2s repeating | Live indicators (HR, recording). |

Rules: every Pressable yields haptic feedback (`.sensoryFeedback`), exits run shorter than enters, and **all animations respect `@Environment(\.accessibilityReduceMotion)`** — fall back to opacity-only or no animation.

---

## 7. Component Inventory (iOS)

Already wired:

- `cardStyle()` — `DesignSystem/CardStyle.swift`
- `PrimaryGlassButtonStyle` — `DesignSystem/PrimaryGlassButton.swift` (52pt min height, glass + orange tint)
- `GlassChip` — `DesignSystem/GlassChip.swift`
- `BridgeWeekBadge`, `ErrorCard`, `SkeletonBlock`
- `ProfileAvatarButton` — circular gradient avatar; trailing-toolbar entry to ProfileView
- `ComingSoonScaffold` — placeholder for tabs not yet built (Community, Stats, Nutrition, Support)

Touch / hit-area minimums:

- iPhone: 44×44pt, 8pt spacing.
- Watch: 44×44pt for primary controls; secondary chips can drop to 32×32 if visually clear and gestured by Digital Crown.
- Widget tap targets: only the system-wide widget tap is interactive on Lock Screen; on Home Screen use `Link(destination:)` with deep links into the iOS app.

---

## 8. Navigation

5 top-level tabs (sidebar-adaptable on iPad):

`Community · Stats · Today · Nutrition · Support`

- **Today** is the centered focal tab (flame.fill).
- **Today bar:** no title text. Trailing toolbar holds `ProfileAvatarButton` → pushes `ProfileView` via `NavRoute.profile`. Profile is *not* a top-level tab.
- Each tab uses its own `NavigationStack`. Today's stack handles `.week / .day / .profile` routes.
- Back navigation must restore scroll + filter state (default `NavigationStack` behavior — don't manually reset).
- Deep links: `persist://today`, `persist://today/week/{iso}`, `persist://today/day/{week}/{day}`, `persist://profile`.

---

## 9. Cross-Surface Layout Rules

### iPhone

- Today is the only surface with a hidden navigation title — every other tab shows its name inline.
- Greeting + microcycle label live inside `HomeView`'s scroll content (not the nav bar) so the bar stays clean for Liquid Glass.
- Honor `safeAreaInsets` for notch/Dynamic Island; bottom CTA bars reserve `safeAreaInset(edge: .bottom)`.

### watchOS (planned target)

- Three glances: **Now** (current set or rest timer), **Up Next** (remaining sections), **Streak** (week ring).
- Use `TabView(.verticalPage)` for glance switching; never re-implement a horizontal tab bar.
- Complication families:
  - `circular` — streak ring (% of week complete), tap → app.
  - `rectangular` — next set / weight, tap → logger.
  - `inline` — minimal "Persist · Day 3" text.

### Widgets

- Small: streak number (`.metricLarge`) + "day streak" label, accent-orange ring.
- Medium: today's session — track, day name, top-line metric, primary CTA glyph.
- Large: 7-day strip + completion dots + next session.
- Always include `.containerBackground(for: .widget) { Color.byowBackground }`.
- Always implement Lock Screen variants with `.widgetAccentable()` on the most important shape only.

---

## 10. Accessibility (CRITICAL — non-negotiable)

- Contrast ≥4.5:1 for body text in *both* light and dark mode (already verified for `Ink*` tokens).
- VoiceOver: every metric needs a combined label (`accessibilityElement(children: .combine)`); `ProfileAvatarButton` already labels itself.
- Color is never the only meaning — pair semantic colors with an SF Symbol.
- Every Pressable: visible focus ring, 44pt min, haptic on activation.
- Reduced Motion: replace `Motion.hero` with cross-fade; disable `Motion.pulse`.
- Dynamic Type: all text tokens scale; metric tokens additionally use `monospacedDigit()`.

---

## 11. Anti-Patterns (Do Not)

- ❌ Emoji as a structural icon. Use SF Symbols.
- ❌ Hardcoded hex. Always token.
- ❌ Pure `#000000` background on iOS — use `BYOWBackground` dark variant (`#0B1220`).
- ❌ Loading spinners for >300ms. Use `SkeletonBlock`.
- ❌ Animating `width / height / top / left`. Use `transform / opacity` only.
- ❌ Profile as a top-level tab. It lives in Today's trailing toolbar.
- ❌ Title text on Today's nav bar. The greeting is inside content.

---

## 12. Reasoning Behind Style Choice

Searched via `ui-ux-pro-max` skill (`--design-system "fitness sports athletic training"`). Adopted from results:

- **Vibrant & Block-based** pattern (energetic + high color contrast) — matched our existing orange-accent tokens.
- **Modern Dark (Cinema Mobile)** style for dark mode — informed our motion easing (`Bezier(0.16,1,0.3,1)`), spring damping, blur usage on toolbars, anti-pattern rules (no `#000000`, animated ambient, glass headers).
- **Barlow Condensed / Barlow** font pairing was *rejected* in favor of system SF (rounded for metrics) — keeps watchOS, Dynamic Type, and Liquid Glass parity. Custom fonts on watchOS hurt legibility under sweat / motion.
