# Vibe-Trading Mobile (Flutter)

Mobile (iOS / Android) client for Vibe-Trading, ported from the React/Vite web
frontend per `docs/frontend-flutter.md`. Mobile-first redesign — not a 1:1 web
port.

- **Toolchain:** Flutter 3.44.6 (stable) · Dart 3.12.2
- **State:** Riverpod 2 · **Routing:** go_router · **HTTP/SSE:** dio (+ hand-written SSE client)
- **Charts:** fl_chart 1.x (native candlestick + overlays) + CustomPainter (heatmap / regime)
- **Rich text:** flutter_markdown + flutter_math_fork (LaTeX)
- **Safety:** flutter_secure_storage (Keychain/Keystore), local_auth (biometric mandate confirm)

## Phases (all implemented)

| Phase | Surface |
|---|---|
| P0 | App shell, theme (HSL tokens, light/dark), go_router bottom-nav, dio + SSE client, secure storage, ARB i18n (en/zh/ja/ko/ar), API client 1:1 |
| P1 | Agent chat: session mgmt, streaming (`text_delta`/`reasoning_delta`), tool cards + ETA, ThinkingTimeline, Goal lifecycle, SwarmStatus cards, WelcomeScreen, Composer (send/newline split, IME-safe), kill switch, mandate proposal + biometric commit, connection status |
| P2 | Backtest viz: candlestick (MA/EMA/BOLL overlays + vol/MACD/RSI/KDJ sub-charts + pinch-zoom), equity/drawdown, validation panel, RunDetail (6 tabs, per-symbol lazy load, trades/metrics CSV), Compare, Reports |
| P3 | Alpha Zoo (browse / detail LaTeX / bench SSE / compare SSE), correlation heatmap + regime timeline (CustomPainter) |
| P4 | Live runtime monitor, Settings (LLM / data-source / channels), file upload, Shadow report viewer (WebView) |
| P5 | Pine Script viewer (copy/share/docs). Push / deep-link / offline cache / cert pinning documented as future optional. |

The backend is unchanged — this is a standard HTTP + SSE client of the existing
REST/SSE API (`agent/src/api/*`). Mobile SSE carries `Authorization: Bearer`
directly (no browser ticket detour).

## Run

```bash
cd frontend-app
flutter pub get
flutter run                       # device/emulator
flutter build apk --debug         # Android (Windows host OK)
# iOS final build/signing requires macOS + Xcode.
```

On first launch, set the backend **Base URL** (e.g. `http://10.0.2.2:8899` for
the Android emulator → host loopback) and optional **API key** in Settings.

## Notes / environment caveats

- **Android build toolchain:** the Flutter 3.44 template pins AGP 9 + Gradle 9,
  but the Flutter migrator re-applies `android.newDsl=false` (legacy DSL), which
  AGP 9 rejects, and `androidx.core:1.18` pulls in by transitive deps need
  AGP ≥ 8.9. This project pins **AGP 8.13.0 / Gradle 8.13 / Kotlin 2.1.0**
  (compatible with `newDsl=false` and modern AndroidX). The Gradle distribution
  is fetched from the **Tencent mirror** (`gradle-wrapper.properties`) because
  `services.gradle.org` times out on constrained networks; swap back to the
  official URL on unconstrained networks.
- `MainActivity` uses `FlutterFragmentActivity` (required by `local_auth`).
- Debug builds allow cleartext to local/LAN backends (`usesCleartextTraffic` /
  `NSAppTransportSecurity`); **revert to HTTPS + pinning for release**.
- `flutter analyze` is clean (0 issues) across all phases.
