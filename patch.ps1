# ==============================================================================
# 시스템명: 통합 패치 관리 도구 (Windows PowerShell)
# 작성일자: 2026-04-16
# 주요기능: 사전검증, 안전백업(cp), 배포, 복구, 자동상태확인, 로깅
# ==============================================================================

# 1. 환경 설정 및 경로 정의
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FileListPath = Join-Path $ScriptDir "patch_list.txt"
$PathMapPath = Join-Path $ScriptDir "path_map.txt"
$LogFilePath = Join-Path $ScriptDir "patch.log"
$BkExt = "_bk"

# 로그 기록 함수
function Write-Log($Message, $Color = "Gray") {
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Write-Host $LogEntry -ForegroundColor $Color
    $LogEntry | Add-Content -Path $LogFilePath
}

# 2. 마스터 경로 맵 로드 (Hash Table)
$MasterPaths = @{}
if (Test-Path $PathMapPath) {
    Get-Content $PathMapPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '\S') {
            $filename = Split-Path $line -Leaf
            $MasterPaths[$filename] = $line
        }
    }
} else {
    Write-Log "[ERROR] $PathMapPath 파일을 찾을 수 없습니다." "Red"
    exit 1
}

# 3. 사전 검증 함수
function Validate-All($Mode) {
    $errorFound = $false
    Write-Host "------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "[STEP 1] 사전 검증을 시작합니다... (Mode: $Mode)"

    if (-not (Test-Path $FileListPath)) {
        Write-Log "  [FAIL] $FileListPath 파일이 없습니다." "Red"
        exit 1
    }

    $entries = Get-Content $FileListPath
    foreach ($entry in $entries) {
        $entry = $entry.Trim()
        if (-not ($entry -match '\S')) { continue }

        # 절대/상대 경로 판별
        if ($entry -match '^[a-zA-Z]:\\' -or $entry -match '^\\') { $srcPath = $entry }
        else { $srcPath = Join-Path $ScriptDir $entry }

        $filename = Split-Path $entry -Leaf

        if (-not $MasterPaths.ContainsKey($filename)) {
            Write-Log "  [FAIL] '$filename' -> path_map.txt 정보 누락" "Red"
            $errorFound = $true
        }

        if ($Mode -eq "deploy" -or $Mode -eq "all") {
            if (-not (Test-Path $srcPath)) {
                Write-Log "  [FAIL] '$srcPath' -> 배포 파일 없음" "Red"
                $errorFound = $true
            }
        }
    }

    if ($errorFound) {
        Write-Host "------------------------------------------------------" -ForegroundColor Red
        Write-Log "[FATAL] 검증 실패! 작업을 중단합니다." "Red"
        exit 1
    }
    Write-Host "  [PASS] 모든 검증 통과." -ForegroundColor Green
}

# 4. 작업 실행 함수
function Run-Task($Mode) {
    $count = 0
    if ($Mode -ne "check") {
        Write-Host "------------------------------------------------------" -ForegroundColor Cyan
        Write-Log "[STEP 2] $Mode 작업을 실행합니다." "Cyan"
    } else {
        Write-Host "------------------------------------------------------" -ForegroundColor Magenta
        Write-Host "[STATUS] 현재 파일 상태를 확인합니다..." -ForegroundColor Magenta
    }

    $entries = Get-Content $FileListPath
    foreach ($entry in $entries) {
        $entry = $entry.Trim(); if (-not ($entry -match '\S')) { continue }
        $filename = Split-Path $entry -Leaf
        $targetPath = $MasterPaths[$filename]
        if ($entry -match '^[a-zA-Z]:\\' -or $entry -match '^\\') { $srcPath = $entry }
        else { $srcPath = Join-Path $ScriptDir $entry }

        switch ($Mode) {
            "backup" {
                if (Test-Path $targetPath) {
                    Copy-Item $targetPath "$targetPath$BkExt" -Force
                    Write-Log "  - [OK] Backup: $($filename)$BkExt"
                } else {
                    Write-Log "  - [SKIP] 원본 없음: $filename" "Yellow"
                }
            }
            "deploy" {
                Copy-Item $srcPath $targetPath -Force
                Write-Log "  - [OK] Deployed: $filename"
            }
            "restore" {
                if (Test-Path "$targetPath$BkExt") {
                    Remove-Item $targetPath -Force -ErrorAction SilentlyContinue
                    Move-Item "$targetPath$BkExt" $targetPath -Force
                    Write-Log "  - [OK] Restored: $filename"
                } else {
                    Write-Log "  - [SKIP] 백업 없음: $filename" "Yellow"
                }
            }
            "check" {
                Write-Host "  < $filename 상태 확인 >" -ForegroundColor Magenta
                if (Test-Path $targetPath) { Get-Item $targetPath | Select-Object LastWriteTime, Length | Out-Host }
                else { Write-Host "    (운영 파일 없음)" -ForegroundColor Gray }
                
                if (Test-Path "$targetPath$BkExt") { Get-Item "$targetPath$BkExt" | Select-Object LastWriteTime, Length | Out-Host }
                else { Write-Host "    (백업 파일 없음)" -ForegroundColor Gray }
            }
        }
        $count++
    }
    if ($Mode -ne "check") {
        Write-Log "[COMPLETE] $count건의 $Mode 작업 완료." "Green"
    }
}

# 5. 메인 로직
$action = $args[0]
switch ($action) {
    "backup"  { Validate-All "backup";  Run-Task "backup";  Run-Task "check" }
    "deploy"  { Validate-All "deploy";  Run-Task "deploy";  Run-Task "check" }
    "restore" { Validate-All "restore"; Run-Task "restore"; Run-Task "check" }
    "check"   { Validate-All "check";   Run-Task "check" }
    "all"     { Validate-All "all";     Run-Task "backup";  Run-Task "deploy"; Run-Task "check" }
    Default   { Write-Host "Usage: .\patch.ps1 {backup|deploy|restore|check|all}" -ForegroundColor Yellow }
}