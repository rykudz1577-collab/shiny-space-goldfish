; =====================================================================
; Antares Launcher 3.0 — NSIS installer (spec 3.0 mục 65, 66)
;
; Tính năng đúng mục 66:
;   - Install            : cài vào $LOCALAPPDATA\Programs\Antares Launcher
;   - Repair             : entry "Repair" trong Add/Remove Programs — chạy lại
;                          installer với /R (cài đè, giữ user data)
;   - Uninstall          : gỡ program files, GIỮ data user (an toàn, mục 74);
;                          tuỳ chọn xoá data qua checkbox lúc uninstall
;   - Portable extraction: chạy `Antares-Setup.exe /PORTABLE=<dir>` giải nén
;                          layout portable (app/ data/ cache/) không cài
;   - Create shortcut    : Start Menu + Desktop (tuỳ chọn)
;   - Start on launch    : registry Run key (tuỳ chọn, checkbox)
;   - File associations  : .mrpack, .zip (resource pack project),
;                          .antares (visual project) — có checkbox riêng
;
; Build (trên máy Windows có NSIS):
;   makensis /DVERSION=1.0.0 /DEXE=dist\Antares\Antares.exe packaging\installer.nsi
; =====================================================================

!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!ifndef EXE
  !define EXE "dist\AntaresLauncher.exe"
!endif

!define APPNAME      "Antares Launcher"
!define COMPANY      "Antares"
!define EXEFILENAME  "Antares.exe"          ; khớp name= trong antares.spec
!define INSTALLROOT  "$LOCALAPPDATA\Programs\Antares Launcher"
!define UNINSTKEY    "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
!define RUNKEY       "Software\Microsoft\Windows\CurrentVersion\Run"

Unicode true
ManifestDPIAware true
RequestExecutionLevel user        ; per-user install — không cần admin (mục 74)
SetCompressor /SOLID lzma
InstallDir "${INSTALLROOT}"
Name "${APPNAME} ${VERSION}"
OutFile "dist\Antares-Setup-${VERSION}.exe"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "© ${COMPANY}"

; ---------------------------------------------------------------
; Trang cài đặt
; ---------------------------------------------------------------
!include "MUI2.nsh"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXEFILENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APPNAME}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page customAssocOptions
Page customAssocEnd
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!define MUI_UNCONFIRMPAGE_TEXT_TOP "Gỡ ${APPNAME}. Dữ liệu người dùng (instances, backups, cài đặt) sẽ được GIỮ."
!insertmacro MUI_UNPAGE_CONFIRM
UninstPage customUnDataOptions
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------
; Biến lựa chọn
; ---------------------------------------------------------------
Var AssocMrpack
Var AssocZip
Var AssocAntares
Var StartOnLaunch
Var DesktopShortcut
Var UninstallRemoveData

; ---------------------------------------------------------------
; Trang tuỳ chọn: associations + shortcuts + autorun
; ---------------------------------------------------------------
Function customAssocOptions
  !insertmacro MUI_HEADER_TEXT "Tuỳ chọn tích hợp" "Chọn cách ${APPNAME} tích hợp với hệ thống."
  nsDialogs::Create 1018
  Pop $0

  ${NSD_CreateCheckbox} 0 0u 100% 10u "File association: .mrpack (Modrinth pack)"
  Pop $0
  ${NSD_SetState} $0 ${BST_CHECKED}
  StrCpy $AssocMrpack $0

  ${NSD_CreateCheckbox} 0 14u 100% 10u "File association: .zip (resource pack project)"
  Pop $0
  ${NSD_SetState} $0 ${BST_CHECKED}
  StrCpy $AssocZip $0

  ${NSD_CreateCheckbox} 0 28u 100% 10u "File association: .antares (visual project)"
  Pop $0
  ${NSD_SetState} $0 ${BST_CHECKED}
  StrCpy $AssocAntares $0

  ${NSD_CreateCheckbox} 0 46u 100% 10u "Khởi động cùng Windows"
  Pop $0
  StrCpy $StartOnLaunch $0

  ${NSD_CreateCheckbox} 0 60u 100% 10u "Tạo shortcut Desktop"
  Pop $0
  ${NSD_SetState} $0 ${BST_CHECKED}
  StrCpy $DesktopShortcut $0

  nsDialogs::Show
FunctionEnd

Function customAssocEnd
  ${NSD_GetState} $AssocMrpack   $0
  StrCpy $AssocMrpack   $0
  ${NSD_GetState} $AssocZip      $0
  StrCpy $AssocZip      $0
  ${NSD_GetState} $AssocAntares  $0
  StrCpy $AssocAntares  $0
  ${NSD_GetState} $StartOnLaunch $0
  StrCpy $StartOnLaunch $0
  ${NSD_GetState} $DesktopShortcut $0
  StrCpy $DesktopShortcut $0
FunctionEnd

; Trang uninstall: hỏi có xoá data user không (mặc định: giữ)
Function customUnDataOptions
  !insertmacro MUI_HEADER_TEXT "Dữ liệu người dùng" "Chọn có xoá dữ liệu hay không."
  nsDialogs::Create 1018
  Pop $0
  ${NSD_CreateCheckbox} 0 0u 100% 10u "Xoá luôn dữ liệu người dùng (instances, backups, cài đặt)"
  Pop $0
  StrCpy $UninstallRemoveData $0
  nsDialogs::Show
FunctionEnd

; ---------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------

; Đăng ký 1 file association: PROGID riêng + lệnh Open với "%1"
!macro REGISTER_ASSOC EXT PROGID DESC
  WriteRegStr HKCU "Software\Classes\${PROGID}"         "" "${DESC}"
  WriteRegStr HKCU "Software\Classes\${PROGID}\shell\open\command" "" '"$INSTDIR\${EXEFILENAME}" "%1"'
  WriteRegStr HKCU "Software\Classes\${EXT}\OpenWithProgids" "${PROGID}" ""
!macroend

!macro UNREGISTER_ASSOC EXT PROGID
  DeleteRegKey HKCU "Software\Classes\${PROGID}"
  ReadRegStr $0 HKCU "Software\Classes\${EXT}\OpenWithProgids" "${PROGID}"
  ${If} $0 != ""
    DeleteRegValue HKCU "Software\Classes\${EXT}\OpenWithProgids" "${PROGID}"
  ${EndIf}
!macroend

; ---------------------------------------------------------------
; Section cài đặt chính
; ---------------------------------------------------------------
Section "Install"
  SetShellVarContext current
  SetOutPath "$INSTDIR"

  ; --- Portable extraction mode: chỉ giải nén rồi thoát (mục 66) ---
  ${GetOptions} $CMDLINE "/PORTABLE=" $R0
  ${If} ${Errors}
  ${Else}
    DetailPrint "Portable extraction -> $R0"
    SetOutPath "$R0\app"
    File /oname=${EXEFILENAME} "${EXE}"
    SetOutPath "$R0"
    CreateDirectory "$R0\data"
    CreateDirectory "$R0\cache"
    ; portable.flag rỗng — AppPaths đón data tại .\data cạnh app (mục 65,
    ; khớp với build-portable.ps1)
    FileOpen $1 "$R0\portable.flag" w
    FileClose $1
    DetailPrint "Portable xong."
    Return
  ${EndIf}

  ; --- Files ---
  File /oname=${EXEFILENAME} "${EXE}"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; --- Uninstall entry (Add/Remove Programs) ---
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName"     "${APPNAME} ${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion"  "${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher"       "${COMPANY}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon"     "$INSTDIR\${EXEFILENAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 0     ; Repair = chạy lại installer
  WriteRegStr HKCU "${UNINSTKEY}" "RepairCommand"   '"$EXEPATH" /S'

  ; --- Shortcuts ---
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXEFILENAME}"
  CreateShortCut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"
  ${If} $DesktopShortcut != ${BST_UNCHECKED}
    CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXEFILENAME}"
  ${EndIf}

  ; --- Start on launch (mục 66) ---
  ${If} $StartOnLaunch == ${BST_CHECKED}
    WriteRegStr HKCU "${RUNKEY}" "${APPNAME}" '"$INSTDIR\${EXEFILENAME}" --minimized'
  ${EndIf}

  ; --- File associations (mục 66) ---
  ${If} $AssocMrpack == ${BST_CHECKED}
    !insertmacro REGISTER_ASSOC ".mrpack" "Antares.Modpack" "Antares Modpack"
  ${EndIf}
  ${If} $AssocZip == ${BST_CHECKED}
    !insertmacro REGISTER_ASSOC ".zip" "Antares.ResourcePackProject" "Antares Resource Pack Project"
  ${EndIf}
  ${If} $AssocAntares == ${BST_CHECKED}
    !insertmacro REGISTER_ASSOC ".antares" "Antares.VisualProject" "Antares Visual Project"
  ${EndIf}

  ; Gọi SHChangeNotify để Windows nhận association ngay
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

; ---------------------------------------------------------------
; Uninstall
; ---------------------------------------------------------------
Section "Uninstall"
  SetShellVarContext current

  ; Task/process còn chạy -> kết nhẹ nhàng trước khi xoá file
  nsExec::Exec 'taskkill /IM "${EXEFILENAME}" /FI "STATUS eq RUNNING"'

  Delete "$INSTDIR\${EXEFILENAME}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk"
  RMDir  "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"

  DeleteRegKey HKCU "${UNINSTKEY}"
  DeleteRegValue HKCU "${RUNKEY}" "${APPNAME}"

  !insertmacro UNREGISTER_ASSOC ".mrpack"  "Antares.Modpack"
  !insertmacro UNREGISTER_ASSOC ".zip"     "Antares.ResourcePackProject"
  !insertmacro UNREGISTER_ASSOC ".antares" "Antares.VisualProject"

  ; Data user: CHỈ xoá khi người dùng tick (mặc định giữ — mục 74)
  ${If} $UninstallRemoveData == ${BST_CHECKED}
    RMDir /r "$APPDATA\Antares"
  ${Else}
    DetailPrint "Đã giữ dữ liệu người dùng: $APPDATA\Antares"
  ${EndIf}
SectionEnd
