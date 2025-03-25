# Define source and destination paths
$SourcePath = "\\path\to\source\directory"  # Modify this to the source directory path
$DestinationPath = "C:\path\to\destination\folder"  # Modify this to the destination directory path

# Ask how many days back to include in file_list.txt or add all files
$daysBack = Read-Host "Enter the number of days to include (or press Enter for all files)"
$useAllFiles = $daysBack -eq ""  # If the user pressed enter, use all files
$daysBack = if ($useAllFiles) { "all" } else { [int]$daysBack }

# Ask for the frame rate (frames per second)
$frameRate = Read-Host "Enter the frame rate (frames per second), e.g., 30 or 150"

# Check if destination directory exists, if not, create it
if (-not (Test-Path -Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath
}

# Get all .jpg files from the source directory
$Files = Get-ChildItem -Path $SourcePath -Filter *.jpg -File

# Move each .jpg file from the source to the destination
foreach ($File in $Files) {
    $SourceFile = $File.FullName
    $DestinationFile = Join-Path -Path $DestinationPath -ChildPath $File.Name

    try {
        Move-Item -Path $SourceFile -Destination $DestinationFile -Force
        Write-Host "Moved file: $SourceFile to $DestinationFile" -ForegroundColor Green
        Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Moved file: $SourceFile to $DestinationFile"
    } catch {
        Write-Host "Error moving file: $SourceFile. $_" -ForegroundColor Red
        Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error moving file: $SourceFile. $_"
    }
}

Write-Host "File transfer complete!" -ForegroundColor Cyan
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] File transfer complete!"

# Step 1: Filter files based on creation date or get all files
if ($useAllFiles) {
    # Sort files by the earlier of creation or last modified time, in ascending order (oldest first)
    $jpgFiles = Get-ChildItem -Path $DestinationPath -Filter "*.jpg" | Sort-Object {
        # Select the earlier of CreationTime or LastWriteTime
        if ($_.CreationTime -lt $_.LastWriteTime) {
            $_.CreationTime
        } else {
            $_.LastWriteTime
        }
    }
} else {
    # Calculate the start date based on the user input for days
    $startDate = (Get-Date).AddDays(-$daysBack)
    # Filter and sort files by the earlier of creation or last modified time, in ascending order (oldest first)
    $jpgFiles = Get-ChildItem -Path $DestinationPath -Filter "*.jpg" | Where-Object {
        $fileTime = if ($_.CreationTime -lt $_.LastWriteTime) { $_.CreationTime } else { $_.LastWriteTime }
        $fileTime -ge $startDate
    } | Sort-Object {
        # Select the earlier of CreationTime or LastWriteTime
        if ($_.CreationTime -lt $_.LastWriteTime) {
            $_.CreationTime
        } else {
            $_.LastWriteTime
        }
    }
}

if ($jpgFiles.Count -gt 0) {
    $jpgFiles | ForEach-Object { "file '$($_.Name)'" } | Set-Content "$DestinationPath\file_list.txt"
    Write-Host "file_list.txt created with files from the last $daysBack days (or all files)." -ForegroundColor Green
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] file_list.txt created with files from the last $daysBack days (or all files)."
} else {
    Write-Host "No JPG files found within the specified time frame. Exiting..." -ForegroundColor Red
    Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] No JPG files found within the specified time frame. Exiting..."
    exit
}

# Step 2: Create the initial timelapse video
C:\ffmpeg\bin\ffmpeg.exe -r $frameRate -f concat -safe 0 -i "$DestinationPath\file_list.txt" -c:v libx264 -pix_fmt yuv420p "$DestinationPath\output.mp4" -y
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Initial timelapse video created: output.mp4"

# Step 3: Run blackdetect with precise settings and capture output
$blackdetectOutput = C:\ffmpeg\bin\ffmpeg -i "$DestinationPath\output.mp4" -vf "blackdetect=d=0.1:pix_th=0.1" -f null - 2>&1 | Out-String
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Running blackdetect to find black frames..."

# Step 4: Parse blackdetect output for start and end times
$blackSegments = $blackdetectOutput | Select-String "black_start:(\d+\.\d+)\s+black_end:(\d+\.\d+)" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object {
    [PSCustomObject]@{
        Start = [double]$_.Groups[1].Value
        End   = [double]$_.Groups[2].Value
    }
} | Sort-Object Start

# Step 5: Get video duration
$durationOutput = C:\ffmpeg\bin\ffmpeg -i "$DestinationPath\output.mp4" 2>&1 | Out-String
$durationMatch = $durationOutput | Select-String "Duration: (\d{2}):(\d{2}):(\d{2}\.\d{2})"
$hours, $minutes, $seconds = $durationMatch.Matches.Groups[1..3].Value
$duration = [double]($hours * 3600 + $minutes * 60 + $seconds)

# Step 6: Build the trim segments (non-dark parts)
$segments = @()
$lastEnd = 0.0
foreach ($seg in $blackSegments) {
    if ($lastEnd -lt $seg.Start) {
        $segments += [PSCustomObject]@{Start = $lastEnd; End = $seg.Start}
    }
    $lastEnd = $seg.End
}
if ($lastEnd -lt $duration) {
    $segments += [PSCustomObject]@{Start = $lastEnd; End = $duration}
}

# Step 7: Generate the filter_complex string with exact formatting
$filterParts = @()
for ($i = 0; $i -lt $segments.Count; $i++) {
    $filterParts += "[0:v]trim=$($segments[$i].Start):$($segments[$i].End),setpts=PTS-STARTPTS[$i]"
}
$concatLabels = (0..($segments.Count - 1) | ForEach-Object { "[$_]" }) -join ""
$concatPart = "${concatLabels}concat=n=$($segments.Count):v=1:a=0[vout]"
$filterComplex = ($filterParts -join ";") + ";$concatPart"

# Step 8: Run the final FFmpeg command to trim and concatenate
$ffmpegCmd = "C:\ffmpeg\bin\ffmpeg -i `"$DestinationPath\output.mp4`" -filter_complex `"$filterComplex`" -map `[vout]` -c:v libx264 -an `"$DestinationPath\output_cleaned.mp4`" -y"
Invoke-Expression $ffmpegCmd
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Final video created: output_cleaned.mp4"

Write-Host "Timelapse video creation complete!" -ForegroundColor Cyan
Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Timelapse video creation complete!"
