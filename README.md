# 番茄钟 (Pomodoro)

Windows 本地番茄钟小工具。

## 文件说明

- `Pomodoro.ps1` — 主程序（PowerShell）
- `PomodoroLauncher.vbs` — 无黑框启动器，日常双击用这个
- `setup.bat` — 一键安装/更新桌面快捷方式
- `pomodoro.ico` — 图标

## 使用

双击 `PomodoroLauncher.vbs` 启动；改完代码后运行 `setup.bat` 可重建快捷方式。

## 项目脚手架

`scaffold/` 是语言无关的新项目模板。一键生成新项目：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scaffold/new-project.ps1 -Name 项目名 [-Path 目标目录]
```

会生成：git 仓库 + `.gitignore`（多语言）+ `README.md` + `PERF.md` + `.vscode/tasks.json`。

性能/提速记录见 [PERF.md](PERF.md)。
