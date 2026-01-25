build:
	swift build

run:
	swift run

format:
	swift format -i Sources/**/*.swift

release:
	./build_app.sh

install: release
	rm -rf /Applications/SimpleEditor.app
	mv dist/SimpleEditor.app /Applications/
