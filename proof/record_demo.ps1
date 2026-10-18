# Marg 60-second walkthrough demo recorder
Write-Host "Starting screen recording for 60 seconds..."
$recordJob = Start-Job -ScriptBlock {
    adb shell "screenrecord --time-limit 60 /sdcard/marg_demo.mp4"
}

Start-Sleep -Seconds 2

# 1. Start on Explore / Home
Write-Host "Showcasing Explore & Map..."
adb shell input swipe 540 1800 540 1200 300
Start-Sleep -Seconds 3
adb shell input swipe 540 1200 540 1800 300
Start-Sleep -Seconds 2

# 2. Open Plan Screen
Write-Host "Opening Plan Screen..."
adb shell input tap 540 1300
Start-Sleep -Seconds 3

# 3. Priority chips interaction
Write-Host "Interacting with Priority Chips..."
adb shell input tap 350 480
Start-Sleep -Seconds 2
adb shell input tap 550 480
Start-Sleep -Seconds 2
adb shell input tap 150 480
Start-Sleep -Seconds 2

# 4. Search Autocomplete
Write-Host "Searching Destination..."
adb shell input tap 540 360
Start-Sleep -Seconds 2
adb shell input text "Swargate"
Start-Sleep -Seconds 3
adb shell input tap 540 550
Start-Sleep -Seconds 2

# 5. Show Routes
Write-Host "Generating Routes..."
adb shell input tap 540 2250
Start-Sleep -Seconds 4

# 6. Results Screen: switch routes
Write-Host "Showcasing Results & Map Sync..."
adb shell input tap 540 1800
Start-Sleep -Seconds 3
adb shell input tap 540 1550
Start-Sleep -Seconds 3

# 7. Itinerary Screen
Write-Host "Opening Itinerary & Timeline Rail..."
adb shell input tap 540 1550
Start-Sleep -Seconds 4
adb shell input swipe 540 1900 540 1400 300
Start-Sleep -Seconds 3

# 8. Start Trip Mode
Write-Host "Entering Live Trip Mode (Honest Scheduled)..."
adb shell input tap 540 2250
Start-Sleep -Seconds 5

# 9. End Trip
Write-Host "Ending Trip..."
adb shell input tap 540 2250
Start-Sleep -Seconds 2
adb shell input tap 540 2150
Start-Sleep -Seconds 3

# 10. Saved & Alerts Screens
Write-Host "Showcasing Saved & Alerts Tabs..."
adb shell input tap 540 2280
Start-Sleep -Seconds 4
adb shell input tap 880 2280
Start-Sleep -Seconds 4
adb shell input tap 200 2280
Start-Sleep -Seconds 2

Write-Host "Waiting for screen record to finalize..."
Wait-Job $recordJob -Timeout 65 | Out-Null
Receive-Job $recordJob | Out-Null
Remove-Job $recordJob -Force

Write-Host "Pulling recorded video..."
adb pull /sdcard/marg_demo.mp4 proof/final/marg_demo.mp4
Copy-Item proof\final\marg_demo.mp4 proof\marg_demo.mp4 -Force
adb shell "rm /sdcard/marg_demo.mp4"

$videoSize = (Get-Item proof\final\marg_demo.mp4).Length
Write-Host "Recording complete! File size: $videoSize bytes."
