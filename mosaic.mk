PRODUCT_PRODUCT_PROPERTIES += ro.config.wallpaper=/product/media/wallpaper_default.png

PRODUCT_COPY_FILES += \
    vendor/mosaic/MosaicWallpapers/res/drawable-nodpi/wallpaper_default.png:$(TARGET_COPY_OUT_PRODUCT)/media/wallpaper_default.png \
    $(call find-copy-subdir-files,*,vendor/mosaic/fonts/prebuilt,$(TARGET_COPY_OUT_PRODUCT)/fonts) \
	vendor/mosaic/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip \
	vendor/mosaic/bootanimation-dark.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation-dark.zip \
	vendor/mosaic/etc/init/mosaic-theme.rc:$(TARGET_COPY_OUT_PRODUCT)/etc/init/mosaic-theme.rc

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
