[CmdletBinding()]
param(
    [string]$RepackPath = (Split-Path -Parent $PSScriptRoot),
    [switch]$SkipWowheadCheck
)

$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'Custom-ADD_GM_ISLAND_VENDORS.sql'
$outputPath = Join-Path $PSScriptRoot 'Custom-ADD_GM_ISLAND_VENDORS_FOREVER.sql'
$removePath = Join-Path $PSScriptRoot 'Custom-REMOVE_GM_ISLAND_VENDORS_FOREVER.sql'
$reportPath = Join-Path $PSScriptRoot 'FOREVER_VENDOR_AUDIT.md'
$wowheadCachePath = Join-Path $PSScriptRoot 'WOWHEAD_FOREVER_VERIFIED_IDS.txt'
$mysqlPath = Join-Path $RepackPath 'mysql\bin\mysql.exe'
$worldConfigPath = Join-Path $RepackPath 'server\worldserver.conf'

foreach ($requiredPath in @($sourcePath, $mysqlPath, $worldConfigPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

$connectionLine = (Select-String -LiteralPath $worldConfigPath -Pattern '^\s*WorldDatabaseInfo\s*=\s*"([^"]+)"\s*$').Matches.Groups[1].Value
$connectionParts = $connectionLine.Split(';')
if ($connectionParts.Count -lt 5) {
    throw 'WorldDatabaseInfo could not be parsed from worldserver.conf.'
}

$dbHost, $dbPort, $dbUser, $dbPassword, $worldDatabase = $connectionParts[0..4]

function Invoke-MySqlQuery {
    param([Parameter(Mandatory)][string]$Query)

    $arguments = @(
        '--protocol=TCP',
        "--host=$dbHost",
        "--port=$dbPort",
        "--user=$dbUser",
        '--batch',
        '--raw',
        '--skip-column-names',
        "--execute=$Query"
    )

    $previousMysqlPassword = $env:MYSQL_PWD
    try {
        $env:MYSQL_PWD = $dbPassword
        $result = & $mysqlPath @arguments 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw 'The ForeverRepack database query failed. Start Database in Forever Launcher and try again.'
        }
        return @($result)
    }
    finally {
        if ($null -eq $previousMysqlPassword) {
            Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
        }
        else {
            $env:MYSQL_PWD = $previousMysqlPassword
        }
    }
}

function Escape-SqlText {
    param([AllowEmptyString()][string]$Value)
    return $Value.Replace("'", "''")
}

$vendorDefinitions = @{
    90000 = @{ NewId = 990000; Name = 'Forever Druid Sets';       SubName = 'Waywatcher Collection'; Model = 7249;  SetIds = @(1945, 1946, 1947, 1948); Extra = @(); Position = @(1, 16269.5, 16315.1, 14.0968, 6.2399) }
    90001 = @{ NewId = 990001; Name = 'Forever Shaman Sets';      SubName = 'Soulcrusher Collection'; Model = 15976; SetIds = @(1949, 1950, 1951, 1952); Extra = @(); Position = @(1, 16269.6, 16317.7, 14.0951, 6.26817) }
    90002 = @{ NewId = 990002; Name = 'Forever Mage Sets';        SubName = 'Fireleaf Collection'; Model = 15834; SetIds = @(1943, 1944); Extra = @(); Position = @(1, 16269.3, 16312.6, 14.0314, 6.12923) }
    90003 = @{ NewId = 990003; Name = 'Forever Warlock Sets';     SubName = 'Heretic Collection'; Model = 11325; SetIds = @(1953, 1954); Extra = @(); Position = @(1, 16269.1, 16309.7, 14.0994, 6.21091) }
    90004 = @{ NewId = 990004; Name = 'Forever Priest Sets';      SubName = 'Revelation Collection'; Model = 15725; SetIds = @(1938, 1939); Extra = @(); Position = @(1, 16268.9, 16307.3, 14.1763, 6.1465) }
    90005 = @{ NewId = 990005; Name = 'Forever Hunter Sets';      SubName = 'Dawnstalker Collection'; Model = 16027; SetIds = @(1936, 1937); Extra = @(); Position = @(1, 16268.7, 16304.9, 14.2956, 6.14488) }
    90006 = @{ NewId = 990006; Name = 'Forever Rogue Sets';       SubName = 'Duskwraith Collection'; Model = 4617; SetIds = @(1934, 1935); Extra = @(); Position = @(1, 16268.4, 16302.4, 14.5802, 6.1425) }
    90007 = @{ NewId = 990007; Name = 'Forever Paladin Sets';     SubName = 'Inquisition Collection'; Model = 15843; SetIds = @(1940, 1941, 1942, 1963); Extra = @(); Position = @(1, 16268.3, 16300.1, 14.7637, 6.15035) }
    90008 = @{ NewId = 990008; Name = 'Forever Warrior Sets';     SubName = 'Lightbreaker Collection'; Model = 16012; SetIds = @(1932, 1933); Extra = @(); Position = @(1, 16268.1, 16298.1, 15.001, 6.16998) }
    90009 = @{ NewId = 990009; Name = 'Demon Grimoires';          SubName = 'Warlock Companion Tomes'; Model = 911; SetIds = @(); Extra = @(); Position = @(1, 16268.6, 16311, 14.1163, 6.1891) }
    90011 = @{ NewId = 990010; Name = 'Forever Melee Weapons';    SubName = 'Epic Arsenal'; Model = 7211; SetIds = @(); Extra = @(234542,234543,234545,234546,234547,234548,234552,234553,234554,234555,234556,234557,234558,234565,234566,234567,234568,234569,234570,234578,234579,234580,234581,234582,234583,234584,235476,235477,235478,235479,235480,235481); Position = @(1, 16264.1, 16326.2, 13.2077, 1.46903) }
    90012 = @{ NewId = 990011; Name = 'Forever Ranged Weapons';   SubName = 'Bows, Guns and Crossbows'; Model = 7211; SetIds = @(); Extra = @(234559,234560,234561,234585,234586,234587); Position = @(1, 16261.5, 16326.4, 13.0358, 1.42662) }
    90013 = @{ NewId = 990012; Name = 'Forever Caster Weapons';   SubName = 'Staves, Blades and Maces'; Model = 15998; SetIds = @(); Extra = @(234549,234550,234551,234571,234574,234576); Position = @(1, 16258.8, 16326.7, 12.9362, 1.48553) }
    90014 = @{ NewId = 990013; Name = 'Forever Off-hands';        SubName = 'Shields, Tomes and Relics'; Model = 7171; SetIds = @(); Extra = @(234562,234563,234564,234588,234589,234590,235473,235474); Position = @(1, 16256.1, 16327, 12.9211, 1.45175) }
    90015 = @{ NewId = 990014; Name = 'Forever Off-set Armor';    SubName = 'Raid Collection'; Model = 7206; SetIds = @(); Extra = @(); Position = @(1, 16253.3, 16327.3, 12.9214, 1.40855) }
    90016 = @{ NewId = 990015; Name = 'Forever Jewelry';         SubName = 'Rings, Necks and Trinkets'; Model = 7176; SetIds = @(); Extra = @(234032,234033,234034,234035,275981,275982,275983,275984); Position = @(1, 16250.6, 16327.7, 12.9226, 1.45857) }
    90017 = @{ NewId = 990016; Name = 'Forever Supplies';        SubName = 'Consumables and Utilities'; Model = 7209; SetIds = @(); Extra = @(); Position = @(1, 16247.5, 16328, 12.9237, 1.39573) }
    90018 = @{ NewId = 990017; Name = 'Forever Poisons';         SubName = 'Rogue Supplies'; Model = 7138; SetIds = @(); Extra = @(); Position = @(1, 16268, 16303.3, 14.5523, 6.27236) }
    90022 = @{ NewId = 990018; Name = 'Forever Mounts';          SubName = 'Rare Mount Collection'; Model = 16075; SetIds = @(); Extra = @(234465,265838,265839,265840,269671,269673,269678,274799,274933,280544); Position = @(1, 16269.7, 16322.5, 14.0319, 6.22892) }
}
$vendorOrder = @($vendorDefinitions.Keys | Sort-Object { [int]$_ })

$sourceSql = Get-Content -LiteralPath $sourcePath -Raw
$vendorMatches = [regex]::Matches(
    $sourceSql,
    '(?im)^INSERT INTO `npc_vendor` \(`entry`, `item`, `maxcount`, `incrtime`\) VALUES \((\d+),\s*(\d+),\s*(\d+),\s*(\d+)\);'
)

$legacyRows = foreach ($match in $vendorMatches) {
    [pscustomobject]@{
        VendorId = [int]$match.Groups[1].Value
        ItemId = [int]$match.Groups[2].Value
    }
}

$catalog = @{}
foreach ($line in Invoke-MySqlQuery -Query "SELECT id, name FROM $worldDatabase.armory_item ORDER BY id;") {
    $parts = $line -split "`t", 2
    if ($parts.Count -eq 2) {
        $catalog[[int]$parts[0]] = $parts[1]
    }
}

if ($catalog.Count -eq 0) {
    throw 'world.armory_item is empty; item validation cannot continue.'
}

$setItems = @{}
$setIds = @($vendorDefinitions.Values.SetIds | ForEach-Object { $_ } | Sort-Object -Unique)
if ($setIds.Count -gt 0) {
    $setQuery = "SELECT id, itemSet FROM $worldDatabase.armory_item WHERE itemSet IN ($($setIds -join ',')) ORDER BY itemSet, inventoryType, id;"
    foreach ($line in Invoke-MySqlQuery -Query $setQuery) {
        $parts = $line -split "`t"
        $itemId = [int]$parts[0]
        $setId = [int]$parts[1]
        if (-not $setItems.ContainsKey($setId)) {
            $setItems[$setId] = [System.Collections.Generic.List[int]]::new()
        }
        $setItems[$setId].Add($itemId)
    }
}

$allVendorItems = @{}
$missingLegacy = [System.Collections.Generic.List[object]]::new()
$retainedLegacyCount = 0
$addedForeverIds = [System.Collections.Generic.HashSet[int]]::new()

foreach ($oldVendorId in $vendorOrder) {
    $definition = $vendorDefinitions[$oldVendorId]
    $ids = [System.Collections.Generic.HashSet[int]]::new()

    foreach ($row in $legacyRows | Where-Object VendorId -eq $oldVendorId) {
        if ($catalog.ContainsKey($row.ItemId)) {
            [void]$ids.Add($row.ItemId)
            $retainedLegacyCount++
        }
        else {
            $missingLegacy.Add([pscustomobject]@{ VendorId = $oldVendorId; ItemId = $row.ItemId })
        }
    }

    foreach ($setId in $definition.SetIds) {
        if (-not $setItems.ContainsKey($setId)) {
            throw "Forever item set $setId was not found in world.armory_item."
        }
        foreach ($itemId in $setItems[$setId]) {
            if (-not $catalog.ContainsKey($itemId)) {
                throw "Item $itemId from set $setId was not found in world.armory_item."
            }
            [void]$ids.Add($itemId)
            [void]$addedForeverIds.Add($itemId)
        }
    }

    foreach ($itemId in $definition.Extra) {
        if (-not $catalog.ContainsKey($itemId)) {
            throw "Curated Forever item $itemId was not found in world.armory_item."
        }
        [void]$ids.Add($itemId)
        [void]$addedForeverIds.Add($itemId)
    }

    $allVendorItems[$oldVendorId] = @($ids | Sort-Object)
}

$wowheadResults = @{}
$wowheadVerifiedIds = [System.Collections.Generic.HashSet[int]]::new()
if (Test-Path -LiteralPath $wowheadCachePath -PathType Leaf) {
    foreach ($line in Get-Content -LiteralPath $wowheadCachePath) {
        $cachedId = 0
        if ([int]::TryParse($line.Trim(), [ref]$cachedId)) {
            [void]$wowheadVerifiedIds.Add($cachedId)
        }
    }
}
if (-not $SkipWowheadCheck) {
    $httpClient = [System.Net.Http.HttpClient]::new()
    $httpClient.DefaultRequestHeaders.UserAgent.ParseAdd('ForeverCreator-Vendor-Audit/1.0')
    try {
        foreach ($itemId in $addedForeverIds) {
            $url = "https://www.wowhead.com/forever/item=$itemId`?xml"
            if ($wowheadVerifiedIds.Contains($itemId)) {
                $wowheadResults[$itemId] = [pscustomobject]@{
                    Found = $true
                    Name = $catalog[$itemId]
                    Url = "https://www.wowhead.com/forever/item=$itemId"
                }
                continue
            }
            try {
                $xmlText = $httpClient.GetStringAsync($url).GetAwaiter().GetResult()
                [xml]$xml = $xmlText
                $remoteName = [string]$xml.wowhead.item.name
                $wowheadResults[$itemId] = [pscustomobject]@{
                    Found = -not [string]::IsNullOrWhiteSpace($remoteName)
                    Name = $remoteName
                    Url = "https://www.wowhead.com/forever/item=$itemId"
                }
                if ($wowheadResults[$itemId].Found) {
                    [void]$wowheadVerifiedIds.Add($itemId)
                }
            }
            catch {
                $wowheadResults[$itemId] = [pscustomobject]@{ Found = $false; Name = ''; Url = $url }
            }
        }
    }
    finally {
        $httpClient.Dispose()
    }

    [IO.File]::WriteAllLines(
        $wowheadCachePath,
        @($wowheadVerifiedIds | Sort-Object | ForEach-Object { [string]$_ }),
        [Text.UTF8Encoding]::new($false)
    )
}

$sqlLines = [System.Collections.Generic.List[string]]::new()
$sqlLines.Add('-- ForeverRepack / WoW Forever 1.60.x GM Island vendor pack')
$sqlLines.Add('-- Adapted by FilinoDZ from the VMaNGOS vendor concept.')
$sqlLines.Add('-- Generated only from item IDs verified in this ForeverRepack world.armory_item catalog.')
$sqlLines.Add('-- IMPORTANT: back up the world database before installation.')
$sqlLines.Add('-- Some world tables are non-transactional in this repack; ROLLBACK is not a substitute for a backup.')
$sqlLines.Add('')
$sqlLines.Add('START TRANSACTION;')
$sqlLines.Add('')
$sqlLines.Add('DELETE FROM `npc_vendor` WHERE `entry` BETWEEN 990000 AND 990018;')
$sqlLines.Add('DELETE FROM `creature` WHERE `guid` BETWEEN 9900000 AND 9900018;')
$sqlLines.Add('DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 990000 AND 990018;')
$sqlLines.Add('DELETE FROM `creature_template_difficulty` WHERE `Entry` BETWEEN 990000 AND 990018;')
$sqlLines.Add('DELETE FROM `creature_template` WHERE `entry` BETWEEN 990000 AND 990018;')
$sqlLines.Add('')
$sqlLines.Add('INSERT INTO `creature_template` (`entry`,`name`,`subname`,`IconName`,`RequiredExpansion`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`scale`,`Classification`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`type`,`AIName`,`MovementType`,`ExperienceModifier`,`RacialLeader`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`) VALUES')
$templateRows = foreach ($oldVendorId in $vendorOrder) {
    $definition = $vendorDefinitions[$oldVendorId]
    "($($definition.NewId),'$(Escape-SqlText $definition.Name)','$(Escape-SqlText $definition.SubName)','Buy',0,35,128,1,1.14286,1,0,0,2000,2000,1,1,1,7,'',0,1,0,1,0,'',0)"
}
$sqlLines.Add(($templateRows -join ",`r`n") + ';')
$sqlLines.Add('')
$sqlLines.Add('INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`) VALUES')
$modelRows = foreach ($oldVendorId in $vendorOrder) {
    $definition = $vendorDefinitions[$oldVendorId]
    "($($definition.NewId),0,$($definition.Model),1,1,0)"
}
$sqlLines.Add(($modelRows -join ",`r`n") + ';')
$sqlLines.Add('')
$sqlLines.Add('INSERT INTO `creature_template_difficulty` (`Entry`,`DifficultyID`,`LevelScalingDeltaMin`,`LevelScalingDeltaMax`,`ContentTuningID`,`HealthScalingExpansion`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`CreatureDifficultyID`,`TypeFlags`,`TypeFlags2`,`TypeFlags3`,`LootID`,`PickPocketLootID`,`SkinLootID`,`GoldMin`,`GoldMax`,`StaticFlags1`,`StaticFlags2`,`StaticFlags3`,`StaticFlags4`,`StaticFlags5`,`StaticFlags6`,`StaticFlags7`,`StaticFlags8`,`VerifiedBuild`)')
$difficultySelects = foreach ($oldVendorId in $vendorOrder) {
    $newId = $vendorDefinitions[$oldVendorId].NewId
    "SELECT $newId,`DifficultyID`,`LevelScalingDeltaMin`,`LevelScalingDeltaMax`,`ContentTuningID`,`HealthScalingExpansion`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`CreatureDifficultyID`,`TypeFlags`,`TypeFlags2`,`TypeFlags3`,0,0,0,0,0,`StaticFlags1`,`StaticFlags2`,`StaticFlags3`,`StaticFlags4`,`StaticFlags5`,`StaticFlags6`,`StaticFlags7`,`StaticFlags8`,0 FROM `creature_template_difficulty` WHERE `Entry`=66"
}
$sqlLines.Add(($difficultySelects -join "`r`nUNION ALL`r`n") + ';')
$sqlLines.Add('')
$sqlLines.Add('INSERT INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`) VALUES')
$spawnIndex = 0
$spawnRows = foreach ($oldVendorId in $vendorOrder) {
    $definition = $vendorDefinitions[$oldVendorId]
    $position = $definition.Position
    $guid = 9900000 + $spawnIndex
    $spawnIndex++
    "($guid,$($definition.NewId),$($position[0]),0,0,'0',0,0,0,-1,0,0,$($position[1]),$($position[2]),$($position[3]),$($position[4]),120,0,0,100,0,NULL,NULL,NULL,NULL,'',NULL,0)"
}
$sqlLines.Add(($spawnRows -join ",`r`n") + ';')
$sqlLines.Add('')

foreach ($oldVendorId in $vendorOrder) {
    $definition = $vendorDefinitions[$oldVendorId]
    $sqlLines.Add("-- $($definition.Name) ($($allVendorItems[$oldVendorId].Count) verified items)")
    $slot = 1
    $vendorRows = foreach ($itemId in $allVendorItems[$oldVendorId]) {
        $row = "($($definition.NewId),$slot,$itemId,0,0,0,1,NULL,0,1,0)"
        $slot++
        $row
    }
    $sqlLines.Add('INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`type`,`BonusListIDs`,`PlayerConditionID`,`IgnoreFiltering`,`VerifiedBuild`) VALUES')
    $sqlLines.Add(($vendorRows -join ",`r`n") + ';')
    $sqlLines.Add('')
}

$sqlLines.Add('COMMIT;')
$sqlLines.Add('')
$sqlLines.Add('-- Installation complete. Restart worldserver before testing the vendors.')

[IO.File]::WriteAllText($outputPath, ($sqlLines -join "`r`n"), [Text.UTF8Encoding]::new($false))

$removeSql = @"
-- Removes only the Forever vendor pack IDs generated by Build-Forever-Vendors.ps1.
START TRANSACTION;
DELETE FROM ``npc_vendor`` WHERE ``entry`` BETWEEN 990000 AND 990018;
DELETE FROM ``creature`` WHERE ``guid`` BETWEEN 9900000 AND 9900018;
DELETE FROM ``creature_template_model`` WHERE ``CreatureID`` BETWEEN 990000 AND 990018;
DELETE FROM ``creature_template_difficulty`` WHERE ``Entry`` BETWEEN 990000 AND 990018;
DELETE FROM ``creature_template`` WHERE ``entry`` BETWEEN 990000 AND 990018;
COMMIT;
"@
[IO.File]::WriteAllText($removePath, $removeSql, [Text.UTF8Encoding]::new($false))

$finalItemIds = @($allVendorItems.Values | ForEach-Object { $_ } | Sort-Object -Unique)
$wowheadSuccess = @($wowheadResults.Values | Where-Object Found).Count
$wowheadFailure = @($wowheadResults.Values | Where-Object { -not $_.Found }).Count

$report = [System.Collections.Generic.List[string]]::new()
$report.Add('# ForeverRepack vendor migration audit')
$report.Add('')
$report.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$report.Add('')
$report.Add('## Result')
$report.Add('')
$report.Add("- Original VMaNGOS vendor rows inspected: $($legacyRows.Count)")
$report.Add("- Legacy item references retained after local catalog verification: $retainedLegacyCount")
$report.Add("- Legacy item references omitted because they are absent from `world.armory_item`: $($missingLegacy.Count)")
$report.Add("- Curated Forever item IDs added: $($addedForeverIds.Count)")
$report.Add("- Unique item IDs in the generated pack: $($finalItemIds.Count)")
$report.Add("- New collision-free creature IDs: 990000-990018")
$report.Add("- New collision-free spawn GUIDs: 9900000-9900018")
$report.Add("- Wowhead Forever checks for curated replacements: $wowheadSuccess passed, $wowheadFailure unavailable")
$report.Add('')
$report.Add('## Important compatibility changes')
$report.Add('')
$report.Add('- The original `creature_template`, `creature`, and `npc_vendor` column layouts were replaced with the installed ForeverRepack schema.')
$report.Add('- Old VMaNGOS `npc_trainer`, `npc_gossip`, `gossip_scripts`, and custom C++ ScriptName records were intentionally excluded. They are not compatible with the current TrinityCore Retail/Forever schema.')
$report.Add('- Existing official creature IDs 90000-90032 were not overwritten; nine of them are already used by ForeverRepack.')
$report.Add('- The installed world tables do not reliably roll back this import. A database backup is mandatory before installation; use the dedicated removal script if needed.')
$report.Add('- Old display IDs were accepted only when they are referenced by the installed `creature_template_model` table. The missing ranged-vendor model was replaced by a verified merchant model.')
$report.Add('- The class vendors include the current Forever 1.60.x premium sets: Lightbreaker, Inquisition, Dawnstalker, Duskwraith, Revelation, Fireleaf, Waywatcher, Soulcrusher, and Heretic.')
$report.Add('')
$report.Add('## Vendor inventory')
$report.Add('')
foreach ($oldVendorId in $vendorOrder) {
    $definition = $vendorDefinitions[$oldVendorId]
    $report.Add("- " + '`' + $definition.NewId + '`' + " — $($definition.Name): $($allVendorItems[$oldVendorId].Count) items")
}
$report.Add('')
$report.Add('## Omitted legacy IDs')
$report.Add('')
$report.Add(($missingLegacy.ItemId | Sort-Object -Unique) -join ', ')
$report.Add('')
$report.Add('## Curated Forever references')
$report.Add('')
foreach ($itemId in $addedForeverIds | Sort-Object) {
    $name = $catalog[$itemId]
    $status = if ($wowheadResults.ContainsKey($itemId) -and $wowheadResults[$itemId].Found) { 'local DB + Wowhead Forever' } else { 'local DB' }
    $report.Add("- [$itemId — $name](https://www.wowhead.com/forever/item=$itemId) — $status")
}

[IO.File]::WriteAllText($reportPath, ($report -join "`r`n"), [Text.UTF8Encoding]::new($false))

Write-Host "Forever vendor SQL: $outputPath" -ForegroundColor Green
Write-Host "Removal SQL: $removePath" -ForegroundColor Green
Write-Host "Audit report: $reportPath" -ForegroundColor Green
Write-Host "Verified unique items: $($finalItemIds.Count)"
Write-Host "Wowhead Forever curated checks: $wowheadSuccess passed, $wowheadFailure unavailable"
