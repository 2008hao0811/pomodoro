#requires -Version 5
# ============================================================
#  番茄钟 - 桌面番茄工作法计时器 (PowerShell + WPF, 零依赖)
#  启动方式: 双击 PomodoroLauncher.vbs 或桌面快捷方式
#  参数: -CreateShortcut  在桌面创建快捷方式(自动生成图标)
# ============================================================
param([switch]$CreateShortcut)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:Root      = $PSScriptRoot
$script:DataDir   = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'PomodoroClock'
$script:StatsFile = Join-Path $script:DataDir 'stats.txt'
$script:ErrorLog  = Join-Path $script:DataDir 'error.log'
$script:IconFile  = Join-Path $script:Root 'pomodoro.ico'

# ---------- 阶段配置 (可自行修改时长) ----------
$script:Durations = @{ work = 25 * 60; short = 5 * 60; long = 15 * 60 }
$script:Theme = @{
    work  = @{ Color = '#E5484D'; Label = '专注时间'; Tip = '专心工作，别分心' }
    short = @{ Color = '#2FB344'; Label = '短休息';   Tip = '站起来走走，放松一下眼睛' }
    long  = @{ Color = '#3B82F6'; Label = '长休息';   Tip = '好好休息，奖励一下自己' }
}

# ---------- 运行状态 ----------
$script:Mode           = 'work'
$script:Remaining      = $script:Durations.work
$script:EndTime        = [DateTime]::Now
$script:Running        = $false
$script:CycleCount     = 0      # 当前循环中已完成的番茄数 (0-3)
$script:CompletedToday = 0
$script:StatsDate      = (Get-Date).ToString('yyyy-MM-dd')
$script:Player         = $null
$script:Brushes        = @{}

# ---------- 工具函数 ----------
function Get-Brush([string]$Hex) {
    if (-not $script:Brushes.ContainsKey($Hex)) {
        $script:Brushes[$Hex] = (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex)
    }
    return $script:Brushes[$Hex]
}

function Format-Clock([int]$Secs) {
    return ('{0:mm\:ss}' -f [TimeSpan]::FromSeconds([Math]::Max(0, $Secs)))
}

function Import-Stats {
    try {
        if (Test-Path $script:StatsFile) {
            $line = (Get-Content $script:StatsFile -Raw).Trim()
            if ($line -match '^(\d{4}-\d{2}-\d{2})\|(\d+)$' -and $Matches[1] -eq $script:StatsDate) {
                $script:CompletedToday = [int]$Matches[2]
            }
        }
    } catch { }
}

function Export-Stats {
    try {
        if (-not (Test-Path $script:DataDir)) {
            New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
        }
        Set-Content -Path $script:StatsFile -Value ('{0}|{1}' -f $script:StatsDate, $script:CompletedToday) -Encoding ASCII
    } catch { }
}

function New-IconFile {
    # 用 GDI 画一个番茄图标, 只在首次运行时生成
    if (Test-Path $script:IconFile) { return }
    try {
        Add-Type -AssemblyName System.Drawing
        $bmp = New-Object System.Drawing.Bitmap -ArgumentList 64, 64
        $g   = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.FillEllipse([System.Drawing.Brushes]::Tomato, 3, 17, 58, 45)        # 果实
        $g.FillEllipse([System.Drawing.Brushes]::ForestGreen, 21, 4, 22, 17)   # 叶子
        $shine = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb(110, 255, 255, 255))
        $g.FillEllipse($shine, 13, 25, 14, 9)                                  # 高光
        $g.Dispose()
        $ms = New-Object System.IO.MemoryStream
        [System.Drawing.Icon]::FromHandle($bmp.GetHicon()).Save($ms)
        [System.IO.File]::WriteAllBytes($script:IconFile, $ms.ToArray())
        $ms.Dispose(); $bmp.Dispose()
    } catch { }
}

# ---------- 提醒音效 ----------
function Start-Alarm {
    $script:Player = $null
    try {
        $wav = Join-Path $env:SystemRoot 'Media\Alarm05.wav'
        if (Test-Path $wav) {
            $script:Player = New-Object System.Media.SoundPlayer -ArgumentList $wav
            $script:Player.PlayLooping()   # 循环播放, 点击弹窗确定后停止
            return
        }
    } catch { $script:Player = $null }
    try { 1..3 | ForEach-Object { [console]::Beep(880, 260); Start-Sleep -Milliseconds 120 } } catch { }
}

function Stop-Alarm {
    if ($script:Player) {
        try { $script:Player.Stop(); $script:Player.Dispose() } catch { }
        $script:Player = $null
    }
}

# ---------- 界面刷新 ----------
function Update-Clock {
    $script:Clock.Text = Format-Clock $script:Remaining
    if ($script:Window.TaskbarItemInfo) {
        if ($script:Running) {
            $total = $script:Durations[$script:Mode]
            $script:Window.TaskbarItemInfo.ProgressValue = 1.0 - ($script:Remaining / $total)
            $script:Window.TaskbarItemInfo.ProgressState = 'Normal'
        } else {
            $script:Window.TaskbarItemInfo.ProgressState = 'None'
        }
    }
}

function Update-Dots {
    $filled = if ($script:Mode -eq 'long') { 4 } else { $script:CycleCount % 4 }
    1..4 | ForEach-Object {
        $dot = $script:Window.FindName("Dot$_")
        if ($_ -le $filled) { $dot.Fill = Get-Brush $script:Theme[$script:Mode].Color }
        else                { $dot.Fill = Get-Brush '#33334D' }
    }
}

function Update-Theme {
    $t = $script:Theme[$script:Mode]
    $script:PhaseLabel.Text       = $t.Label
    $script:PhaseLabel.Foreground = Get-Brush $t.Color
    $script:Clock.Foreground      = Get-Brush $t.Color
    $script:BtnStart.Background   = Get-Brush $t.Color
    $script:StatsText.Text        = ('今日完成 {0} 个番茄' -f $script:CompletedToday)
    Update-Dots
}

function Update-Buttons {
    $script:BtnStart.Content = if ($script:Running) { '暂停' } else { '开始' }
    if ($script:Running) {
        $script:HintText.Text = $script:Theme[$script:Mode].Tip
    } elseif ($script:Remaining -eq $script:Durations[$script:Mode]) {
        $script:HintText.Text = $script:Theme[$script:Mode].Tip
    } else {
        $script:HintText.Text = '已暂停，点击「开始」继续'
    }
    if ($script:Window.TaskbarItemInfo -and -not $script:Running) {
        $script:Window.TaskbarItemInfo.ProgressState = 'None'
    }
}

function Set-Phase([string]$NewMode) {
    $script:Timer.Stop()
    $script:Mode      = $NewMode
    $script:Remaining = $script:Durations[$NewMode]
    $script:Running   = $false
    Update-Theme
    Update-Clock
    Update-Buttons
}

function Complete-Phase {
    $script:Timer.Stop()
    $script:Running = $false
    $wasWork = ($script:Mode -eq 'work')

    # 跨天自动清零
    $today = (Get-Date).ToString('yyyy-MM-dd')
    if ($today -ne $script:StatsDate) { $script:StatsDate = $today; $script:CompletedToday = 0 }
    if ($wasWork) { $script:CompletedToday++; $script:CycleCount++ }
    Export-Stats

    $next = if ($wasWork) { if ($script:CycleCount % 4 -eq 0) { 'long' } else { 'short' } } else { 'work' }
    $nextLabel = $script:Theme[$next].Label
    $nextMins  = [int]($script:Durations[$next] / 60)

    $script:Remaining = 0
    Update-Clock
    Update-Theme
    Update-Buttons

    Start-Alarm
    if ($wasWork) {
        $msg = "🍅 完成第 $script:CycleCount 个番茄！`n`n接下来：$nextLabel $nextMins 分钟"
    } else {
        $msg = "休息结束！`n`n接下来：$nextLabel $nextMins 分钟，点击「开始」继续"
    }
    [void][Windows.MessageBox]::Show($script:Window, $msg, '番茄钟',
        [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information)
    Stop-Alarm

    Set-Phase $next
}

function Invoke-Tick {
    if (-not $script:Running) { return }
    $remain = [int][Math]::Ceiling(($script:EndTime - [DateTime]::Now).TotalSeconds)
    if ($remain -le 0) { Complete-Phase }
    else { $script:Remaining = $remain; Update-Clock }
}

# ---------- 创建桌面快捷方式 ----------
if ($CreateShortcut) {
    New-IconFile
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop '番茄钟.lnk'
    $vbs     = Join-Path $script:Root 'PomodoroLauncher.vbs'
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath       = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $sc.Arguments        = '"' + $vbs + '"'
    $sc.WorkingDirectory = $script:Root
    $sc.IconLocation     = "$script:IconFile,0"
    $sc.Description      = '桌面番茄钟'
    $sc.Save()
    Write-Output ("SHORTCUT-OK: " + $lnkPath)
    exit 0
}

# ---------- 主程序 ----------
$script:Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="番茄钟" Width="380" SizeToContent="Height"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#1B1B2A" FontFamily="Microsoft YaHei UI" UseLayoutRounding="True">
  <Window.TaskbarItemInfo>
    <TaskbarItemInfo/>
  </Window.TaskbarItemInfo>
  <Window.Resources>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="#3A3A55"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="12" Padding="0,11">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Opacity" Value="0.85"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Opacity" Value="0.7"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <StackPanel Margin="28,24,28,22">
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
      <Ellipse Width="14" Height="14" Fill="#E5484D" VerticalAlignment="Center" Margin="0,1,9,0"/>
      <TextBlock Text="番茄钟" FontSize="19" FontWeight="Bold" Foreground="#EDEDF5"/>
    </StackPanel>

    <TextBlock x:Name="PhaseLabel" Text="专注时间" FontSize="15" Margin="0,26,0,0"
               HorizontalAlignment="Center" Foreground="#E5484D"/>
    <TextBlock x:Name="Clock" Text="25:00" FontSize="70" FontWeight="Bold" FontFamily="Consolas"
               Margin="0,2,0,0" HorizontalAlignment="Center" Foreground="#E5484D"/>

    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,14,0,0">
      <Ellipse x:Name="Dot1" Width="13" Height="13" Margin="7,0" Fill="#33334D"/>
      <Ellipse x:Name="Dot2" Width="13" Height="13" Margin="7,0" Fill="#33334D"/>
      <Ellipse x:Name="Dot3" Width="13" Height="13" Margin="7,0" Fill="#33334D"/>
      <Ellipse x:Name="Dot4" Width="13" Height="13" Margin="7,0" Fill="#33334D"/>
    </StackPanel>

    <TextBlock x:Name="HintText" Text="准备好了就开始吧" FontSize="13" Margin="0,16,0,0"
               Foreground="#8B8BA3" HorizontalAlignment="Center"/>

    <UniformGrid Columns="3" Margin="0,20,0,0">
      <Button x:Name="BtnStart" Content="开始" Style="{StaticResource Btn}" Margin="0,0,8,0"/>
      <Button x:Name="BtnSkip"  Content="跳过" Style="{StaticResource Btn}" Margin="0,0,8,0"/>
      <Button x:Name="BtnReset" Content="重置" Style="{StaticResource Btn}"/>
    </UniformGrid>

    <Border Background="#232338" CornerRadius="12" Margin="0,24,0,0" Padding="16,12">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <Ellipse Width="12" Height="12" Fill="#E5484D" VerticalAlignment="Center" Margin="0,1,8,0"/>
        <TextBlock x:Name="StatsText" Text="今日完成 0 个番茄" FontSize="14" Foreground="#C9C9DA"/>
      </StackPanel>
    </Border>
  </StackPanel>
</Window>
'@

try {
    $script:Window     = [Windows.Markup.XamlReader]::Parse($script:Xaml)
    $script:PhaseLabel = $script:Window.FindName('PhaseLabel')
    $script:Clock      = $script:Window.FindName('Clock')
    $script:HintText   = $script:Window.FindName('HintText')
    $script:BtnStart   = $script:Window.FindName('BtnStart')
    $script:BtnSkip    = $script:Window.FindName('BtnSkip')
    $script:BtnReset   = $script:Window.FindName('BtnReset')
    $script:StatsText  = $script:Window.FindName('StatsText')

    # 开始/暂停
    $script:BtnStart.Add_Click({
        if ($script:Running) {
            $script:Remaining = [int][Math]::Ceiling(($script:EndTime - [DateTime]::Now).TotalSeconds)
            if ($script:Remaining -lt 0) { $script:Remaining = 0 }
            $script:Timer.Stop()
            $script:Running = $false
        } else {
            $script:EndTime  = [DateTime]::Now.AddSeconds($script:Remaining)
            $script:Running  = $true
            $script:Timer.Start()
        }
        Update-Clock
        Update-Buttons
    })

    # 跳过当前阶段 (不计数)
    $script:BtnSkip.Add_Click({
        $next = if ($script:Mode -eq 'work') { 'short' } else { 'work' }
        Set-Phase $next
    })

    # 重置当前阶段
    $script:BtnReset.Add_Click({
        $script:Timer.Stop()
        $script:Running   = $false
        $script:Remaining = $script:Durations[$script:Mode]
        Update-Clock
        Update-Buttons
    })

    $script:Window.Add_Closed({ Stop-Alarm })

    $script:Timer = New-Object System.Windows.Threading.DispatcherTimer
    $script:Timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $script:Timer.Add_Tick({ Invoke-Tick })

    New-IconFile
    try {
        $uri = New-Object System.Uri($script:IconFile)
        $script:Window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($uri)
    } catch { }

    Import-Stats
    Set-Phase 'work'
    [void]$script:Window.ShowDialog()
} catch {
    $err = '{0} | {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), ($_ | Out-String)
    try {
        if (-not (Test-Path $script:DataDir)) { New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null }
        Add-Content -Path $script:ErrorLog -Value $err
    } catch { }
    try { [void][Windows.MessageBox]::Show("启动出错：`n$($_.Exception.Message)", '番茄钟') } catch { }
}
