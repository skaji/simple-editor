build:
	swift build

run:
	swift run

format:
	swift format -i Sources/**/*.swift

release:
	./build_app.sh
