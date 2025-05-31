#!/bin/bash

echo "===== Cleaning Flutter build cache ====="
flutter clean

echo "===== Getting dependencies ====="
flutter pub get

echo "===== Building for web ====="
flutter build web --release

echo "===== Build completed ====="
echo "You can now deploy the contents of the build/web directory to your Render site." 