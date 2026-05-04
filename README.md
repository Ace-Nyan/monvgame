# monvdemo

一个基于 Godot 4 的卡牌战斗 Demo 项目，包含角色选择、地图/事件流程、战斗系统、卡牌与遗物资源以及 Windows 导出配置。

## 项目概览

- 引擎：Godot 4.6（.NET 版本）
- 入口场景：`res://Scenes/UI/MainMenu.tscn`
- 主要玩法：地图节点推进、回合制卡牌战斗、事件/商店/休整节点、角色与遗物成长
- 当前导出目标：Windows Desktop

## 快速开始

### 1. 环境准备

- 安装 Godot 4.6 .NET 版本
- 安装 .NET SDK 8.x
- Windows 导出时建议同时安装 Godot 的 Windows Export Template

### 2. 获取项目

```powershell
git clone https://github.com/Ace-Nyan/monvgame.git
cd monvgame
git checkout feat/demo
```

### 3. 编辑器运行

1. 使用 Godot 4.6 .NET 打开项目根目录。
2. 首次导入时等待资源索引和 C# 构建完成。
3. 点击运行，默认从主菜单进入。

### 4. 命令行运行

如果本机已将 Godot 可执行文件加入 PATH，可在项目根目录执行：

```powershell
godot4-mono --path .
```

若命令名不同，请替换为本机 Godot 4.6 .NET 可执行文件路径。

## 文档

- 技术文档：见 `docs/TECHNICAL.md`
- 部署与导出文档：见 `docs/DEPLOYMENT.md`

## 仓库约定

- `Build/` 为本地产出目录，不纳入版本控制
- `Data/`、`Scenes/`、`Scripts/`、`picture/` 中的游戏资源与美术资产应提交到仓库
- 导出配置保存在 `export_presets.cfg`

## 目录结构

```text
Data/        游戏数据资源（卡牌、遗物）
Scenes/      场景资源
Scripts/     逻辑脚本
addons/      第三方或自定义 Godot 插件
picture/     项目美术资源
Build/       本地导出产物（忽略）
```