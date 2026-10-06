<#
  new-project.ps1 — 一键新建项目脚手架
  用法: powershell -NoProfile -ExecutionPolicy Bypass -File new-project.ps1 -Name 项目名 [-Path 目标目录]
  示例: powershell -File new-project.ps1 -Name my-app -Path D:\code
#>
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$Path = "."
)

$ErrorActionPreference = "Stop"
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $Path $Name

if (Test-Path $target) {
  Write-Error "目录已存在: $target"
  exit 1
}

New-Item -ItemType Directory -Path $target -Force | Out-Null

# 复制模板
Copy-Item "$here\.gitignore.template" (Join-Path $target ".gitignore")
Copy-Item "$here\PERF.template.md"    (Join-Path $target "PERF.md")
Copy-Item "$here\.vscode"             (Join-Path $target ".vscode") -Recurse

# README 占位符替换
$readme = (Get-Content "$here\README.template.md" -Raw).Replace("{{PROJECT_NAME}}", $Name)
Set-Content (Join-Path $target "README.md") $readme -Encoding UTF8

# git 初始化（若 git 可用）
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
  git -C $target init -q
  git -C $target add -A
  git -C $target commit -q -m "Initial scaffold" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "git 首次提交失败（可能未配置 user.name/email）——仓库已初始化，可稍后手动提交"
  }
}

Write-Host ""
Write-Host "已创建项目: $target"
Write-Host "下一步:  code $target"
