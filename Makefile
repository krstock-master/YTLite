ifeq ($(ROOTLESS),1)
THEOS_PACKAGE_SCHEME=rootless
else ifeq ($(ROOTHIDE),1)
THEOS_PACKAGE_SCHEME=roothide
endif

DEBUG=0
FINALPACKAGE=1
ARCHS = arm64
PACKAGE_VERSION = 4.0.0
TARGET := iphone:clang:16.5:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTLite

# ──────────────────────────────────────────────
# Module Toggle System
# Usage: make package ENABLE_SLEEP_TIMER=1 ENABLE_GESTURES=1
# All new modules are OFF by default; core modules always ON
# ──────────────────────────────────────────────

# Core files (always included)
CORE_FILES = YTLite.x Settings.x Sideloading.x YTNativeShare.x
UTIL_FILES = $(wildcard Utils/*.m)

# New feature modules (opt-in via build flags)
MODULE_FILES =

EXTRA_CFLAGS =

ifeq ($(ENABLE_SLEEP_TIMER),1)
MODULE_FILES += Modules/SleepTimer/SleepTimer.x
EXTRA_CFLAGS += -DENABLE_SLEEP_TIMER=1
endif

ifeq ($(ENABLE_GESTURES),1)
MODULE_FILES += Modules/GestureControls/GestureControls.x
EXTRA_CFLAGS += -DENABLE_GESTURES=1
endif

ifeq ($(ENABLE_CLIPBOARD),1)
MODULE_FILES += Modules/ClipboardDetector/ClipboardDetector.x
EXTRA_CFLAGS += -DENABLE_CLIPBOARD=1
endif

ifeq ($(ENABLE_ADBLOCK_PLUS),1)
MODULE_FILES += Modules/AdBlock/AdBlock.x
EXTRA_CFLAGS += -DENABLE_ADBLOCK_PLUS=1
endif

ifeq ($(ENABLE_OLED),1)
MODULE_FILES += Modules/OLEDTheme/OLEDTheme.x
EXTRA_CFLAGS += -DENABLE_OLED=1
endif

ifeq ($(ENABLE_AI_SUMMARY),1)
MODULE_FILES += Modules/AISummary/AISummary.x
EXTRA_CFLAGS += -DENABLE_AI_SUMMARY=1
endif

ifeq ($(ENABLE_AUTO_TRANSLATE),1)
MODULE_FILES += Modules/AutoTranslate/AutoTranslate.x
EXTRA_CFLAGS += -DENABLE_AUTO_TRANSLATE=1
endif

ifeq ($(ENABLE_DOWNLOAD_PLUS),1)
MODULE_FILES += Modules/DownloadPlus/DownloadPlus.x
EXTRA_CFLAGS += -DENABLE_DOWNLOAD_PLUS=1
endif

# Convenience: build everything
ifeq ($(ENABLE_ALL_MODULES),1)
MODULE_FILES += Modules/SleepTimer/SleepTimer.x
MODULE_FILES += Modules/GestureControls/GestureControls.x
MODULE_FILES += Modules/ClipboardDetector/ClipboardDetector.x
MODULE_FILES += Modules/AdBlock/AdBlock.x
MODULE_FILES += Modules/OLEDTheme/OLEDTheme.x
MODULE_FILES += Modules/AISummary/AISummary.x
MODULE_FILES += Modules/AutoTranslate/AutoTranslate.x
MODULE_FILES += Modules/DownloadPlus/DownloadPlus.x
EXTRA_CFLAGS += -DENABLE_SLEEP_TIMER=1 -DENABLE_GESTURES=1 -DENABLE_CLIPBOARD=1 -DENABLE_ADBLOCK_PLUS=1 -DENABLE_OLED=1 -DENABLE_AI_SUMMARY=1 -DENABLE_AUTO_TRANSLATE=1 -DENABLE_DOWNLOAD_PLUS=1
endif

# ──────────────────────────────────────────────
# Build Configuration
# ──────────────────────────────────────────────
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation SystemConfiguration AVFoundation MediaPlayer
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -DTWEAK_VERSION=$(PACKAGE_VERSION) $(EXTRA_CFLAGS)
$(TWEAK_NAME)_FILES = $(CORE_FILES) $(UTIL_FILES) $(MODULE_FILES)

include $(THEOS_MAKE_PATH)/tweak.mk
