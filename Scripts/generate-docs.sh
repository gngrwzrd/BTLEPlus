#!/bin/bash

JAZZY="$(which jazzy)"
if [ -z "$JAZZY" ]; then
    echo "Jazzy gem required."
    echo "sudo gem install jazzy"
fi

echo "Generate BTLEPlus Framework Docs."
jazzy jazzy --xcodebuild-arguments \
"-scheme,BTLEPlus,-workspace,BTLEPlus.xcworkspace" \
--clean \
--theme="Jazzy/Theme/" \
--output="Docs/BTLEPlus" \
--exclude="BTLEPlus/BTLEPlus/BTLEPlusSerialServiceProtocolMessage-DocExclude.swift" \
--documentation="Jazzy/Guides/*.md"
