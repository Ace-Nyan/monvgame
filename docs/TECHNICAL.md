# 技术文档

## 1. 技术栈

- 引擎：Godot 4.6
- 脚本：GDScript 为主，包含少量 C# 插件代码
- 平台：当前仓库内已配置 Windows Desktop 导出预设

## 2. 关键入口

- 应用入口：`project.godot`
- 启动场景：`Scenes/UI/MainMenu.tscn`
- 自动加载单例：
  - `Scripts/Core/EventBus.gd`
  - `Scripts/Core/CardRegistry.gd`
  - `Scripts/Combat/CombatantRegistry.gd`
  - `Scripts/systems/RunState.gd`
  - `Scripts/systems/RelicManager.gd`

## 3. 核心模块说明

### 3.1 游戏流程

`RunState.gd` 负责维护一次 run 的全局状态，包括：

- 当前路线与节点推进
- 角色初始属性与开局牌组
- 当前生命、法力、金币等可持续状态
- 卡池与元素池重建
- 战斗/事件节点之间的数据传递

### 3.2 战斗系统

`CombatManager.gd` 负责战斗阶段推进，主要职责包括：

- 初始化战斗与生成敌人
- 接管玩家回合与敌方回合切换
- 处理抽牌、能量、响应窗口和回合结算
- 根据 `RunState` 的节点信息生成遭遇内容

### 3.3 卡牌系统

卡牌数据以 `CardData.gd` 为核心资源结构，主要字段覆盖：

- 基础信息：ID、名称、描述、稀有度
- 战斗参数：消耗、前摇/生效/后摇帧
- 分类信息：意图、元素、目标类型
- 表演信息：动画 ID、投射物场景、射程与索敌范围
- 效果列表：`CardEffect` 数组

仓库中的 `Data/Cards/*.tres` 为实际卡牌资源文件，可直接在 Godot 编辑器内调整。

### 3.4 遗物系统

遗物数据以 `RelicData.gd` 为资源结构，负责承载：

- 遗物 ID、名称、说明
- 分类与表现字段

实际遗物资源位于 `Data/Relics/`。

### 3.5 UI 与流程场景

当前已纳入仓库的流程/UI 场景包括：

- 主菜单
- 角色选择
- 图鉴
- 暂停菜单
- 地图节点场景
- 事件、奖励、安全屋、商店、许愿等节点场景

这些场景分别位于 `Scenes/UI/`、`Scenes/Map/`、`Scenes/Events/`。

## 4. 资源组织方式

- `Data/`：游戏玩法资源，适合策划与系统协同维护
- `Scenes/`：Godot 场景，负责视觉结构和节点编排
- `Scripts/`：玩法逻辑与 UI 控制脚本
- `picture/`：美术图片资源
- `addons/`：输入与 AI 相关插件

## 5. 开发建议

- 新增卡牌优先通过 `CardData` 新建 `.tres`，再接入注册表和掉落/初始牌池
- 新增遗物优先通过 `RelicData` 新建 `.tres`，再接入 `RelicManager` 与事件奖励逻辑
- 导出产物统一放在 `Build/`，避免将 exe、pck 等结果文件提交进仓库
- 如果变更了导出方式，应同步更新 `export_presets.cfg` 和部署文档