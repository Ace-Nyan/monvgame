# 部署与运行文档

## 1. 环境要求

### 开发运行

- Windows 10/11
- Godot 4.6 .NET
- .NET SDK 8.x

### 导出运行

- Godot 4.6 .NET
- 已安装 Windows Desktop Export Templates

## 2. 从仓库克隆到运行

### 2.1 克隆代码

```powershell
git clone https://github.com/Ace-Nyan/monvgame.git
cd monvgame
git checkout feat/demo
```

### 2.2 打开项目

1. 打开 Godot 4.6 .NET。
2. 导入项目目录。
3. 等待 Godot 完成资源导入。
4. 如果编辑器提示构建 C# 解决方案，执行一次构建。

### 2.3 本地运行

- 编辑器内按 F5 运行。
- 默认入口为主菜单场景，路径为 `Scenes/UI/MainMenu.tscn`。

## 3. 命令行运行

如果系统中已配置 Godot 命令，可在项目目录执行：

```powershell
godot4-mono --path .
```

如果需要显式指定可执行文件：

```powershell
"C:\Path\To\Godot_v4.6-stable_mono_win64.exe" --path .
```

## 4. Windows 导出步骤

仓库已提供 `export_presets.cfg`，默认导出目标如下：

- 平台：Windows Desktop
- 默认输出：`Build/monvdemoDemo0.1.exe`

导出流程：

1. 在 Godot 中打开项目。
2. 确认已安装 Windows 导出模板。
3. 打开 Project -> Export。
4. 选择 `Windows Desktop` 预设。
5. 确认输出路径为 `Build/monvdemoDemo0.1.exe` 或按需调整。
6. 点击 Export Project 或 Export All。

## 5. 持续交付约定

- 不提交 `Build/` 下的 exe、zip、pck 等构建产物
- 提交场景、脚本、数据资源和美术资产
- 每次调整导出名称、平台参数或模板依赖时，需同步更新此文档

## 6. 常见问题

### 6.1 克隆后打开失败

- 确认使用的是 Godot 4.6 .NET，而不是非 .NET 版本
- 确认本机已安装 .NET SDK 8.x

### 6.2 无法导出 Windows 版本

- 先安装 Godot 官方 Windows Export Templates
- 检查 `export_presets.cfg` 是否存在并未被本地覆盖

### 6.3 仓库中出现导出结果文件

- 这些文件应保留在 `Build/` 下，并由 `.gitignore` 排除
- 若已被 git 跟踪，需要在提交前移出暂存区或停止跟踪