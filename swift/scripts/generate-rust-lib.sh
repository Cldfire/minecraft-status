set -x
set -e
# Location of rust project
RUST_PROJ="../rust"
# Location of the lib folder in the XCode project
XCODE_PROJ_LIB="$PROJECT_DIR/mcping-widget-lib"
# Provide access to Rust utilities
PATH="$HOME/.cargo/bin:$PATH"

if [ $CONFIGURATION = "Release" ]
then
    export RELEASE_OR_DEBUG="release"
else
    export RELEASE_OR_DEBUG="debug"
fi

cd "$RUST_PROJ"

AARCH64_OBJECT_PATH=target/aarch64-apple-ios/$RELEASE_OR_DEBUG/libmcping_widget.a
X86_OBJECT_PATH=target/x86_64-apple-ios/$RELEASE_OR_DEBUG/libmcping_widget.a
UNIVERSAL_OBJECT_PATH=$XCODE_PROJ_LIB/mcping_widget.a
HEADER_FILE_PATH=$XCODE_PROJ_LIB/mcping_widget.h

# Build for iOS architectures
if [ $RELEASE_OR_DEBUG = "release" ]
then
    cargo build --release --target aarch64-apple-ios
    cargo build --release --target x86_64-apple-ios
else
    cargo build --target aarch64-apple-ios
    cargo build --target x86_64-apple-ios
fi

# We only want to perform these actions if cargo had to rebuild something (the file cargo generated has a newer timestamp
#   than what we generated the last time cargo rebuilt something) or if the header file doesn't exist
#
# This keeps live-updating previews working in the swiftui code
#
# TODO: if you build for debug, then build for release, then build for debug again, this will not overwrite the release version
if [ $AARCH64_OBJECT_PATH -nt $UNIVERSAL_OBJECT_PATH -o ! -a $HEADER_FILE_PATH ]
then
    # Generate C bindings
    cbindgen -l C -o $HEADER_FILE_PATH
    # Combine object files into a universal library
    lipo -create $AARCH64_OBJECT_PATH $X86_OBJECT_PATH -output $UNIVERSAL_OBJECT_PATH
fi
