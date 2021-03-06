# -----------------------------------------------------------------------------
# Overridable definitions
# -----------------------------------------------------------------------------
!ifndef VERSION
  !define VERSION v1.0.0
!endif

!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSON 1.0.0.0
!endif

!ifndef NAME
  !define NAME PlinkProxy
!endif

!ifndef RELEASE_DIR
  !define RELEASE_DIR ..\releases
!endif


# Single user/"Just me" installer
RequestExecutionLevel User

# define installer name
OutFile "..\releases\${NAME}_${VERSION}_Installer.exe"

# set desktop as install directory
InstallDir $APPDATA\${NAME}

# set icon from the src directory
Icon ../src/PlinkProxy.ico

# set title of installer window
Caption "${NAME} OneClick Installer"
UninstallCaption "${NAME} OneClick Uninstaller"

# -----------------------------------------------------------------------------
# Package Metadata
# -----------------------------------------------------------------------------
VIFileVersion ${PRODUCT_VERSION}
VIProductVersion ${PRODUCT_VERSION}
VIAddVersionKey /LANG=1033 ProductName "${NAME} Installer"
VIAddVersionKey /LANG=1033 Comments "${NAME} Installer"
VIAddVersionKey /LANG=1033 CompanyName "Urs Roesch"
VIAddVersionKey /LANG=1033 LegalCopyright "2019-2020 Urs Roesch"
VIAddVersionKey /LANG=1033 FileDescription "${NAME} ${VERSION} Installer"
VIAddVersionKey /LANG=1033 FileVersion "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=1033 ProductVersion "${VERSION}"
VIAddVersionKey /LANG=1033 InternalName "${Name} Installer"
VIAddVersionKey /LANG=1033 OriginalFilename "${Name}_${Version}_Installer.exe"


# -----------------------------------------------------------------------------
# Create Start Menu Entries
# -----------------------------------------------------------------------------
Section -StartMenu
  CreateDirectory "$SMPrograms\${NAME}"
  CreateShortCut "$SMPROGRAMS\${NAME}\${NAME}.lnk" "$INSTDIR\${NAME}.exe"
SectionEnd

# -----------------------------------------------------------------------------
# Installer -> Default Section
# -----------------------------------------------------------------------------
Section
  # define output path
  SetOutPath $INSTDIR

  # specify file to go in output path
  File /r ${RELEASE_DIR}\${NAME}_${VERSION}\*.*

  # define uninstaller name
  WriteUninstaller $INSTDIR\uninstaller.exe
SectionEnd

# -----------------------------------------------------------------------------
# Uninstaller
# -----------------------------------------------------------------------------

# create a section to define what the uninstaller does.
# the section will always be named "Uninstall"
Section "Uninstall"
  # Always delete uninstaller first
  Delete $INSTDIR\uninstaller.exe

  # delete installed file
  Delete $INSTDIR/*.*

  # Delete the directory
  RMDIR /r $INSTDIR
  RMDIR /r $SMPrograms\${NAME}
SectionEnd
