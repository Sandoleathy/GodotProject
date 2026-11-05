# AGENTS.md

给在本仓库工作的 AI 编码代理（以及人类贡献者）的工程说明。动手前先读完本文件，并同步查看 `README.md` 里的开发计划（那里是路线图，本文件是事实与约定）。

## 1. 项目概览

- **是什么**：Godot 4.7 制作的 2D 俯视角射击小游戏，工程名 `GodotTutorial-明日方舟-肿么滴`，版本 `1.1`。以《Journey of the Prairie King》风格教程为起点，已演进成"关卡计时 + 刷怪器 + 数据驱动敌人/道具"的小游戏。
- **引擎**：Godot 4.7，`gl_compatibility` 渲染（Windows 下 `d3d12` 驱动），`canvas_items` 拉伸模式。
- **语言**：GDScript（tab 缩进、带类型标注）；一个 `canvas_item` 着色器 `scene/blink.gdshader`。
- **规模**：11 个 `.gd`、9 个 `.tscn`、全部数值/资源走 `.tres` 配置。
- **目标平台**：Windows Desktop，导出预设写死到 `release/MyGodotGame.exe`（该目录被 git 忽略）。
- **无自动化测试、无构建脚本、无 CI**。所有验证靠 Godot 编辑器实际运行。

## 2. 运行与验证

主场景是 `scene/main_menu.tscn`（`uid://cgyifpknjirw2`）。

1. 用 **Godot 4.7** 打开 `project.godot`，F5 运行。
2. 手动走一遍链路：主菜单 → 选关菜单 → `scene/game.tscn`；改玩法时至少打完一局（60 秒倒计时或血量归零，两者都会弹结算框）。
3. `scene/game_test.tscn` 是未纳入版本管理的实验场景（第 2 关入口指向它），只在测刷怪点行为时用得着。
4. 导出：编辑器 `项目 > 导出 > Windows Desktop`，产物在 `release/`。

Godot 可执行文件当前**不在 PATH** 中（已确认）。若自行安装，可做单文件解析检查：

```powershell
godot --headless --path . --check-only --script res://scene/player.gd
```

改完 `.gd` / `.tscn` / `.tres` 后如果无法启动编辑器，**必须明确告诉用户"未运行验证"**，不要声称改动能跑。

## 3. 目录结构

| 路径 | 作用 |
| --- | --- |
| `project.godot` | 工程配置：主场景、输入映射、物理层命名、渲染 |
| `scene/` | 玩法场景与一一对应的脚本（game / player / enemy / enemy_spawner / bullet / pickup） |
| `resources/config/` | `Resource` 定义（`enemy_config.gd`、`pickup_config.gd`）及其 `.tres` 实例目录 |
| `resources/config/enemy_configs/` | 4 种敌人配置：basic、bomber、fast、shelled |
| `resources/config/pickup_configs/` | 5 种道具配置：speed、rapid、spiral、continue_healing、immediate_healing |
| `resources/animation/` | `SpriteFrames`（敌人动画：`move` / `death` / `explode`） |
| `resources/atlas/` | 从 `道具ui.png` 切出的 `AtlasTexture`，供道具图标使用 |
| `resources/scripts/` | 非场景脚本：菜单脚本 `menu_scripts/`、持续回血节点 `continue_healing_unit.gd` |
| `resources/texture/`、`resources/audio/`、`resources/font/` | 原始美术、音效/BGM、`IPix.ttf` 像素字体 |
| `release/` | 导出产物（`git` 忽略） |
| `.godot/` | 导入缓存（`git` 忽略，禁止手改或提交） |

命名约定：场景脚本与其场景同名放在 `scene/`；可复用的非场景节点和 UI 脚本放 `resources/scripts/`；`Resource` 的类定义放 `resources/config/`。

## 4. 场景流转与运行时架构

```
main_menu.tscn (MainMenu)
  └─ 开始游戏 → game_selection_menu.tscn (GameSelectionMenu)
                  ├─ 第 1 关 → game.tscn   (Game)
                  └─ 第 2 关 → game_test.tscn（实验场景，未跟踪）
game.tscn 结算框「返回主菜单」→ main_menu.tscn
```

### 节点职责（改动前先认准归属）

- **`Game`（`scene/game.gd`）**：关卡总控。持有 `enemy_scene`、刷怪节奏参数、`stage_duration`；`_process` 里推进倒计时、按难度插值刷怪间隔（`lerpf(spawn_interval, min_spawn_interval, progress)`）、刷新 HUD、判定胜负。**它是唯一实例化敌人的地方**，并在此处执行 `max_alive_enemies` 上限。
- **`EnemySpawner`（`scene/enemy_spawner.gd`）**：只负责"选哪个配置 + 在哪个坐标"，通过 `enemy_spawned_signal(config, position)` 通知 `Game`，自己不做实例化。`Game._collect_enemy_spwaners()` 在 `_ready` 里遍历 `EnemySpawnPoints` 的子节点并连接信号。
- **`Enemy`（`scene/enemy.gd`）**：`setup(config, player)` 在 `add_child` 之后由 `Game` 调用；`_apply_config()` 把配置写进碰撞半径、贴图帧、爆炸参数。接触伤害走 `TouchDamageArea`，子弹命中走同一 Area 的 `area_entered`，爆炸伤害用 `ExplosionDamageArea` 的形状做 `intersect_shape` 查询。
- **`Player`（`scene/player.gd`）**：移动、键鼠/手柄瞄准、射击冷却、无敌帧、拾取物 buff 计时。子弹在 `get_tree().current_scene` 下生成并 `top_level = true`；射击前用射线（World 层）判断枪口是否贴墙。
- **`Bullet`（`scene/bullet.gd`）**：`Area2D`，`setup(direction)` 设朝向；每帧射线检测世界并自行 `queue_free`。
- **`PickUp`（`scene/pickup.gd`）**：`config` 由 `Enemy` 掉落时写入；碰 Player 时调用 `player.apply_pickup(config)`，成功才销毁；到期前用 blink 着色器闪烁。
- **`ContinueHealingUnit`（`resources/scripts/continue_healing_unit.gd`）**：Player 子节点，把总回复量按时间均摊，结束时补足取整误差。
- **`MainMenu` / `GameSelectionMenu`**：`change_scene_to_file` 跳转；`SettingButton` 目前**没有**处理函数。

### 数据驱动链路

```
EnemyConfig(.tres) ──► EnemySpawner.enemy_configs ──信号──► Game 实例化 Enemy
        └─ pick_up_drop_configs ──► PickupConfig(.tres) ──► PickUp ──► Player.apply_pickup
```

所有配置通过 UID 互相引用，没有注册表、没有 autoload（全局类靠 `class_name`）。新增内容不需要改任何"列表文件"，但要挂到上面这条链路的数组里。

## 5. 常见改动怎么做

### 新增一种敌人

1. 复制 `resources/config/enemy_configs/enemy_basic.tres`，改 `enemy_type`、`max_health`、`move_speed`、`collision_radius`（该半径同时作用于本体和接触伤害区）。
2. `enemy_frames` 指向 `resources/animation/*.tres`；动画名必须与 `EnemyConfig` 的 `move_animation_name` / `death_animation_name` / `explosion_animation_name` 对得上（默认 `move`、`death`、`explode`）。
3. 会自爆的敌人：`explode_in_death = true`，并设 `explosion_damage` 与 `explosion_radius`。
4. 掉落：`pickup_drop_chance` + `pick_up_drop_configs`（数组内可重复以调权重），实际抽取还会乘 `PickupConfig.drop_weight`。
5. 把新 `.tres` 加入 `EnemySpawner.enemy_configs` 的默认数组（`enemy_spawner.gd` 顶部）或具体场景里 spawner 节点的该属性。

### 新增一种道具

1. 在 `resources/atlas/` 建 `AtlasTexture`（从 `resources/texture/道具ui.png` 切图）。
2. 复制一个 `resources/config/pickup_configs/*.tres`，按需设 `pickup_type`、`duration`、`move_speed_multiplier`、`fire_rate_multiplier`、`healing_amount`、`player_form_mode`、`shot_pattern`、`icon_texture`、`audio_stream`、`drop_weight`。
3. 加入某个 `EnemyConfig.pick_up_drop_configs`（通常是 bomber 的掉落表）。

### 改数值/平衡

优先改 `.tres`，不要把数值硬编码进 `.gd`。只有在需要新的**行为维度**时才给 `EnemyConfig` / `PickupConfig` 加 `@export` 字段，并在 `Enemy._apply_config` 或 `Player.apply_pickup` 里消费它。

### 改刷怪节奏

`Game` 的 `initial_spawn_count`、`spawn_count_per_tick`、`spawn_interval`、`min_spawn_interval`、`max_alive_enemies` 都是 `@export`，优先在 `game.tscn` 的 Game 节点上调。注意 `game.gd` 里 `_is_spawn_system_ready()` 上方有注释："修改生成系统和敌人系统时注意修改！"——改动生成条件时同步更新它。

## 6. 物理层与输入

`project.godot` 的层命名与 `.tscn` 里的位掩码（位值 = 2^(层号-1)）：

| 层 | 名称 | 使用方（层/掩码） |
| --- | --- | --- |
| 1 | World | 瓦片物理层、子弹（layer 含 World 位） |
| 2 | Player | Player 本体（layer 2） |
| 3 | EnemyBody | Enemy 本体（layer 4） |
| 4 | EnemySensor | Enemy `TouchDamageArea`（layer 8，mask 18 = Player+Bullet） |
| 5 | Bullet | Bullet（layer 17 = World+Bullet） |
| 6 | Pickup | PickUp（layer 32，mask 2 = Player） |
| 7 | Explosion | Enemy `ExplosionDamageArea`（layer 64，mask 6 = Player+EnemyBody） |
| 8 | SpawnerDetect | EnemySpawner `DetectRange`（layer 128，mask 2） |

输入动作：`move_left/right/up/down`（WASD）、`shoot_left/right/up/down`（方向键/手柄轴）、`shooting`（鼠标左键 / 手柄按钮）、`pause`（Esc，脚本里尚未接）。新增输入请写进 `project.godot` 的 `[input]`，不要在脚本里读裸键码。

## 7. 代码约定

- **风格**：tab 缩进；变量 `snake_case`、类 `PascalCase`、私有函数/字段 `_` 前缀；尽量写类型（`func foo() -> void:`、`var x: int = 0`、`:=` 推断）；`StringName` 用 `&"..."`；节点引用用 `@onready`；编辑器暴露的参数用 `@export` 并配 `@export_group` / `@export_range`。
- **注释**：仓库内注释与玩家可见文本都是中文，保持一致。玩家可见文案集中在 `game.gd` 顶部常量里。
- **信号/回调**：信号用过去式或 `_signal` 后缀（现有 `enemy_spawned_signal`）；回调统一 `_on_<节点>_<事件>`。
- **场景耦合**：`@onready` 的 `$Path` 与 `.tscn` 节点名强绑定，重命名节点要同步脚本，反之亦然。
- **着色器参数**：`blink_enable` 这个参数名在 `player.gd`、`enemy.gd`、`pickup.gd` 里各有一份常量。改 `scene/blink.gdshader` 的 uniform 名时必须同步这三处（注意 `pickup.gd` 里常量本身拼作 `BLINK_ENABLEED_...`）。
- **别引入**：autoload、第三方插件、新的全局状态，除非任务确实需要；当前工程刻意保持"场景 + 配置资源"两层结构。

## 8. 资源与工程卫生

- **编码**：所有文本 UTF-8，无 BOM；`.gitattributes` 强制 LF。中文注释、`.tres` 里的中文 `pickup_name` 都是正常内容。用 PowerShell 读这些文件时默认代码页会把中文显示成乱码，读取请显式 `-Encoding utf8`（或用支持 UTF-8 的读取工具）。
- **UID**：`.gd.uid`、`uid://` 引用由编辑器维护。**移动/重命名资源请在 Godot 文件系统面板里操作**，让编辑器改写 UID；不要手改 `uid://`、不要删 `.uid` 或 `.import` 文件。
- **导入资源**：新增图片/音频先经编辑器导入，会生成 `.import`（要提交）和 `.godot/imported/`（不提交）。
- **`.godot/`**：纯缓存，不要提交、不要手改。
- **`scene/*.tmp`**：编辑器残留（如 `enemy.tscn1949265216.tmp`），未跟踪，可安全删除，不要当成有效场景。
- **`.import` 与 `export_presets.cfg`**：属于工程配置，要提交。

## 9. 已知问题与未完成项（改动时留意，别默默"顺手重构"）

**功能未完成**

- `EnemySpawner` 的"靠近才刷怪"（`SPAWN_WHEN_CLOSE`）只有骨架：`_handle_player_detection()` 与 `_on_enemy_spawn_timer_timeout()` 都是 `pass  # TODO`；`Game._pick_global_spawner()` 目前只挑 `NORMAL` 类型。
- `pause` 输入动作已定义但没有任何脚本消费。
- 选关菜单的"设置"按钮无处理函数；`game_test.tscn` 尚未纳入版本管理。

**疑似缺陷（修之前先确认是有意为之）**

- `scene/game.gd` 的 `_stop_world()` 设置 `Engine.time_scale = 0.0` 并 `get_tree().paused = true`，但返回主菜单时没有恢复，菜单可能处于暂停/零时标状态。（计划修复）
- `scene/enemy_spawner.gd:103`：`if enemy_spawn_timer.timeout.is_connected(...): connect(...)` 条件反了，计时器实际永远不会连接。（现已修复）
- `scene/player.gd:387`：`if move_sfx_player == null and move_sfx_player.stream == null:` 应为 `or`，否则空引用时直接崩溃。（现已修复）

**拼写遗留（保持局部一致，不要大规模重命名）**

`availiable_enemy_configs`、`_collect_enemy_spwaners`、`_configure_enemy_spwan_timer`、`_spwan_dropped_pickup`、`_pick_pick_up_drop_config`、`pickup.gd` 的 `liftime_timer`、`BLINK_ENABLEED_SHADER_PARAMETER`。要统一拼写请单独开一次提交，别混在功能改动里。

## 10. 提交约定

- Commit message 用**中文**、描述实际改动，例如 `加入了两种回血道具，修改血量数值，提高数据驱动程度`。
- 提交前自查：`git status` 里不应出现 `release/`、`.godot/`、`*.tmp`；新增 `.tres` 的 UID 引用要能被编辑器解析。
- 完成路线图条目后同步勾选 `README.md` 的开发计划（`- [x]`），这是本仓库的既有习惯。
- 改动涉及本文件描述的结构/约定时，一并更新 `AGENTS.md`。
