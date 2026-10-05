$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) {
    $vsPath = & $vswhere -latest -products * -property installationPath
}
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"

$flex = Join-Path $root "tools\win_flex.exe"
$bison = Join-Path $root "tools\win_bison.exe"
$src = Join-Path $root "src"
$outExe = Join-Path $root "parser.exe"

Write-Host "Generando parser con win_bison (parser.output = estados LALR)..."
& $bison -d -v --output="$src\parser.tab.c" --report-file="$root\parser.output" "$src\parser.y"
if ($LASTEXITCODE -ne 0) { throw "win_bison fallo" }

Write-Host "Generando lexer con win_flex..."
& $flex --outfile="$src\lex.yy.c" "$src\lexer.l"
if ($LASTEXITCODE -ne 0) { throw "win_flex fallo" }

Write-Host "Compilando con cl.exe..."
$cmd = "call `"$vcvars`" >nul && cl.exe /nologo /D_CRT_SECURE_NO_WARNINGS /D_CRT_NONSTDC_NO_WARNINGS /Fe:`"$outExe`" `"$src\parser.tab.c`" `"$src\lex.yy.c`""
cmd.exe /c $cmd
if ($LASTEXITCODE -ne 0) { throw "cl.exe fallo" }

Remove-Item -ErrorAction SilentlyContinue (Join-Path $root "parser.tab.obj"), (Join-Path $root "lex.yy.obj")

Write-Host "OK: $outExe"
