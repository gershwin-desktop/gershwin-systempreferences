RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make
GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

BUNDLE_NAME = DesktopBackground
BUNDLE_EXTENSION = .prefPane

DesktopBackground_HAS_RESOURCE_BUNDLE = yes

OBJCFLAGS += -Wall

DesktopBackground_OBJC_FILES = DesktopBackgroundPreferences.m DesktopBackgroundSettings.m

DesktopBackground_PRINCIPAL_CLASS = DesktopBackgroundPreferences

DesktopBackground_RESOURCE_FILES = \
DesktopBackground.tiff \
Resources/English.lproj 

DesktopBackground_LANGUAGES = \
Resources/English

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ADDITIONAL_GUI_LIBS += -lGSPreferencePanes
else
  ADDITIONAL_GUI_LIBS += -lPreferencePanes
endif

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble


