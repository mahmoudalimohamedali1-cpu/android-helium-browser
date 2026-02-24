#!/bin/bash
source common.sh
set_keys
export VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' vanadium/args.gn)
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt install -y sudo lsb-release file nano git curl python3 python3-pillow

# https://github.com/uazo/cromite/blob/master/tools/images/chr-source/prepare-build.sh
git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
mkdir -p chromium/src/out/Default; cd chromium
gclient root; cd src
git init
git remote add origin $CHROMIUM_SOURCE
git fetch --depth 2 $CHROMIUM_SOURCE +refs/tags/$VERSION:chromium_$VERSION
git checkout $VERSION
export COMMIT=$(git show-ref -s $VERSION | head -n1)
cat > ../.gclient <<EOF
solutions = [
  {
    "name": "src",
    "url": "$CHROMIUM_SOURCE@$COMMIT",
    "deps_file": "DEPS",
    "managed": False,
    "custom_vars": {
      "checkout_android_prebuilts_build_tools": True,
      "checkout_telemetry_dependencies": False,
      "codesearch": "Debug",
    },
  },
]
target_os = ["android"]
EOF
git submodule foreach git config -f ./.git/config submodule.$name.ignore all
git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'

# Apply Vanadium security patches with Sneptuob branding
replace "$SCRIPT_DIR/vanadium/patches" "VANADIUM" "SNEPTUOB"
replace "$SCRIPT_DIR/vanadium/patches" "Vanadium" "Sneptuob"
replace "$SCRIPT_DIR/vanadium/patches" "vanadium" "sneptuob"
git am --whitespace=nowarn --keep-non-patch $SCRIPT_DIR/vanadium/patches/*.patch

gclient sync -D --no-history --nohooks
gclient runhooks
rm -rf third_party/angle/third_party/VK-GL-CTS/
./build/install-build-deps.sh --no-prompt

# ========== Sneptuob Custom Patches ==========

# 1. Enable MV2 extensions (keep both MV2 and MV3 working)
sed -i 's/BASE_FEATURE(kExtensionManifestV2Unsupported, base::FEATURE_ENABLED_BY_DEFAULT);/BASE_FEATURE(kExtensionManifestV2Unsupported, base::FEATURE_DISABLED_BY_DEFAULT);/' extensions/common/extension_features.cc
sed -i 's/BASE_FEATURE(kExtensionManifestV2Disabled, base::FEATURE_ENABLED_BY_DEFAULT);/BASE_FEATURE(kExtensionManifestV2Disabled, base::FEATURE_DISABLED_BY_DEFAULT);/' extensions/common/extension_features.cc

# 2. Enable extension toolbar on phone layout
sed -i '/<ViewStub/{N;N;N;N;N;N; /optional_button_stub/a\
\
        <ViewStub\
            android:id="@+id/extension_toolbar_container_stub"\
            android:inflatedId="@+id/extension_toolbar_container"\
            android:layout_width="wrap_content"\
            android:layout_height="match_parent" />
}' chrome/browser/ui/android/toolbar/java/res/layout/toolbar_phone.xml
sed -i 's/extension_toolbar_baseline_width">600dp/extension_toolbar_baseline_width">0dp/' chrome/browser/ui/android/extensions/java/res/values/dimens.xml

# 3. Sneptuob branding in strings
sed -i 's/app_name">Chromium/app_name">Sneptuob/' chrome/android/java/res/values/channel_constants.xml 2>/dev/null || true
sed -i 's/app_name">Chrome/app_name">Sneptuob/' chrome/android/java/res/values/channel_constants.xml 2>/dev/null || true

# 4. Generate Sneptuob launcher icons (S with gradient)
python3 $SCRIPT_DIR/generate_icons.py .

# 5. iOS-inspired color theme
# Toolbar & primary colors - clean white/light gray like Safari
for f in chrome/android/java/res/values/colors.xml chrome/browser/ui/android/theme/java/res/values/colors.xml; do
    if [ -f "$f" ]; then
        # Light mode: white toolbar, blue accents (iOS system blue)
        sed -i 's|"default_bg_color">#[0-9A-Fa-f]\{6\}|"default_bg_color">#FFFFFF|g' "$f" 2>/dev/null || true
        sed -i 's|"default_bg_color_dark">#[0-9A-Fa-f]\{6\}|"default_bg_color_dark">#1C1C1E|g' "$f" 2>/dev/null || true
        sed -i 's|"default_text_color_link">#[0-9A-Fa-f]\{6\}|"default_text_color_link">#007AFF|g' "$f" 2>/dev/null || true
    fi
done

# Override toolbar colors in theme files
for f in $(find chrome/android/java/res/values components/browser_ui/theme/android/java/res/values -name 'colors.xml' -o -name 'themes.xml' 2>/dev/null); do
    if [ -f "$f" ]; then
        # iOS blue accent color
        sed -i 's|"default_control_color_active">#[0-9A-Fa-f]\{6\}|"default_control_color_active">#007AFF|g' "$f" 2>/dev/null || true
    fi
done

# Dark mode: iOS-style pure black background
for f in $(find chrome/android/java/res/values-night -name 'colors.xml' 2>/dev/null); do
    if [ -f "$f" ]; then
        sed -i 's|"default_bg_color">#[0-9A-Fa-f]\{6\}|"default_bg_color">#000000|g' "$f" 2>/dev/null || true
    fi
done

# UI color palette - iOS system colors
PALETTE_FILE="ui/android/java/res/values/color_palette.xml"
if [ -f "$PALETTE_FILE" ]; then
    # iOS blue for interactive elements
    sed -i 's|"default_icon_color_blue">#[0-9A-Fa-f]\{6\}|"default_icon_color_blue">#007AFF|g' "$PALETTE_FILE" 2>/dev/null || true
fi

# 7. Apply Sneptuob custom patches if they exist
if [ -d "$SCRIPT_DIR/patches" ]; then
    for patch in $SCRIPT_DIR/patches/*.patch; do
        if [ -f "$patch" ]; then
            echo "Applying Sneptuob patch: $patch"
            git am --whitespace=nowarn --keep-non-patch "$patch" || git am --abort
        fi
    done
fi

# ========== Build Configuration ==========
cat > out/Default/args.gn <<EOF
# Sneptuob Browser - Chromium-based with native extension support
chrome_public_manifest_package = "com.brow.spear"
is_desktop_android = true
target_os = "android"
target_cpu = "arm64"
is_component_build = false
is_debug = false
is_official_build = true
symbol_level = 0
disable_fieldtrial_testing_config = true
ffmpeg_branding = "Chrome"
proprietary_codecs = true
enable_vr = false
enable_arcore = false
enable_openxr = false
enable_cardboard = false
enable_remoting = false
enable_reporting = false
google_api_key = "x"
google_default_client_id = "x"
google_default_client_secret = "x"

blink_symbol_level=0
build_contextual_search=false
build_with_tflite_lib=true
chrome_pgo_phase=0
dcheck_always_on=false
enable_hangout_services_extension=false
enable_iterator_debugging=false
enable_mdns=false
exclude_unwind_tables=false
icu_use_data_file=true
rtc_build_examples=false
use_debug_fission=false
use_thin_lto=false
use_errorprone_java_compiler=false
use_official_google_api_keys=false
use_rtti=false
enable_av1_decoder=true
enable_dav1d_decoder=true
include_both_v8_snapshots = false
include_both_v8_snapshots_android_secondary_abi = false
generate_linker_map = false
EOF

gn gen out/Default
autoninja -C out/Default chrome_public_apk

export PATH=$PWD/third_party/jdk/current/bin/:$PATH
export ANDROID_HOME=$PWD/third_party/android_sdk/public
mkdir -p out/Default/apks/release
sign_apk $(find out/Default/apks -name 'Chrome*.apk') out/Default/apks/release/Sneptuob-$VERSION.apk
