# Laser Chess

A real-time multiplayer arcade game built in Godot 4.5 and shipped for web and Android. Players survive an ever-escalating hazard board across three ranked time controls while competing on a global leaderboard.

**[Play in Browser](https://christoph.itch.io/laser-chess)** &nbsp;·&nbsp; **[Android APK / .aab](Export/laserchess.zip)**

---

## Tech Stack

| Layer | Technology |
|---|---|
| Engine | Godot 4.5 (GDScript) |
| Multiplayer | WebSocket server (Node.js, hosted on Render) |
| Backend | Firebase Realtime Database (europe-west1) |
| Export targets | HTML5/WASM · Windows · Android |

---

## Features

### Ranked Multiplayer
- WebSocket matchmaking with Bullet (1:30), Blitz (3:00), and Rapid (5:00) time controls
- Server-issued match seed for deterministic, reproducible hazard sequences — both clients run identical game logic from the same seed, making cheating detectable
- ELO rating system (K = 32) with per-mode tracking; client-side fallback calculates ELO locally when the server returns 0
- Live opponent position ghost and real-time score sync over WebSocket
- 25-second heartbeat ping to keep Render's proxy from dropping idle connections

### Game Systems
- 6×6 grid with WASD (desktop) and D-pad/swipe (mobile) controls
- Three hazard types with distinct movement logic: Rook (row/col sweep), Bishop (diagonal), Knight (L-jump with pre-warning flash)
- Camera shake, pooled SFX via `SoundManager` autoload, seeded hazard spawner

### Cosmetic Shop
- 38 purchasable hats with per-hat sprite tweaks (position, scale, rotation) defined in a data table
- In-game currency earned by playing; shop UI with owned/equipped/locked states
- Equipped hat synced to opponent's client through the match server

### Profile & Leaderboard
- Player profiles persisted to Firebase with local JSON fallback (`user://player.json`) when offline
- Per-mode W/L/D records and win rate
- Leaderboard supports ELO and solo high-score tabs; mini preview embedded in the main menu

### Responsive UI
- Separate desktop (1920×1080, three-panel layout) and portrait mobile layouts built in code
- Safe-area aware margins, touch-scrollable shop/settings panels, full-width tap targets on mobile
- All UI constructed procedurally in GDScript — no external UI framework

---

## Architecture

```
scripts/
├── network_manager.gd   # WebSocket client autoload — matchmaking, score relay, heartbeat
├── player_data.gd       # Player state autoload — stats, shop, Firebase CRUD, local fallback
├── game_settings.gd     # App-wide settings autoload — volume, control scheme, color prefs
├── ranked_match.gd      # Match scene — state machine (CONNECTING→LOBBY→COUNTDOWN→PLAYING→RESULTS)
├── game_board.gd        # Grid logic, collision, respawn
├── hazard_spawner.gd    # Seeded hazard factory, difficulty scaling
├── player.gd            # Player movement, hat overlay, death/respawn
├── main_menu.gd         # Main menu — leaderboard, shop, profile panels
└── ...
```

The match is driven by a five-state machine in `ranked_match.gd`. Both clients receive the same integer seed from the server at match start and run the hazard sequence independently — no per-frame game state is sent over the network, keeping latency impact minimal.

---

## Running Locally

1. Open the project in **Godot 4.5+**.
2. Press **F5** to run; the intro scene loads automatically.
3. The WebSocket server (`wss://laserchess-webserver.onrender.com`) is already set in `network_manager.gd` — no local server setup needed for ranked play.

For a Windows build, run the pre-exported binary at `Export/LaserChess.exe`.
