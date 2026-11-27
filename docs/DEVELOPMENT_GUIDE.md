# PixelPlatformer Development Guide

Welcome to **PixelPlatformer**! This guide explains how the project is structured, how Godot 4's core 2D platformer systems work, and how you can customize, test, and expand the game.

---

## 1. Project Structure

```text
pixel-platformer/
├── project.godot                  # Main Godot 4.7 project configuration & Input Map
├── export_presets.cfg             # Android export preset (ready once SDK/JDK/templates are set)
├── icon.svg                       # Default project icon
├── assets/
│   ├── source/
│   │   └── character_reference.png # Original presentation artwork (preserved untouched)
│   ├── sprites/
│   │   ├── player/                # Clean 32x32 transparent PNG animation frames
│   │   │   ├── idle/              # idle_0.png .. idle_3.png (4 frames)
│   │   │   ├── run/               # run_0.png .. run_5.png (6 frames)
│   │   │   ├── jump/              # jump_0.png .. jump_2.png (3 frames)
│   │   │   ├── fall/              # fall_0.png .. fall_1.png (2 frames)
│   │   │   └── land/              # land_0.png .. land_1.png (2 frames)
│   │   └── ui/                    # 48x48 on-screen touch button icons
│   ├── tilesets/
│   │   ├── terrain_tileset.png    # 16x16 pixel-art terrain tiles
│   │   └── terrain_tileset.tres   # Godot TileSet resource with collision boxes
│   ├── backgrounds/               # Reserved for future parallax backgrounds
│   ├── audio/                     # Reserved for future SFX and music
│   └── fonts/                     # Reserved for future pixel-art UI fonts
├── scenes/
│   ├── player/player.tscn         # Reusable player scene
│   ├── levels/test_level.tscn     # Playable test level (set as Main Scene)
│   └── ui/touch_controls.tscn     # On-screen mobile touch HUD
├── scripts/
│   ├── player/player.gd           # Player movement, physics, and animation logic
│   ├── levels/test_level.gd       # Spawn alignment and out-of-bounds respawn trigger
│   └── ui/touch_controls.gd       # Touch button tracking and focus-loss safety guard
└── docs/
    ├── DEVELOPMENT_GUIDE.md       # This guide
    └── PROJECT_STATUS.md          # Current progress, checks, and next steps
```

---

## 2. How to Open and Run the Game

1. Launch **Godot Engine 4.7.2** (`Godot_v4.7.2-stable_win64.exe`).
2. In the Project Manager, click **Import** (or select **PixelPlatformer** if already listed) and choose `project.godot` in `c:\Users\Pronay\Documents\pixel-platformer`.
3. Press **F5** (or click the **Play** button in the top-right corner) to run the main scene (`res://scenes/levels/test_level.tscn`).
4. Controls on Windows & Supported Gamepads:
   - **Move Left:** `A`, `Left Arrow`, Left Analog Stick (left), D-Pad Left, or on-screen **Left** button
   - **Move Right:** `D`, `Right Arrow`, Left Analog Stick (right), D-Pad Right, or on-screen **Right** button
   - **Jump:** `Space`, `W`, `Up Arrow`, Gamepad South Face Button (`A` on Xbox, `Cross` on PlayStation, `B` on Nintendo), or on-screen **Jump** button
   - **Test Respawn:** Jump into the open pit between the left and right ground platforms to fall into `OutOfBoundsZone` and respawn at `SpawnPoint`.
   - **Hot-Plugging:** Gamepads use `device = -1` (All Devices) and `deadzone = 0.2` in the Input Map, so you can connect, disconnect, or reconnect a controller at any time without restarting the game.

---

## 3. How the Player Scene Works

Open `scenes/player/player.tscn`. Its node tree is:

```text
Player (CharacterBody2D)
├── AnimatedSprite2D
└── CollisionShape2D
```

### Node Roles Explained (Beginner Guide)
- **`CharacterBody2D` (`Player`)**: A specialized 2D physics node made for player characters and moving enemies. Unlike `RigidBody2D` (which tumbles under full physics simulation), `CharacterBody2D` lets your script directly control `velocity` and calls `move_and_slide()` to smoothly slide along floors, walls, and ceilings without getting stuck.
- **`AnimatedSprite2D`**: Draws the character's current animation frame (`idle`, `run`, `jump`, `fall`, `land`).
  - Its `position` is `Vector2(0, -16)` so that the bottom pixel row of the `32×32` sprite sits at local `y = 0` (the Player's feet).
  - Setting `flip_h = true` mirrors the sprite horizontally when facing left.
- **`CollisionShape2D`**: Defines the solid hitbox used by the physics engine (`RectangleShape2D` sized `12 × 22` pixels).
  - Its `position` is `Vector2(0, -11)`, so its bottom edge is at `-11 + 22/2 = 0` — aligned cleanly with the sprite's boots at `y = 0`.
  - Making the hitbox slightly narrower than the sprite's hair and arms prevents snagging on 16×16 tile corners.

---

## 4. How the Movement Script Works (`scripts/player/player.gd`)

Godot runs `_physics_process(delta)` at a fixed rate (default 60 times per second). `delta` is the elapsed time in seconds since the previous physics tick (~`0.0167` s). Multiplying accelerations by `delta` keeps speed consistent regardless of frame rate.

Inside `_physics_process(delta)`:
1. **Gravity:** When `not is_on_floor()`, downward velocity increases (`velocity.y += gravity * delta`), capped at `max_fall_speed`. (In Godot 2D, **negative Y is up** and **positive Y is down**.)
2. **Jumping:** When `Input.is_action_just_pressed("jump")` and `is_on_floor()` is `true`, `velocity.y` is set to `jump_velocity` (`-320.0`).
3. **Horizontal Input:** `Input.get_axis("move_left", "move_right")` returns `-1.0` to `+1.0` across keyboard, D-pad, touch buttons, and the left analog stick (with `0.2` deadzone). Partial analog stick tilts produce proportional horizontal speed, while `move_toward()` smoothly ramps `velocity.x` toward `direction * move_speed` (using `acceleration` / `air_acceleration`) or back toward `0.0` (using `friction`).
4. **Collision Resolution:** `move_and_slide()` moves `Player` by `velocity * delta` and resolves collisions against the `TileMapLayer` ground and platforms, updating `is_on_floor()`.
5. **Landing, Disconnect Safety & Respawn:** Tracks `_last_air_vy` while airborne so a genuine fall (`> 100.0` px/s downward) triggers the `"land"` animation when standing still. `Input.joy_connection_changed` safely releases any held gamepad action if a controller disconnects mid-input without interrupting active keyboard or touch presses. Falling below `fall_limit_y` (or entering `OutOfBoundsZone` in `test_level.tscn`) calls `respawn()`, resetting position, velocity, timers, and facing direction.

---

## 5. Adjusting Speed, Jump Height, and Gravity

Select the `Player` node in `scenes/player/player.tscn` (or in `scenes/levels/test_level.tscn`) and look at the **Inspector**:
- **`Movement -> Move Speed`** (default `135.0`): Higher values make running faster.
- **`Movement -> Acceleration` / `Friction`**: Higher values make starts and stops snappier; lower values feel slippery.
- **`Jumping & Gravity -> Jump Velocity`** (default `-320.0`): More negative values jump higher. Approximate jump height is `jump_velocity^2 / (2 * gravity)` (about `52 px` ≈ `3.25` tiles with defaults).
- **`Jumping & Gravity -> Gravity`** (default `980.0`): Higher values make jumps snappier and less floaty.

---

## 6. How Animations Are Selected

`Player` chooses its animation every physics frame in `_update_animation()`:
1. **In the air (`not is_on_floor()`):**
   - `velocity.y < 0.0` (moving upward) → **`jump`**
   - `velocity.y >= 0.0` (moving downward) → **`fall`**
2. **On the ground (`is_on_floor()`):**
   - If the player just landed from a real fall (`_last_air_vy > 100.0`) with near-zero horizontal speed → **`land`** plays once (`loop = false`) and clears when `animation_finished` fires (or immediately if the player moves or jumps).
   - If moving horizontally (`absf(velocity.x) > 4.0`) → **`run`** (pressing against a wall sets `velocity.x = 0.0`, keeping the player in `idle`)
   - Otherwise → **`idle`**

---

## 7. How Mobile Touch & Gamepad Controls Coexist

`scenes/ui/touch_controls.tscn` is a `CanvasLayer` (`layer = 10`) instanced in `test_level.tscn`:
- **Responsive Corner Anchors:** `HudRoot` fills the screen; `BottomLeft` anchors `LeftButton` and `RightButton` to the bottom-left corner, and `BottomRight` anchors `JumpButton` to the bottom-right corner. Because they use `Control` anchors, they adapt cleanly to 16:9, 19.5:9, and 20:9 mobile screens without covering the center gameplay area.
- **Shared Input Map:** Each `TouchScreenButton` maps directly to `"move_left"`, `"move_right"`, or `"jump"`, the exact same actions bound to keyboard keys and gamepad inputs (`JOY_AXIS_LEFT_X`, `JOY_BUTTON_DPAD_LEFT`, `JOY_BUTTON_DPAD_RIGHT`, `JOY_BUTTON_A`).
- **No Accidental Controller Menu Activation:** `TouchControls` uses `TouchScreenButton` (`Node2D`) and `Control` containers with `focus_mode = Control.FOCUS_NONE`. Pressing D-pad or the south face button on a controller does not focus or trigger UI buttons.
- **Slide & Release Safety:** `LeftButton` and `RightButton` have `passby_press = true` so sliding a thumb between left and right feels smooth. `scripts/ui/touch_controls.gd` tracks active touch actions (`is_action_held()`) and automatically calls `Input.action_release()` if the window/app loses focus, hidden, or exits the tree, preventing stuck movement.

---

## 8. Replacing the Character Artwork

`assets/source/character_reference.png` was preserved untouched as reference art because it is a 1536×1024 presentation sheet with text labels, a dark cloudy background, baked shadows, and soft anti-aliased edges. Clean 32×32 transparent frames were generated in `assets/sprites/player/` matching its design and palette.

To swap in your own sprites later (for example from Aseprite):
1. Export transparent **32×32** PNG frames (facing right, feet resting on the bottom pixel row `y = 31`) into `assets/sprites/player/<anim>/`.
2. If you replace existing filenames (`idle_0.png`, etc.), Godot automatically reimports them.
3. If you add or remove frames, open `scenes/player/player.tscn`, select `AnimatedSprite2D`, click **`SpriteFrames`** in the Inspector, and drag the new PNGs into each animation.
4. For future animations like `hurt` or `attack`, add them to `SpriteFrames` only once damage/combat mechanics exist in `player.gd`.

---

## 9. Pixel-Art & Viewport Settings Trade-offs

In `project.godot`:
- **Base Viewport (`640 × 360`) + Window Override (`1280 × 720`):** Keeps pixel art large and crisp while giving a comfortable 2× preview window on Windows.
- **Nearest Texture Filtering (`default_texture_filter = 0`):** Prevents blurry bilinear smoothing on pixel art.
- **Stretch Mode `canvas_items` + Aspect `expand`:** Fills modern wide Android displays (such as 20:9 phones) without black letterbox bars while keeping anchored touch controls pinned to the screen edges.
  - *Trade-off:* Wider screens reveal slightly more horizontal world space, and UI/sprites scale smoothly at fractional window sizes. We enabled `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` to minimize pixel shimmer during camera movement. If you ever prefer strict integer pixel scaling with black bars on non-16:9 screens, change `stretch/mode` to `viewport` and `stretch/aspect` to `keep`.

---

## 10. Running Basic Validation

From PowerShell (using the Godot console binary):

```powershell
# 1. Check that the project, scenes, and scripts load cleanly in Godot editor mode
& "C:\Users\Pronay\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --path "c:\Users\Pronay\Documents\pixel-platformer" --quit

# 2. Smoke-test opening the game window for 30 frames (GL Compatibility)
& "C:\Users\Pronay\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "c:\Users\Pronay\Documents\pixel-platformer" --quit-after 30
```

---

## 11. Remaining Tasks and Known Limitations

- **Android Export Prerequisites Not Yet Complete:** Godot `4.7.2.stable` export templates, a compatible JDK 17 installation, `cmdline-tools` in the Android SDK, and `debug.keystore` still need to be installed/configured before building an APK (see `docs/PROJECT_STATUS.md`).
- **On-Device Android & Physical Gamepad Testing Pending:** Touch controls and simulated gamepad events have been verified on Windows/headless Godot, but physical controller hardware (stick drift/deadzone feel, live USB/Bluetooth unplug/replug, and simultaneous touchscreen + controller play on Android) still requires manual testing on real hardware.
- **No Audio, Collectibles, Enemies, or Hurt State Yet:** Intentionally kept out of scope until the core controller and mobile build pipeline are solid.
