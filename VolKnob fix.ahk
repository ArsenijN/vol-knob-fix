#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetProductName VolKnob Fix
;@Ahk2Exe-SetVersion 1.1.4
ScriptVersion := "1.1.4"
;@Ahk2Exe-SetCompanyName Arsenii Nochevnyi
;@Ahk2Exe-SetDescription Volume knob fixer for SteelSeries Sonar
;@Ahk2Exe-SetCopyright 2026

;DevNote: the VERSION file may have lame version to test the update notifier

; ============ CONFIG ============
VolStep       := 1      ; volume % per registered step
DebounceOn    := true   ; skip every Nth-1 events to counter loose detent
DebounceRatio := 2      ; register every 2nd rotation event
DebugMode     := true   ; Show detailed popups/error codes during update check
; =================================

UpCounter   := 0
DownCounter := 0

; ---- Startup Tasks ----
; Run update check 1 second after startup
SetTimer(CheckForUpdate, -1000)

; ---- Tray menu: toggle + change ratio at runtime ----
A_TrayMenu.Delete()
A_TrayMenu.Add("Debounce: ON/OFF", ToggleDebounce)
A_TrayMenu.Add("Set debounce ratio...", SetRatio)
A_TrayMenu.Add("Check for Updates", (*) => CheckForUpdate(true)) ; Manual check always shows feedback
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
UpdateTrayCheck()

ToggleDebounce(*) {
    global DebounceOn
    DebounceOn := !DebounceOn
    UpdateTrayCheck()
    ToolTip("Debounce: " (DebounceOn ? "ON (1/" DebounceRatio ")" : "OFF"))
    SetTimer(() => ToolTip(), -800)
}

SetRatio(*) {
    global DebounceRatio
    result := InputBox("Register every Nth knob step (current: " DebounceRatio ")", "Debounce Ratio", "w250 h130", DebounceRatio)
    if result.Result = "OK" and IsInteger(result.Value) and Integer(result.Value) >= 1
        DebounceRatio := Integer(result.Value)
}

UpdateTrayCheck() {
    A_TrayMenu.Rename("Debounce: ON/OFF", "Debounce: " (DebounceOn ? "ON ✓" : "OFF"))
}

; ---- Debounce gate: returns true if this event should act ----
ShouldFire(&counter) {
    global DebounceOn, DebounceRatio
    if !DebounceOn
        return true
    counter += 1
    if (Mod(counter, DebounceRatio) = 0)
        return true
    return false
}

CheckForUpdate(forceShowFeedback := false) {
    global ScriptVersion, DebugMode
    
    ; Determine if we should show popups (either debug is globally on, or user manually triggered it)
    showFeedback := DebugMode || forceShowFeedback
    
    try {
        if showFeedback
            ToolTip("Contacting GitHub...")

        req := ComObject("WinHttp.WinHttpRequest.5.1")
        
        ; 1. CACHE BUSTER: Append unique timestamp to the URL to bypass local and server caches
        url := "https://raw.githubusercontent.com/ArsenijN/vol-knob-fix/refs/heads/main/VERSION?t=" . A_Now
        req.Open("GET", url, false)
        
        ; 2. CACHE-CONTROL HEADERS: Force Windows to skip its local cache
        req.SetRequestHeader("Cache-Control", "no-cache, no-store, must-revalidate")
        req.SetRequestHeader("Pragma", "no-cache")
        req.SetRequestHeader("Expires", "0")
        
        req.Send()
        
        status := req.Status
        latest := Trim(req.ResponseText)
        
        if showFeedback {
            ToolTip() ; Clear the contact tooltip
            
            ; Only show the diagnostic breakdown if DebugMode is globally active
            if DebugMode {
                MsgBox(
                    "--- Update Debugger ---`n`n" .
                    "HTTP Status: " . status . " (200 is success)`n`n" .
                    "Raw Response from Server: '" . latest . "'`n`n" .
                    "Local Script Version: '" . ScriptVersion . "'", 
                    "Update Check Debugger", "Iconi"
                )
            }
        }
        
        if (latest != "" and latest != ScriptVersion) {
            result := MsgBox("Update available: v" latest " (you have v" ScriptVersion ")`nOpen download page?", "VolKnob Fix", "YesNo")
            if result = "Yes"
                Run("https://github.com/ArsenijN/vol-knob-fix/releases/latest")
        } else if showFeedback {
            MsgBox("Check finished. No new update needed.`nLocal: " ScriptVersion "`nServer: " (latest = "" ? "[Empty]" : latest), "VolKnob Fix")
        }
    } catch Error as err {
        if showFeedback {
            ToolTip()
            ; If anything fails, always throw a descriptive popup so you know why
            MsgBox(
                "Error checking for updates!`n`n" .
                "Type: " . Type(err) . "`n" .
                "Message: " . err.Message . "`n" .
                "Line: " . err.Line . "`n" .
                "What: " . err.What, 
                "Update Check Error", "Iconx"
            )
        }
    }
}

; ============ VOLUME UP ============
*Volume_Up::{
    global UpCounter
    if !ShouldFire(&UpCounter) {
        ToolTip("skipped (debounce)")
        SetTimer(() => ToolTip(), -400)
        return
    }
    if GetKeyState("Alt", "P") {
        ToolTip("Volume Up (raw)")
        SoundSetVolume("+" VolStep)
    } else if GetKeyState("Ctrl", "P") {
        ToolTip("Sending Shift+F19")
        Send("+{F19}")
    } else {
        ToolTip("Sending Shift+F22")
        Send("+{F22}")
    }
    SetTimer(() => ToolTip(), -800)
}

; ============ VOLUME DOWN ============
*Volume_Down::{
    global DownCounter
    if !ShouldFire(&DownCounter) {
        ToolTip("skipped (debounce)")
        SetTimer(() => ToolTip(), -400)
        return
    }
    if GetKeyState("Alt", "P") {
        ToolTip("Volume Down (raw)")
        SoundSetVolume("-" VolStep)
    } else if GetKeyState("Ctrl", "P") {
        ToolTip("Sending Shift+F20")
        Send("+{F20}")
    } else {
        ToolTip("Sending Shift+F23")
        Send("+{F23}")
    }
    SetTimer(() => ToolTip(), -800)
}

; ============ MUTE (push button — no debounce needed) ============
*Volume_Mute::{
    if GetKeyState("Alt", "P") {
        ToolTip("Mute toggle (raw)")
        SoundSetMute(-1)
    } else if GetKeyState("Ctrl", "P") {
        ToolTip("Sending Shift+F21")
        Send("+{F21}")
    } else {
        ToolTip("Sending Shift+F24")
        Send("+{F24}")
    }
    SetTimer(() => ToolTip(), -800)
}