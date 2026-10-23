<#
.SYNOPSIS
    为当前运行的 IntelliJ IDEA 启用 TLSv1 / TLSv1.1（用于连接仅支持 TLS1.0 的老 SQL Server）。

.DESCRIPTION
    脚本自动完成：
      1. 扫描正在运行的 idea64.exe / idea.exe 进程，从其可执行文件路径反推 IDEA 安装目录；
      2. 在安装目录下定位 JBR（jbr / jre64 / jre）以及 java.security
         （JBR 17+ 在 conf\security\，JBR 8/11 在 lib\security\）；
      3. 备份原文件（java.security.orig 永久保留 + 带时间戳的 .bak）；
      4. 从 jdk.tls.disabledAlgorithms 中移除 TLSv1、TLSv1.1；
      5. 打印修改前后的算法列表。

    备注：
      - 修改的是 IDEA 自带运行时的全局安全策略，重启 IDEA 后生效；
      - 若 SQL Server 只提供 TLS_RSA_* 套件 / SHA1 签名，光放开协议仍会握手失败，
        此时加 -Compat，会同时放开 TLS_RSA_*、RC4、3DES、DES 与 sha1 握手签名；
      - 用 -Restore 可一键还原到原始文件。

.PARAMETER Restore
    从 java.security.orig 还原，撤销脚本做过的修改。

.PARAMETER Compat
    兼容模式：除协议版本外，同时放开老式密码套件与 SHA1 握手签名（安全性更低）。

.PARAMETER DryRun
    只检测与打印，不写任何文件。

.PARAMETER JbrPath
    手动指定 JBR 目录（如 D:\xxx\jbr），跳过自动扫描。

.EXAMPLE
    .\idea-enable-tlsv1.ps1 -DryRun

.EXAMPLE
    .\idea-enable-tlsv1.ps1

.EXAMPLE
    .\idea-enable-tlsv1.ps1 -Compat

.EXAMPLE
    .\idea-enable-tlsv1.ps1 -Restore
#>

[CmdletBinding()]
param(
    [switch]$Restore,
    [switch]$Compat,
    [switch]$DryRun,
    [string]$JbrPath
)

$ErrorActionPreference = 'Stop'

$PropName = 'jdk.tls.disabledAlgorithms'

function Write-Head([string]$text) { Write-Host ''; Write-Host "== $text ==" -ForegroundColor Cyan }
function Write-Info([string]$text) { Write-Host "  $text" }
function Write-Ok([string]$text) { Write-Host "  $text" -ForegroundColor Green }
function Write-Warn2([string]$text) { Write-Host "  $text" -ForegroundColor Yellow }
function Write-Err2([string]$text) { Write-Host "  $text" -ForegroundColor Red }

function Get-IdeaVersion([string]$ideaHome) {
    $f = Join-Path $ideaHome 'product-info.json'
    if (Test-Path $f) {
        try { return (Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch { }
    }
    return ''
}

function Get-JbrVersion([string]$jbr) {
    $f = Join-Path $jbr 'release'
    if (Test-Path $f) {
        $line = Get-Content $f -Encoding UTF8 | Where-Object { $_ -match '^JAVA_VERSION=' } | Select-Object -First 1
        if ($line) { return ($line -replace '^JAVA_VERSION=', '').Trim('"') }
    }
    return ''
}

# 1. 扫描正在运行的 IDEA 进程
function Get-RunningIdeaHomes {
    $ideaHomes = @()
    try {
        $procs = Get-CimInstance -ClassName Win32_Process -Filter "Name='idea64.exe' OR Name='idea.exe'" -ErrorAction Stop
    }
    catch {
        $procs = @()
    }
    foreach ($p in $procs) {
        $exe = $p.ExecutablePath
        if ([string]::IsNullOrWhiteSpace($exe)) { continue }
        $binDir = Split-Path -Parent $exe
        if ((Split-Path -Leaf $binDir) -ne 'bin') { continue }
        $ideaHome = Split-Path -Parent $binDir
        if ($ideaHomes -notcontains $ideaHome) { $ideaHomes += $ideaHome }
    }
    return $ideaHomes
}

# IDEA 未运行时，退化为扫描常见安装位置
function Get-InstalledIdeaHomes {
    $cands = @()
    if ($env:IDEA_HOME) { $cands += $env:IDEA_HOME }
    if ($env:LOCALAPPDATA) { $cands += (Join-Path $env:LOCALAPPDATA 'Programs\IntelliJ IDEA') }

    $pfRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    foreach ($root in $pfRoots) {
        $jb = Join-Path $root 'JetBrains'
        if (Test-Path $jb) {
            $cands += (Get-ChildItem $jb -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'IntelliJ IDEA*' } | ForEach-Object { $_.FullName })
        }
    }

    if ($env:LOCALAPPDATA) {
        $tb = Join-Path $env:LOCALAPPDATA 'JetBrains\Toolbox\apps\IDEA-U'
        if (Test-Path $tb) {
            $cands += (Get-ChildItem $tb -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq 'IntelliJ IDEA' } | ForEach-Object { $_.FullName })
        }
    }

    $result = @()
    foreach ($c in $cands) {
        if (-not (Test-Path $c)) { continue }
        if ((Test-Path (Join-Path $c 'bin\idea64.exe')) -or (Test-Path (Join-Path $c 'product-info.json'))) {
            if ($result -notcontains $c) { $result += $c }
        }
    }
    return $result
}

# 2. 在 IDEA 安装目录里定位 JBR 与 java.security
function Resolve-Jbr([string]$ideaHome) {
    $jbrCands = @(
        (Join-Path $ideaHome 'jbr'),
        (Join-Path $ideaHome 'jre64'),
        (Join-Path $ideaHome 'jre')
    )
    foreach ($j in $jbrCands) {
        if (-not (Test-Path (Join-Path $j 'bin\java.exe'))) { continue }
        $secCands = @(
            (Join-Path $j 'conf\security\java.security'),
            (Join-Path $j 'lib\security\java.security')
        )
        foreach ($s in $secCands) {
            if (Test-Path $s) {
                return [pscustomobject]@{ Jbr = $j; Security = $s }
            }
        }
    }
    return $null
}

# 解析某个安全属性的完整值（自动拼接行尾反斜杠续行）
function Get-PropBlocks($lines, [string]$name) {
    $blocks = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match ('^\s*' + [regex]::Escape($name) + '\s*=\s*(.*)$')) {
            $value = $Matches[1]
            $j = $i
            while ($value.TrimEnd().EndsWith('\') -and ($j + 1) -lt $lines.Count) {
                $v = $value.TrimEnd()
                $value = $v.Substring(0, $v.Length - 1)
                $j++
                $value = $value + ' ' + $lines[$j]
            }
            $blocks += [pscustomobject]@{ Start = $i; End = $j; Value = $value }
        }
    }
    return $blocks
}

function Format-AlgoList([string]$value, [string]$prefix = '      ') {
    $items = @($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $out = @()
    $cur = $prefix
    foreach ($it in $items) {
        if (($cur.Length + $it.Length + 2) -gt 110) { $out += $cur.TrimEnd(); $cur = $prefix }
        $cur += $it + ', '
    }
    if ($cur.Trim() -ne '') { $out += $cur.TrimEnd().TrimEnd(',') }
    return $out
}

# ------------------------------------------------------------------ 主流程
Write-Host ''
Write-Host 'IntelliJ IDEA JBR TLSv1 enabler' -ForegroundColor Magenta
Write-Host ('Mode: ' + $(if ($Restore) { 'Restore' } elseif ($DryRun) { 'DryRun' } elseif ($Compat) { 'Apply (Compat)' } else { 'Apply' })) -ForegroundColor Magenta

# --- 定位 JBR
$target = $null
if ($JbrPath) {
    Write-Head 'JBR (manual)'
    $secCands = @(
        (Join-Path $JbrPath 'conf\security\java.security'),
        (Join-Path $JbrPath 'lib\security\java.security')
    )
    $sec = $secCands | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $sec) { Write-Err2 "未在 $JbrPath 下找到 java.security"; exit 1 }
    $target = [pscustomobject]@{ Home = (Split-Path -Parent $JbrPath); Jbr = $JbrPath; Security = $sec; Running = $false }
}
else {
    Write-Head '扫描运行中的 IDEA 进程'
    $running = @(Get-RunningIdeaHomes)
    $all = @()
    foreach ($h in $running) {
        $r = Resolve-Jbr $h
        if ($r) {
            $all += [pscustomobject]@{ Home = $h; Jbr = $r.Jbr; Security = $r.Security; Running = $true }
            Write-Ok ("PID 运行中 -> " + $h)
        }
        else {
            Write-Warn2 ("$h 未找到 jbr 目录，已跳过")
        }
    }

    if ($all.Count -eq 0) {
        Write-Warn2 '未检测到运行中的 IDEA，改为扫描已安装目录...'
        foreach ($h in @(Get-InstalledIdeaHomes)) {
            $r = Resolve-Jbr $h
            if ($r) {
                $all += [pscustomobject]@{ Home = $h; Jbr = $r.Jbr; Security = $r.Security; Running = $false }
                Write-Ok ("已安装 -> " + $h)
            }
        }
    }

    if ($all.Count -eq 0) {
        Write-Err2 '没有找到任何 IDEA + JBR，请用 -JbrPath 手动指定 JBR 目录。'
        exit 1
    }

    # 多个安装时按版本号取最新；且优先正在运行的
    $target = $all | Sort-Object @{ Expression = { $_.Running }; Descending = $true },
                               @{ Expression = { [string](Get-IdeaVersion $_.Home) }; Descending = $true } |
              Select-Object -First 1
}

$ideaVersion = Get-IdeaVersion $target.Home
$jbrVersion = Get-JbrVersion $target.Jbr
$secFile = $target.Security

Write-Head '命中目标'
Write-Info ("IDEA 安装目录 : " + $target.Home)
Write-Info ("IDEA 版本     : " + $(if ($ideaVersion) { $ideaVersion } else { '未知' }))
Write-Info ("JBR 目录      : " + $target.Jbr)
Write-Info ("JBR 版本      : " + $(if ($jbrVersion) { $jbrVersion } else { '未知' }))
Write-Info ("安全策略文件  : " + $secFile)
Write-Info ("IDEA 是否运行 : " + $(if ($target.Running) { '是（修改后需重启 IDEA 生效）' } else { '否（下次启动生效）' }))

$enc = [Text.Encoding]::GetEncoding(28591)   # ISO-8859-1：逐字节保真，避免破坏原文件
$origBackup = "$secFile.orig"

# --- 还原
if ($Restore) {
    Write-Head '还原'
    if (-not (Test-Path $origBackup)) {
        Write-Err2 "未找到原始备份 $origBackup，无法还原。"
        exit 1
    }
    if ($DryRun) {
        Write-Warn2 "[DryRun] 将用 $origBackup 覆盖 $secFile"
    }
    else {
        Copy-Item -LiteralPath $origBackup -Destination $secFile -Force
        Write-Ok "已还原: $secFile"
        Write-Ok "请重启 IDEA 使配置生效。"
    }
    exit 0
}

# --- 计算要移除的条目
$removeList = @('TLSv1', 'TLSv1.1')
if ($Compat) {
    $removeList += @(
        'TLS_RSA_*',
        'RC4',
        'DES',
        '3DES_EDE_CBC',
        'ECDH',
        'rsa_pkcs1_sha1 usage HandshakeSignature',
        'ecdsa_sha1 usage HandshakeSignature',
        'dsa_sha1 usage HandshakeSignature'
    )
}

if (-not (Test-Path $secFile)) { Write-Err2 "文件不存在: $secFile"; exit 1 }

$lines = [IO.File]::ReadAllLines($secFile, $enc)
$blocks = @(Get-PropBlocks $lines $PropName)
if ($blocks.Count -eq 0) {
    Write-Err2 "在 $secFile 中没有找到 $PropName，请确认路径是否正确。"
    exit 1
}

Write-Head '修改前'
foreach ($b in $blocks) { Format-AlgoList $b.Value | ForEach-Object { Write-Host $_ } }

$list = New-Object System.Collections.ArrayList
foreach ($l in $lines) { [void]$list.Add($l) }

$changed = $false
for ($b = $blocks.Count - 1; $b -ge 0; $b--) {
    $blk = $blocks[$b]
    $items = @($blk.Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $kept = @($items | Where-Object {
            $it = $_
            -not ($removeList | Where-Object { $it -ieq $_ })
        })
    if ($kept.Count -eq $items.Count) { continue }
    $newLine = $PropName + '=' + ($kept -join ', ')
    $list.RemoveRange($blk.Start, ($blk.End - $blk.Start + 1))
    $list.Insert($blk.Start, $newLine)
    $changed = $true
}

Write-Head '修改后'
$newBlocks = @(Get-PropBlocks $list $PropName)
foreach ($b in $newBlocks) { Format-AlgoList $b.Value | ForEach-Object { Write-Host $_ } }

if (-not $changed) {
    Write-Warn2 '目标条目已不存在（TLSv1 / TLSv1.1 早已放开），无需修改。'
    exit 0
}

if ($DryRun) {
    Write-Head 'DryRun'
    Write-Warn2 '未写入任何文件。去掉 -DryRun 即真正生效。'
    exit 0
}

Write-Head '写回'
if (-not (Test-Path $origBackup)) {
    Copy-Item -LiteralPath $secFile -Destination $origBackup -Force
    Write-Ok ("原始备份: " + $origBackup)
}
else {
    Write-Info ("原始备份已存在: " + $origBackup)
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bak = "$secFile.bak.$stamp"
Copy-Item -LiteralPath $secFile -Destination $bak -Force
Write-Ok ("时间戳备份: " + $bak)

[IO.File]::WriteAllLines($secFile, [string[]]$list.ToArray(), $enc)

# 回读校验
$check = [IO.File]::ReadAllLines($secFile, $enc)
$checkBlocks = @(Get-PropBlocks $check $PropName)
$still = @()
foreach ($b in $checkBlocks) {
    $items = @($b.Value -split ',' | ForEach-Object { $_.Trim() })
    foreach ($r in $removeList) {
        if ($items | Where-Object { $_ -ieq $r }) { $still += $r }
    }
}
if ($still.Count -eq 0) {
    Write-Ok '校验通过：目标算法已全部从禁用列表中移除。'
}
else {
    Write-Warn2 ('校验发现仍存在: ' + ($still -join ', ') + '（可能被多处定义，请检查文件）')
}

Write-Head '后续'
Write-Info '1) 重启 IDEA 使配置生效（当前进程仍在用旧的 java.security）。'
Write-Info '2) 数据源 URL 建议追加：'
Write-Host '     jdbc:sqlserver://<host>:1433;databaseName=<db>;encrypt=false;trustServerCertificate=true;sslProtocol=TLSv1;' -ForegroundColor DarkGray
Write-Info '3) 若仍握手失败，用本脚本 -Compat 再跑一次（放开 TLS_RSA_* / RC4 / 3DES 与 SHA1 签名）。'
Write-Info '4) 需要还原：powershell -ExecutionPolicy Bypass -File .\idea-enable-tlsv1.ps1 -Restore'
Write-Host ''
