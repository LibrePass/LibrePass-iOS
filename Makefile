DESTDIR = Build/Release-iphoneos
XCODEBUILD ?= xcodebuild

$(DESTDIR)/LibrePass.ipa: $(DESTDIR)/LibrePass.app
	cd $(DESTDIR) && \
		mkdir -p Payload && \
		cp -pr LibrePass.app Payload && \
		zip -r LibrePass.ipa Payload

$(DESTDIR)/LibrePass.app:
	    xcodebuild -project LibrePass.xcodeproj -scheme LibrePass -sdk iphoneos -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO SYMROOT=$(PWD)/Build

clean:
	rm -rf Build
