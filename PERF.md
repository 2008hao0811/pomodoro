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
- **验证**：生成脚本执行被权限分类器拦截，未能自动跑通（见回滚/待办）。
- **回滚**：删除 `scaffold/` 与 `PERF.md` 即可，不影响任何现有产物。
