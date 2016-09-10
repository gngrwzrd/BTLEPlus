#!/bin/bash

JAZZY="$(which jazzy)"
if [ -z "$JAZZY" ]; then
    echo "Jazzy gem required."
    echo "sudo gem install jazzy"
fi

echo "Generate BTLEPlus Framework Docs."
jazzy jazzy --xcodebuild-arguments \
"-scheme,BTLEPlus,-workspace,BTLEPlus.xcworkspace" \
--theme="Jazzy/BTLEPlus/" \
--output="Docs/BTLEPlus" \
--exclude="BTLEPlus/BTLEPlus/BLEPlusSerialServiceProtocolMessage-DocExclude.swift"

echo "Generate BTLEPlusIOS Framework Docs"
jazzy jazzy --xcodebuild-arguments "-scheme,BTLEPlusIOS,-workspace,BTLEPlus.xcworkspace" --theme="Jazzy/BTLEPlus/" --output="Docs/BTLEPlusIOS"
