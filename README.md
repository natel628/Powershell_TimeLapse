==============================
TIMELAPSE FILE MOVEMENT & VIDEO CREATION SCRIPT
==============================

DESCRIPTION:
-------------
This PowerShell script automates the process of:
1. Moving `.jpg` files from a source directory (network share or local path) to a destination folder.
2. Creating a timelapse video using those `.jpg` files.
3. Detecting black frames in the timelapse video.
4. Removing black frames from the video to generate a cleaned-up timelapse.
5. Logging all actions performed, including file movements and FFmpeg command outputs, to a log file.

The script provides the flexibility to choose the time range of files to include in the video and allows setting a custom frame rate for the timelapse video.

PREREQUISITES:
--------------
1. **PowerShell**:
   - The script should be executed in a Windows environment with PowerShell installed (PowerShell 5.1 or higher).
   
2. **FFmpeg**:
   - FFmpeg must be installed on the system and accessible via the `C:\ffmpeg\bin\ffmpeg.exe` path, or you must modify the script to point to your FFmpeg installation path.
   - You can download FFmpeg from: https://ffmpeg.org/download.html

3. **Network Share or Local Source Folder**:
   - The script assumes that the source folder containing the `.jpg` files is either a network share or a local path. You must specify the full path to the source directory where your `.jpg` files are stored.
   
4. **Destination Folder**:
   - The script will move files from the source to a local destination folder. Ensure that this folder exists or that the script will create it automatically.

5. **Permissions**:
   - Ensure you have the necessary read/write permissions for the source and destination directories.
   
6. **Log File**:
   - A log file named `log.txt` will be generated and stored in the same destination folder, which will append all actions, including file movements and FFmpeg command execution details.

CONFIGURABLE SETTINGS:
---------------------
The following parameters in the script can be customized to fit your needs:

1. **Source Directory (`$SourcePath`)**:
   - This is the directory where the `.jpg` files to be included in the timelapse video are located.
   - Example: 
     ```powershell
     $SourcePath = "\\path\to\source\directory"
     ```

2. **Destination Directory (`$DestinationPath`)**:
   - This is the directory where the `.jpg` files will be moved and where the final timelapse video will be created.
   - Example: 
     ```powershell
     $DestinationPath = "C:\path\to\destination\folder"
     ```

3. **Days Back (`$daysBack`)**:
   - You can specify the number of days back from the current date to include files in the timelapse video. If you want to include all files, simply press Enter when prompted.
   - Example:
     ```powershell
     $daysBack = 7  # Include files from the last 7 days
     ```

4. **Frame Rate (`$frameRate`)**:
   - This is the frame rate (frames per second) for the timelapse video. Common values are 30 or 150 FPS.
   - Example:
     ```powershell
     $frameRate = 30  # Frame rate for the timelapse video
     ```

5. **Black Frame Detection (`blackdetect`)**:
   - The script uses FFmpeg's `blackdetect` filter to identify and remove black frames from the timelapse video. The following parameters can be configured:
   
   - **`d` (duration)**: Minimum duration in seconds for a frame to be considered "black." A higher value will ignore shorter black frames. Default is `0.1`.
     - Example (default): 
       ```powershell
       blackdetect=d=0.1:pix_th=0.1
       ```
   
   - **`pix_th` (pixel threshold)**: The pixel threshold for detecting black frames. A higher value makes the filter less sensitive to black frames.
     - Example (default): 
       ```powershell
       blackdetect=d=0.1:pix_th=0.1
       ```
   
   - To adjust these parameters, you can modify the following line in the script:
     ```powershell
     $blackdetectOutput = C:\ffmpeg\bin\ffmpeg -i "C:\path\to\destination\folder\output.mp4" -vf "blackdetect=d=0.1:pix_th=0.1" -f null - 2>&1 | Out-String
     ```

6. **Output Video Filenames**:
   - The script generates two video files:
     - `output.mp4`: The initial timelapse video created from the `.jpg` files.
     - `output_cleaned.mp4`: The cleaned video with black frames removed.
   - You can change the output filenames by modifying these lines:
     ```powershell
     C:\ffmpeg\bin\ffmpeg.exe -r $frameRate -f concat -safe 0 -i C:\path\to\destination\folder\file_list.txt -c:v libx264 -pix_fmt yuv420p C:\path\to\destination\folder\output.mp4 -y
     ```
     ```powershell
     $ffmpegCmd = "C:\ffmpeg\bin\ffmpeg -i `"C:\path\to\destination\folder\output.mp4`" -filter_complex `"$filterComplex`" -map `"[vout]`" -c:v libx264 -an `"C:\path\to\destination\folder\output_cleaned.mp4`" -y"
     ```

7. **Log File (`log.txt`)**:
   - A detailed log file is generated in the destination directory that logs every file movement, FFmpeg command execution, and the status of black frame removal.
   - The log file will capture events such as:
     - File movements (source to destination).
     - The success or failure of FFmpeg commands.
     - Start and end times of black frames detected in the video.
     - Final status after the script finishes.
   - If you want to change the log file name or location, modify the script where it specifies the `log.txt` path:
     ```powershell
     $logFile = "$DestinationPath\log.txt"
     ```

SCRIPT USAGE:
-------------
1. Run the script in PowerShell:

   ```powershell
   .\timelapse_script.ps1
