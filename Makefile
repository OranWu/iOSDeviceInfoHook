THEOS_DEVICE_IP = 192.168.0.122
ARCHS = arm64
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = asophoneinfo
asophoneinfo_FILES = Tweak.xm
asophoneinfo_FRAMEWORKS = UIKit Foundation IOKit
asophoneinfo_PRIVATE_FRAMEWORKS = IOKit
asophoneinfo_LIBRARIES = MobileGestalt


include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 AppStore"
