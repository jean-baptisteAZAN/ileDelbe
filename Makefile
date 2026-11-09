.PHONY: test adapter app run clean

test:
	swift test

adapter:
	scripts/build-adapter.sh

app: adapter
	scripts/bundle-app.sh

run: app
	open build/IleDelbe.app

clean:
	rm -rf .build build Vendor/mediaremote-adapter/build
