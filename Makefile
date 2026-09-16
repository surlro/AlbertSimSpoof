THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 54321

TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlbertSimSpoof

AlbertSimSpoof_FILES = Tweak.xm
AlbertSimSpoof_CFLAGS = -fobjc-arc
AlbertSimSpoof_FRAMEWORKS = Foundation
AlbertSimSpoof_PRIVATE_FRAMEWORKS = MobileActivation

include $(THEOS)/makefiles/tweak.mk
