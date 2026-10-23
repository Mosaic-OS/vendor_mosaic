PRODUCT_PRODUCT_PROPERTIES += ro.config.wallpaper=/product/media/wallpaper_default.png

PRODUCT_COPY_FILES += \
    vendor/mosaic/MosaicWallpapers/res/drawable-nodpi/wallpaper_default.png:$(TARGET_COPY_OUT_PRODUCT)/media/wallpaper_default.png \
    $(call find-copy-subdir-files,*,vendor/mosaic/fonts/prebuilt,$(TARGET_COPY_OUT_PRODUCT)/fonts) \
	vendor/mosaic/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip \
	vendor/mosaic/bootanimation-dark.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation-dark.zip \
	vendor/mosaic/etc/init/mosaic-theme.rc:$(TARGET_COPY_OUT_PRODUCT)/etc/init/mosaic-theme.rc

MOSAIC_ASSISTANT_4B_DEVICES := husky tokay caiman komodo frankel blazer mustang rango

ifneq ($(filter $(MOSAIC_ASSISTANT_4B_DEVICES) $(addprefix aosp_,$(MOSAIC_ASSISTANT_4B_DEVICES)),$(TARGET_PRODUCT)),)
MOSAIC_ASSISTANT_TIER := 4b
else
MOSAIC_ASSISTANT_TIER := 2b
endif

MOSAIC_ORT_AAR := vendor/mosaic/prebuilts/onnxruntime/onnxruntime-android-1.31.0.aar
ifeq ($(wildcard $(MOSAIC_ORT_AAR)),)
$(error Download the pinned TTS runtime with vendor/mosaic/download-models.sh ort)
endif

MOSAIC_MODEL_CATALOG := vendor/mosaic/catalog/catalog-$(MOSAIC_ASSISTANT_TIER).json
ifeq ($(wildcard $(MOSAIC_MODEL_CATALOG)),)
$(error Generate the offline model catalogs with vendor/mosaic/generate-model-catalog.py after download-models.sh all)
endif
PRODUCT_COPY_FILES += \
    $(MOSAIC_MODEL_CATALOG):$(TARGET_COPY_OUT_PRODUCT)/etc/mosaic/model-catalog.json

MOSAIC_BUNDLE_MODELS ?= false
ifeq ($(MOSAIC_BUNDLE_MODELS),true)
MOSAIC_BUNDLED_CHAT := $(if $(filter 4b,$(MOSAIC_ASSISTANT_TIER)),Qwen3.5-4B-UD-Q4_K_XL.gguf,Qwen3.5-2B-UD-Q4_K_XL.gguf)
PRODUCT_COPY_FILES += \
    vendor/mosaic/models/$(MOSAIC_BUNDLED_CHAT):$(TARGET_COPY_OUT_PRODUCT)/etc/mosaic/bundled-models/$(MOSAIC_BUNDLED_CHAT) \
    vendor/mosaic/models/whisper-base.en-q8_0.bin:$(TARGET_COPY_OUT_PRODUCT)/etc/mosaic/bundled-models/whisper-base.en-q8_0.bin
endif

MOSAIC_TABITI_PERMISSIONS := default-permissions-tabiti.xml
MOSAIC_TABITI_PERMISSIONS_DIR := $(TARGET_COPY_OUT_SYSTEM_EXT)/etc/default-permissions
PRODUCT_COPY_FILES += \
    vendor/mosaic/etc/$(MOSAIC_TABITI_PERMISSIONS):$(MOSAIC_TABITI_PERMISSIONS_DIR)/$(MOSAIC_TABITI_PERMISSIONS)

PRODUCT_PACKAGES_ARM64 += \
    Tabiti

MOSAIC_SCREEN_OFF_OPTICAL_UDFPS_DEVICES := oriole raven bluejay panther cheetah lynx shiba husky akita tegu

ifneq ($(filter $(MOSAIC_SCREEN_OFF_OPTICAL_UDFPS_DEVICES) $(addprefix aosp_,$(MOSAIC_SCREEN_OFF_OPTICAL_UDFPS_DEVICES)),$(TARGET_PRODUCT)),)
PRODUCT_PACKAGES += MosaicOpticalUdfpsOverlay
endif

PRODUCT_PACKAGES += \
    MosaicWallpapers \
    fonts_customization.xml \
    FontAccuratistOverlay \
    FontAclonicaOverlay \
    FontAmaranteOverlay \
    FontBariolOverlay \
    FontCagliostroOverlay \
    FontCoconOverlay \
    FontComfortaaOverlay \
    FontComicSansOverlay \
    FontCookieRunOverlay \
    FontCoolstoryOverlay \
    FontExotwoOverlay \
    FontFifa2018Overlay \
    FontGrandHotelOverlay \
    FontGoogleSansFlexOverlay \
    FontHarmonySansOverlay \
    FontIBMPlexSansOverlay \
    FontLatoOverlay \
    FontLinotteOverlay \
    FontNokiaPureOverlay \
    FontNothingDotHeadlineOverlay \
    FontNothingDotOverlay \
    FontNunitoOverlay \
    FontOnePlusSansOverlay \
    FontOnePlusSlateOverlay \
    FontOswaldOverlay \
    FontPlayOverlay \
    FontQuandoOverlay \
    FontRedressedOverlay \
    FontReemKufiOverlay \
    FontRobotoCondensedOverlay \
    FontRookeryOverlay \
    FontRubikOverlay \
    FontSanFranciscoDisplayProSourceOverlay \
    FontSamsungOneOverlay \
    FontSansSerifOverlay \
    FontSonySketchOverlay \
    FontStoropiaOverlay \
    FontSurferOverlay \
    FontUbuntuOverlay \
    SystemUIOverlay \
    SystemUIClocks-BigNum \
    SystemUIClocks-Calligraphy \
    SystemUIClocks-Growth \
    SystemUIClocks-Inflate \
    SystemUIClocks-Metro \
    SystemUIClocks-NumOverlap \
	SystemUIClocks-Weather
