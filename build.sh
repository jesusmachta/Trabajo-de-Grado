#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Navigate to the frontend directory and build the Flutter web application.
echo "Building Flutter web app..."
cd frontend
flutter build web --release # Using --release for production builds

# Navigate back to the root directory.
cd ..

# Install Python dependencies from the backend directory.
echo "Installing Python dependencies..."
# Ensure the path to requirements.txt is correct relative to the root.
pip install -r backend/requirements.txt

echo "Build script finished successfully." 