PRODUCT_PRODUCT_PROPERTIES += ro.config.wallpaper=/product/media/wallpaper_default.png

PRODUCT_COPY_FILES += \
    vendor/mosaic/MosaicWallpapers/res/drawable-nodpi/wallpaper_default.png:$(TARGET_COPY_OUT_PRODUCT)/media/wallpaper_default.png \
    $(call find-copy-subdir-files,*,vendor/mosaic/fonts/prebuilt,$(TARGET_COPY_OUT_PRODUCT)/fonts) \
	vendor/mosaic/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip \
	vendor/mosaic/bootanimation-dark.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation-dark.zip \
	vendor/mosaic/etc/init/mosaic-theme.rc:$(TARGET_COPY_OUT_PRODUCT)/etc/init/mosaic-theme.rc

MOSAIC_ASSISTANT_4B_DEVICES := husky tokay caiman komodo frankel blazer mustang rango

ifneq ($(filter $(MOSAIC_ASSISTANT_4B_DEVICES) $(addprefix aosp_,$(MOSAIC_ASSISTANT_4B_DEVICES)),$(TARGET_PRODUCT)),)
MOSAIC_ASSISTANT_MODEL := vendor/mosaic/models/Qwen3.5-4B-UD-Q4_K_XL.gguf
else
MOSAIC_ASSISTANT_MODEL := vendor/mosaic/models/Qwen3.5-2B-UD-Q4_K_XL.gguf
endif

ifeq ($(wildcard $(MOSAIC_ASSISTANT_MODEL)),)
MOSAIC_ASSISTANT_MODEL := $(firstword $(sort $(wildcard vendor/mosaic/models/*.gguf)))
endif
ifneq ($(MOSAIC_ASSISTANT_MODEL),)
PRODUCT_COPY_FILES += \
    $(MOSAIC_ASSISTANT_MODEL):$(TARGET_COPY_OUT_PRODUCT)/etc/mosaic/models/$(notdir $(MOSAIC_ASSISTANT_MODEL))
endif

MOSAIC_WHISPER_MODEL := $(wildcard vendor/mosaic/models/whisper-*.bin)
ifneq ($(MOSAIC_WHISPER_MODEL),)
PRODUCT_COPY_FILES += \
    $(foreach model,$(MOSAIC_WHISPER_MODEL),\
        $(model):$(TARGET_COPY_OUT_PRODUCT)/etc/mosaic/models/$(notdir $(model)))
endif

PRODUCT_COPY_FILES += \
    vendor/mosaic/etc/default-permissions-mosaic-assistant.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/default-permissions/default-permissions-mosaic-assistant.xml

PRODUCT_PACKAGES += \
    MosaicAssistant \
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
