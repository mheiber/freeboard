APP_NAME = Freeboard
BUILD_DIR = build/Debug
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build run prod clean kill

build:
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug SYMROOT=$(CURDIR)/build

run: kill build
	open $(APP_BUNDLE)

kill:
	-killall $(APP_NAME) 2>/dev/null; sleep 0.5

prod:
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release SYMROOT=$(CURDIR)/build
	-killall $(APP_NAME) 2>/dev/null; sleep 0.5
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R build/Release/$(APP_NAME).app $(INSTALL_DIR)/$(APP_NAME).app
	open $(INSTALL_DIR)/$(APP_NAME).app

clean:
	rm -rf build
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) clean
