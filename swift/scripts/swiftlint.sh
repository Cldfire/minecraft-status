if which mint >/dev/null; then
    cd $SRCROOT/../
    xcrun --sdk macosx mint run swiftlint
else
    echo "warning: Mint not installed, see setup instructions in README"
fi
