# Read-only probe and staged extraction for Northstar at the verified Forever client.
# Does not edit the git checkout, does not copy into Interface\AddOns, does not disable Polestar.
# Does not pass --no-questie, --allow-build-mismatch, --allow-incomplete, or --no-forever.
# Default -Stage Probe only reads. Later stages write under F:\wowaddons\Northstar-build.
#
# Provenance is decided by policy.js (beside this script, or tools\forever70862\policy.js
# in the checkout). A missing log, a missing meta, a stale meta, or an Era fallback
# is exit 1. An incomplete quest set is exit 3 and is not a release. Exit 0 is not
# a release either. This script was not run against the player's client from here.
#
# Verified inputs (parent discovery, 2026-11-08):
#   Shared root H:\battle_net\World of Warcraft  (.build.info and Data; also retail/PTR)
#   Product wowf 1.60.1.70862 = H:\battle_net\World of Warcraft\_forever_\Wow.exe
#   AddOns (do not write): H:\battle_net\World of Warcraft\_forever_\Interface\AddOns
#   Source checkout F:\wowaddons\Northstar. The data-pipeline note 8705af690 is the
#   baseline the paths were written against. Do not copy addon folders into AddOns.
# Public pack tables are 1.60.1.70532. They are not this client's Forever tables.

[CmdletBinding()]
param(
    [ValidateSet('Probe', 'Fetch', 'Maps', 'Grid', 'Data')]
    [string]$Stage = 'Probe'
)

$ErrorActionPreference = 'Stop'

$Wow = 'H:\battle_net\World of Warcraft'
$Flavor = 'H:\battle_net\World of Warcraft\_forever_'
$AddOns = 'H:\battle_net\World of Warcraft\_forever_\Interface\AddOns'
$Src = 'F:\wowaddons\Northstar'
$StageRoot = 'F:\wowaddons\Northstar-build'
$Product = 'wowf'
$Build = '1.60.1.70862'
$PackUrl = 'https://github.com/fitzforge/polestar/releases/download/data-pack/polestar-data-pack.tar.gz'

$Forge = Join-Path $Src 'rust\target\quick\forge.exe'
$Pack = Join-Path $StageRoot 'pack'
$Sources = Join-Path $Pack 'data\sources'
$Defs = Join-Path $Sources 'wowdbdefs'
$MapsOut = Join-Path $StageRoot 'forever-maps'
$GridOut = Join-Path $StageRoot 'grid'
$DataOut = Join-Path $StageRoot 'forge-out'
$Logs = Join-Path $StageRoot 'logs'

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Policy-Path {
    $beside = Join-Path $PSScriptRoot 'policy.js'
    if (Test-Path -LiteralPath $beside) { return $beside }
    $inRepo = Join-Path $Src 'tools\forever70862\policy.js'
    if (Test-Path -LiteralPath $inRepo) { return $inRepo }
    Fail "missing policy.js beside this script and at $inRepo. Refusing to judge output without the checker."
}

function Invoke-Decision([string]$Kind, [hashtable]$Fields) {
    $policy = Policy-Path
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) { Fail 'node is not on PATH. The provenance checker needs it. Refusing to continue.' }
    $out = Join-Path $Logs ("decision-" + $Kind + ".json")
    $argv = @($policy, $Kind, '--out', $out)
    foreach ($key in $Fields.Keys) {
        $val = $Fields[$key]
        if ($null -eq $val -or $val -eq '') { continue }
        $argv += @("--$key", [string]$val)
    }
    & node @argv | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "provenance checker failed (node exit $LASTEXITCODE)" }
    if (-not (Test-Path -LiteralPath $out)) { Fail "provenance checker wrote no decision for $Kind" }
    $d = Get-Content -LiteralPath $out -Raw | ConvertFrom-Json
    if ($null -eq $d.exit) { Fail "provenance checker returned no exit for $Kind" }
    Write-Host $d.message
    return $d
}

function Apply-Decision($d, [string]$Marker) {
    if ($d.code -eq 'quests-incomplete' -and $Marker) {
        Set-Content -LiteralPath $Marker -Value $d.message
        Write-Host "incomplete marker: $Marker"
    }
    if ([int]$d.exit -ne 0) { exit ([int]$d.exit) }
}

function Assert-ForgeArgs([string]$StageName, [string[]]$ArgumentList) {
    $file = Join-Path $Logs 'forge-args.txt'
    Set-Content -LiteralPath $file -Value ($ArgumentList -join "`n")
    $d = Invoke-Decision 'args' @{ stage = $StageName; 'args-file' = $file }
    if ([int]$d.exit -ne 0) { Fail $d.message }
}

function Read-BuildInfo([string]$Install) {
    $file = Join-Path $Install '.build.info'
    if (-not (Test-Path -LiteralPath $file)) { Fail "missing $file" }
    $lines = @(Get-Content -LiteralPath $file | Where-Object { $_.Trim() -ne '' })
    if ($lines.Count -lt 2) { Fail "$file is empty" }
    $head = $lines[0].Split('|') | ForEach-Object { ($_ -split '!')[0] }
    function Col([string]$Name) {
        $i = [array]::IndexOf($head, $Name)
        if ($i -lt 0) { Fail "$file has no $Name column" }
        return $i
    }
    $ip = Col 'Product'; $iv = Col 'Version'; $ia = Col 'Active'
    $rows = foreach ($line in $lines | Select-Object -Skip 1) {
        $f = $line.Split('|')
        [pscustomobject]@{
            Product = $f[$ip]
            Version = $f[$iv]
            Active  = ($f[$ia] -eq '1')
        }
    }
    return $rows
}

function Assert-Client {
    Write-Host "products in $Wow"
    $rows = Read-BuildInfo $Wow
    foreach ($r in $rows) {
        $flag = if ($r.Active) { 'active' } else { 'inactive' }
        Write-Host ("  {0} {1} ({2})" -f $r.Product, $r.Version, $flag)
    }
    $wowf = @($rows | Where-Object { $_.Product -eq $Product -and $_.Version -eq $Build })
    if ($wowf.Count -ne 1) {
        Fail "expected exactly one $Product $Build row in .build.info. Do not use wow, wowt, wow_classic_era, or wow_classic_beta."
    }
    $other = @($rows | Where-Object { $_.Product -ne $Product })
    if ($other.Count -gt 0) {
        Write-Host "other products are present and must not be selected. Every forge command in this script passes --product wowf or, for forge build, a grid whose index.json says wowf $Build."
    }
    $beta = @($rows | Where-Object { $_.Product -eq 'wow_classic_beta' })
    if ($beta.Count -gt 0) {
        Write-Host "WARNING: wow_classic_beta is also in .build.info ($($beta.Version -join ', ')). forge build's automatic grid stage reads only that product and would ignore wowf. Use -Stage Grid. Do not run a plain forge build."
    }
    $flavorFile = Join-Path $Flavor '.flavor.info'
    if (-not (Test-Path -LiteralPath $flavorFile)) { Fail "missing $flavorFile" }
    $last = @(Get-Content -LiteralPath $flavorFile | Where-Object { $_.Trim() -ne '' }) | Select-Object -Last 1
    if ($last.Trim() -ne $Product) { Fail ".flavor.info last line is '$last', expected $Product" }
    $exe = Join-Path $Flavor 'Wow.exe'
    if (-not (Test-Path -LiteralPath $exe)) { Fail "missing $exe" }
    if (-not (Test-Path -LiteralPath (Join-Path $Wow 'Data'))) { Fail "missing $Wow\Data" }
    if (Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue) {
        Fail 'Wow is running. Close it before any client read. A grid built while the game writes its archives can differ.'
    }
    Write-Host "client ok: $Product $Build at $Flavor"
}

function Invoke-Forge([string]$Log, [string[]]$ArgumentList) {
    $out = Join-Path $Logs ([IO.Path]::GetFileNameWithoutExtension($Log) + '.out.log')
    $err = $Log
    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out }
    if (Test-Path -LiteralPath $err) { Remove-Item -LiteralPath $err }
    $p = Start-Process -FilePath $Forge -ArgumentList $ArgumentList -WorkingDirectory $Src -Wait -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
    return $p.ExitCode
}

Assert-Client
New-Item -ItemType Directory -Force -Path $Logs | Out-Null

switch ($Stage) {
    'Probe' {
        Write-Host "AddOns destination is recorded and not written: $AddOns"
        Write-Host 'Installed Polestar_QuestDB, Codex, ItemDB and Nav are packaged addons, not reference caches. This script does not read them as inputs.'
        $q = Join-Path $AddOns 'QuestieDB\QuestieDB_Forever.toc'
        if (Test-Path -LiteralPath $q) { Write-Host "QuestieDB Forever store: $q" }
        else { Write-Host "QuestieDB_Forever.toc is absent. Quest-complete data cannot be built until that baked Forever store exists. Do not pass --no-questie." }
        if (-not (Test-Path -LiteralPath $Forge)) {
            Write-Host "forge.exe is not at $Forge. From the x64 Native Tools prompt, in the checkout:"
            Write-Host "  cargo build --profile quick --locked -p forge"
            Write-Host 'Probe did not read client tables. Exit 0 here is not a data result.'
            exit 0
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Defs 'definitions'))) {
            Write-Host "WoWDBDefs is not fetched yet. Next: powershell -File windows-forever-70862.ps1 -Stage Fetch"
            Write-Host 'Probe did not read client tables. Exit 0 here is not a data result.'
            exit 0
        }
        & $Forge gamedata list --wow $Wow --product $Product --build $Build --defs $Defs
        if ($LASTEXITCODE -ne 0) { Fail "gamedata list refused $Product $Build (exit $LASTEXITCODE). WoWDBDefs must already be at $Defs (run -Stage Fetch)." }
        Write-Host 'probe passed. This is not a data build and not a release.'
    }
    'Fetch' {
        if (-not (Test-Path -LiteralPath $Forge)) { Fail "build forge.exe first ($Forge)" }
        New-Item -ItemType Directory -Force -Path $StageRoot | Out-Null
        & $Forge data fetch --dest $Pack
        if ($LASTEXITCODE -ne 0) { Fail "data fetch failed ($LASTEXITCODE)" }
        if (-not (Test-Path -LiteralPath (Join-Path $Defs 'definitions'))) { Fail "pack has no WoWDBDefs at $Defs" }
        Write-Host "pack at $Pack. Its wago\1.60.1.70532 tables are not this client. Do not pass --forever-tables wago."
    }
    'Maps' {
        if (-not (Test-Path -LiteralPath (Join-Path $Defs 'definitions'))) { Fail "run -Stage Fetch first" }
        $log = Join-Path $Logs 'maps.log'
        $meta = Join-Path $MapsOut 'meta.json'
        $args = @(
            'data', 'build', '--offline', '--forever-tables', 'client', '--product', $Product,
            '--forever-build', $Build, '--wow', $Wow, '--defs', $Defs, '--sources', $Sources,
            '--out', $MapsOut, '--root', $Src, '--no-web-xp', '--no-web-zones'
        )
        Assert-ForgeArgs 'maps' $args
        $code = Invoke-Forge $log $args
        # Provenance is judged even when Forge exits nonzero. A missing log or
        # meta fails closed. Incomplete quests exit 3 and are not a release.
        $d = Invoke-Decision 'maps' @{ 'forge-exit' = $code; log = $log; meta = $meta }
        Apply-Decision $d (Join-Path $MapsOut 'QUESTS_INCOMPLETE.txt')
        if (@($d.provenanceOk) -and (Test-Path -LiteralPath $meta)) {
            $frames = Get-Content -LiteralPath $meta -Raw | ConvertFrom-Json
            if (@($frames.liveFrameMaps).Count -eq 0) {
                Set-Content -LiteralPath (Join-Path $MapsOut 'REVIEW_LIVE_FRAMES.txt') -Value "liveFrameMaps is empty. The wowf log passed the provenance check, and no map's bounds differed from the Era frame by more than 1 yard. Review before using coordinates. This is a flag, not a fabricated map list, and not a release."
                Write-Host 'REVIEW: liveFrameMaps is empty. See REVIEW_LIVE_FRAMES.txt'
            }
        }
    }
    'Grid' {
        $frames = Join-Path $MapsOut 'map-frames.json'
        if (-not (Test-Path -LiteralPath $frames)) { Fail "map-frames.json missing. Run -Stage Maps and keep the output only if provenance passed." }
        $log = Join-Path $Logs 'grid.log'
        $args = @(
            'nav', 'grid', '--out', $GridOut, '--wow', $Wow, '--product', $Product,
            '--root', $Src, '--defs', $Defs, '--data', $MapsOut, '--continents', '0,1,2991', '--threads', '4'
        )
        Assert-ForgeArgs 'grid' $args
        $code = Invoke-Forge $log $args
        $d = Invoke-Decision 'grid' @{
            'forge-exit' = $code
            'maps-log' = (Join-Path $Logs 'maps.log')
            'maps-meta' = (Join-Path $MapsOut 'meta.json')
            log = $log
            stdout = (Join-Path $Logs 'grid.out.log')
            index = (Join-Path $GridOut 'index.json')
        }
        Apply-Decision $d (Join-Path $GridOut 'QUESTS_INCOMPLETE.txt')
    }
    'Data' {
        $index = Join-Path $GridOut 'index.json'
        if (-not (Test-Path -LiteralPath $index)) { Fail "missing $index. Run -Stage Grid first." }
        $dgrid = Invoke-Decision 'grid' @{
            'forge-exit' = 0
            'maps-log' = (Join-Path $Logs 'maps.log')
            'maps-meta' = (Join-Path $MapsOut 'meta.json')
            log = (Join-Path $Logs 'grid.log')
            stdout = (Join-Path $Logs 'grid.out.log')
            index = $index
        }
        if ([int]$dgrid.exit -ne 0 -and $dgrid.code -ne 'quests-incomplete') { exit ([int]$dgrid.exit) }
        $toc = Join-Path $AddOns 'QuestieDB\QuestieDB_Forever.toc'
        if (-not (Test-Path -LiteralPath $toc)) {
            Fail "QuestieDB_Forever.toc is not installed. forge build stops without it. Do not pass --no-questie. This stage does not download Questie."
        }
        $log = Join-Path $Logs 'until-data.log'
        $meta = Join-Path $DataOut 'data\forever\meta.json'
        # forge build --wow remembers the folder in %APPDATA%\polestar-forge\config.toml. It does not write the game.
        $args = @(
            'build', '--wow', $Wow, '--forever-tables', 'client', '--grid', $GridOut, '--pack', $Pack,
            '--until', 'data', '--starts', 'Tauren', '--threads', '4', '--out', $DataOut, '--checkout', $Src
        )
        Assert-ForgeArgs 'data' $args
        $code = Invoke-Forge $log $args
        $d = Invoke-Decision 'data' @{ 'forge-exit' = $code; log = $log; meta = $meta; 'questie-toc' = (Test-Path -LiteralPath $toc) }
        Apply-Decision $d (Join-Path $DataOut 'QUESTS_INCOMPLETE.txt')
        Write-Host "Do not copy addon folders into $AddOns. Northstar-named folders are not a release and were not validated in game. Copying Polestar-named folders would replace installed Polestar 0.3.4."
    }
}
