#!/bin/bash
echo "Starting archive..."
cd ~/Developer/HomeLink
xcodebuild clean -scheme HomeLink
xcodebuild archive \
  -scheme HomeLink \
  -archivePath ~/Developer/HomeLink/build/HomeLink.xcarchive \
  -allowProvisioningUpdates
echo "Archive complete!"
echo "Open Xcode Organizer to distribute"
open -a Xcode
