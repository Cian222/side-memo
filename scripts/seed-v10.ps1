# Append test notes to existing store without touching user data (ASCII-safe via .NET JSON APIs)
$ErrorActionPreference = 'Stop'
$p = 'C:\Users\Administrator\AppData\Roaming\com.zcode.sideMemo\memos.json'
$j = [System.IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) | ConvertFrom-Json

$tests = @(
  @{ id = 'g1'; title = 'Tauri Release Plan'; content = "#work beta on Oct 15`n- ship v1.0 by month end"; pinned = $true; archived = $false; ts = 1791338400000 },
  @{ id = 'g2'; title = 'Reading Notes'; content = "#ideas focus on systems not goals #reading"; pinned = $false; archived = $false; ts = 1791270000000 },
  @{ id = 'g3'; title = 'Quick Idea'; content = "#ideas global quick input bar"; pinned = $false; archived = $false; ts = 1791086400000 },
  @{ id = 'g4'; title = 'Old Note'; content = 'an old note without tags'; pinned = $false; archived = $false; ts = 1789012800000 },
  @{ id = 'g5'; title = 'Archived Meeting Notes'; content = "#work weekly meeting, done"; pinned = $false; archived = $true; ts = 1791330000000 }
)

foreach ($t in $tests) {
  if (-not ($j.notes | Where-Object { $_.id -eq $t.id })) {
    $o = [pscustomobject]@{
      id = $t.id; title = $t.title; content = $t.content
      pinned = $t.pinned; archived = $t.archived
      created_at = $t.ts; updated_at = $t.ts
    }
    $j.notes = @($j.notes) + @($o)
  }
}
$j.active_tab = 'notes'
[System.IO.File]::WriteAllText($p, ($j | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
Write-Host ("notes now: " + $j.notes.Count)
