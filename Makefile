.PHONY: build test app run install clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

run: app
	open "dist/PR Status.app"

install: app
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/PR Status.app"
	cp -R "dist/PR Status.app" "$(HOME)/Applications/PR Status.app"
	open "$(HOME)/Applications/PR Status.app"

clean:
	swift package clean
	rm -rf dist
