RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

BUNDLE_NAME = Dock
BUNDLE_EXTENSION = .prefPane

Dock_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

Dock_OBJC_FILES = DockPreferences.m DockSettings.m 

Dock_PRINCIPAL_CLASS = DockPreferences

Dock_RESOURCE_FILES = \
Dock.tiff \
Resources/English.lproj 

Dock_LANGUAGES = \
Resources/English

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ADDITIONAL_GUI_LIBS += -lGSPreferencePanes
else
  ADDITIONAL_GUI_LIBS += -lPreferencePanes
endif

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble


