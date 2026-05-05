# Start this script via generate-win.bat on Windows.
# Apply templates in this fixed priority regardless of input order.
$TEMPLATES_ORDER = @("git", "markdown", "python", "c")
$TEMPLATE_URLS = @{
    "git"      = "https://github.com/in0ho1no/Git_Template"
    "markdown" = "https://github.com/in0ho1no/Markdown_Template"
    "python"   = "https://github.com/in0ho1no/Python_Template"
    "c"        = "https://github.com/in0ho1no/C_template"
}
$OUTPUT_DIR = "integlated"

function Select-AndSortTemplates {
    param([string[]]$InputArgs)

    $rawSelected = @()

    if ($InputArgs.Count -eq 0) {
        foreach ($tmpl in $TEMPLATES_ORDER) {
            $answer = Read-Host "Use $tmpl template? (y/n)"
            if ($answer -eq "y" -or $answer -eq "Y") {
                $rawSelected += $tmpl
            }
        }
    } else {
        foreach ($arg in $InputArgs) {
            if (-not $TEMPLATE_URLS.ContainsKey($arg)) {
                Write-Error "Unknown template '$arg'"
                exit 1
            }
            if ($rawSelected -notcontains $arg) {
                $rawSelected += $arg
            }
        }
    }

    # Reorder selections by the fixed template priority.
    $sorted = @()
    foreach ($tmpl in $TEMPLATES_ORDER) {
        if ($rawSelected -contains $tmpl) {
            $sorted += $tmpl
        }
    }

    return $sorted
}

# Files that should be appended across multiple templates.
function Test-IsMechanicalMerge {
    param([string]$RelPath)

    $name = [System.IO.Path]::GetFileName($RelPath)
    $targets = @(".gitignore", ".editorconfig", ".gitattributes")
    return $targets.Contains($name)
}

# Tool instruction files are always treated as conflicts.
function Test-IsInstructionFile {
    param([string]$RelPath)

    $norm = $RelPath -replace "\\", "/"
    $targets = @(".claude/CLAUDE.md", ".github/copilot-instructions.md")
    return $targets.Contains($norm)
}

# Keep appended files newline-terminated.
function Ensure-TrailingNewline {
    param([string]$FilePath)

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -eq 0) {
        return
    }

    $lastIndex = $bytes.Length - 1
    if ($bytes[$lastIndex] -eq 10) {
        return
    }

    $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Append)
    $stream.WriteByte(10)
    $stream.Close()
}

function Test-FilesEqual {
    param([string]$Path1, [string]$Path2)

    $h1 = (Get-FileHash -Path $Path1 -Algorithm SHA256).Hash
    $h2 = (Get-FileHash -Path $Path2 -Algorithm SHA256).Hash
    return ($h1 -eq $h2)
}

function Process-File {
    param([string]$Src, [string]$Rel, [string]$TmplName)

    $normRel = $Rel -replace "\\", "/"
    $dest = Join-Path $OUTPUT_DIR $Rel
    $destDir = Split-Path $dest -Parent

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if (Test-IsInstructionFile $normRel) {
        if (Test-Path $dest) {
            $conflictPath = "${dest}.merge.${TmplName}"
            Copy-Item $Src $conflictPath
            Write-Host "[CONFLICT] ${normRel}.merge.${TmplName}"
        } else {
            Copy-Item $Src $dest
            Write-Host "[ADD] $normRel"
        }
        return
    }

    if (Test-IsMechanicalMerge $normRel) {
        if (Test-Path $dest) {
            $stream = [System.IO.File]::Open($dest, [System.IO.FileMode]::Append)
            $stream.WriteByte(10)
            $srcBytes = [System.IO.File]::ReadAllBytes($Src)
            $stream.Write($srcBytes, 0, $srcBytes.Length)
            $stream.Close()
        } else {
            Copy-Item $Src $dest
        }
        Ensure-TrailingNewline $dest
        Write-Host "[ADD] $normRel"
        return
    }

    if (-not (Test-Path $dest)) {
        Copy-Item $Src $dest
        Write-Host "[ADD] $normRel"
    } elseif (Test-FilesEqual $Src $dest) {
        Write-Host "[SKIP] $normRel"
    } else {
        $conflictPath = "${dest}.merge.${TmplName}"
        Copy-Item $Src $conflictPath
        Write-Host "[CONFLICT] ${normRel}.merge.${TmplName}"
    }
}

function Apply-Template {
    param([string]$TmplDir, [string]$TmplName)

    Get-ChildItem -Path $TmplDir -Recurse -File |
        Where-Object { $_.FullName -notmatch '[/\\]\.git[/\\]' } |
        Sort-Object FullName |
        ForEach-Object {
            $rel = $_.FullName.Substring($TmplDir.Length).TrimStart([char]'\', [char]'/')
            Process-File $_.FullName $rel $TmplName
        }
}

$sorted = Select-AndSortTemplates $args

if ($sorted.Count -eq 0) {
    Write-Host "No templates selected. Exiting."
    exit 0
}

Write-Host "Selected templates (in order): $($sorted -join ', ')"

if (Test-Path $OUTPUT_DIR) {
    $otherItems = Get-ChildItem -Path $OUTPUT_DIR -Recurse |
        Where-Object { $_.PSIsContainer -or $_.Name -ne ".gitignore" }
    if ($otherItems.Count -gt 0) {
        Write-Host "Error: '$OUTPUT_DIR' already exists and contains files other than .gitignore. Aborting."
        exit 1
    }
}

New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $workDir | Out-Null

# Always remove the temp directory, even on failure.
try {
    foreach ($tmpl in $sorted) {
        $url = $TEMPLATE_URLS[$tmpl]
        $cloneDir = Join-Path $workDir $tmpl
        Write-Host "Cloning $tmpl from $url ..."
        & git clone --depth 1 $url $cloneDir
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to clone '$tmpl' (exit code $LASTEXITCODE). Aborting."
            exit 1
        }
        Write-Host "Applying $tmpl ..."
        Apply-Template $cloneDir $tmpl
    }
    Write-Host "Done."
} finally {
    Remove-Item -Recurse -Force $workDir
}
