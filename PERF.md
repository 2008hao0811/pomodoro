# PERF — 性能 / 提速记录

## 基线报告（2026-10-06）

| 项目 | 结论 |
|---|---|
| 类型 | 静态 HTML + PowerShell 小工具，无构建/测试/CI |
| 构建耗时 | 无构建步骤（`index.html` 直接打开即用） |
| 可提速项 | 现有产物无 pipeline 可优化 |

**结论**：当前项目没有传统意义上的构建/测试/lint/CI 瓶颈。真正可优化的是「以后做新项目」的工程起步效率。

## 优化记录

### 2026-10-06 新增语言无关项目脚手架
- **改动**：新增 `scaffold/` 目录，含 `new-project.ps1` 一键生成脚本 + `.gitignore`/`README`/`PERF`/`.vscode/tasks.json` 模板。
- **命令**：`powershell -File scaffold/new-project.ps1 -Name 项目名 [-Path 目录]`
- **收益**：新项目从「手动建 git、手写 gitignore/README/PERF」→ 一条命令 2 秒内完成。
- **验证**：✅ 已实测跑通（2026-10-06），生成 `git 仓库 + .gitignore + README.md + PERF.md + .vscode/tasks.json`。
- **回滚**：删除 `scaffold/` 与 `PERF.md` 即可，不影响任何现有产物。

### 2026-10-06 修复两处中文编码乱码
- **改动**：① `new-project.ps1` 顶部加 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`，解决 `Write-Host` 在中文系统（GBK 代码页）下输出乱码；② `Get-Content` 读模板时加 `-Encoding UTF8`，解决 README 占位符替换后内容乱码。
- **根因**：PowerShell 5.1 默认以 ANSI（GBK）处理无 BOM 的 UTF-8 文件与控制台输出，与 Git Bash 终端的 UTF-8 解码不匹配。
- **验证**：✅ 重跑脚本，控制台中文与生成的 `README.md` 均正常。
- **回滚**：还原 `new-project.ps1` 的两行改动即可。
