.PHONY: test adapter app run release readme-assets clean

test:
	swift test

adapter:
	scripts/build-adapter.sh

app: adapter
	scripts/bundle-app.sh

run: app
	open build/IleDelbe.app

# Zip in build/: Developer ID signed with DEVELOPER_ID_APP, notarized with NOTARY_PROFILE, ad hoc otherwise.
release:
	scripts/release.sh

# Regenerates the README images in docs/assets from the real views (sample data only).
readme-assets:
	swift build -c release
	"$$(swift build -c release --show-bin-path)/IleDelbe" --render-readme-assets docs/assets

clean:
	rm -rf .build build Vendor/mediaremote-adapter/build
