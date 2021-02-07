if which mint >/dev/null; then
    mint run swiftformat $SRCROOT
else
    echo "warning: Mint not installed, see setup instructions in README"
fi
