#!/bin/bash

set -e -u

THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)
PROJECT_REPO=$(realpath ${THIS_DIR}/../..)
RELEASE_REPO=$(realpath ${THIS_DIR}/../../../jitsi-meet-ios-sdk-releases)
DEFAULT_SDK_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${THIS_DIR}/../sdk/src/Info.plist)
SDK_VERSION=${OVERRIDE_SDK_VERSION:-${DEFAULT_SDK_VERSION}}
DO_GIT_TAG=${GIT_TAG:-0}


echo "Releasing SEF Digital Meet SDK ${SDK_VERSION}"

pushd ${RELEASE_REPO}

# Generate podspec file
cat JitsiMeetSDK.podspec.tpl | sed -e s/VERSION/${SDK_VERSION}/g > JitsiMeetSDK.podspec

# Cleanup
rm -rf Frameworks/*

popd

# Build the SDK
pushd ${PROJECT_REPO}
rm -rf ios/sdk/out
xcodebuild clean \
    -workspace ios/jitsi-meet.xcworkspace \
    -scheme JitsiMeetSDK
xcodebuild archive \
    -workspace ios/jitsi-meet.xcworkspace \
    -scheme JitsiMeetSDK  \
    -configuration Release \
    -sdk iphonesimulator \
    -destination='generic/platform=iOS Simulator' \
    -archivePath ios/sdk/out/ios-simulator \
    VALID_ARCHS=x86_64 \
    ENABLE_BITCODE=NO \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
xcodebuild archive \
    -workspace ios/jitsi-meet.xcworkspace \
    -scheme JitsiMeetSDK  \
    -configuration Release \
    -sdk iphoneos \
    -destination='generic/platform=iOS' \
    -archivePath ios/sdk/out/ios-device \
    VALID_ARCHS=arm64 \
    ENABLE_BITCODE=NO \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
xcodebuild -create-xcframework \
    -framework ios/sdk/out/ios-device.xcarchive/Products/Library/Frameworks/JitsiMeetSDK.framework \
    -framework ios/sdk/out/ios-simulator.xcarchive/Products/Library/Frameworks/JitsiMeetSDK.framework \
    -output ios/sdk/out/JitsiMeetSDK.xcframework
if [[ $DO_GIT_TAG == 1 ]]; then
    git tag ios-sdk-${SDK_VERSION}
fi
popd

pushd ${RELEASE_REPO}

# Put the new files in the repo
cp -a ${PROJECT_REPO}/ios/sdk/out/JitsiMeetSDK.xcframework Frameworks/
cp -a ${PROJECT_REPO}/node_modules/react-native-webrtc/apple/WebRTC.xcframework Frameworks/

# Add all files to git
if [[ $DO_GIT_TAG == 1 ]]; then
    git add -A .
    git commit -m "${SDK_VERSION}"
    git tag ${SDK_VERSION}
fi

popd

echo "Finished! Don't forget to push the tags and releases repo artifacts."
echo "The new pod can be pushed to CocoaPods by doing: pod trunk push JitsiMeetSDK.podspec"
