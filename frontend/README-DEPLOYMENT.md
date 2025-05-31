# Deployment Guide - StoreSense App

This guide explains how the app was modified to support both local development and production deployment on Render.

## Changes Made

### 1. Dynamic Base URL Configuration

Created a new `apiBaseUrl` getter in `config.dart` that automatically detects whether the app is running on:
- localhost (development)
- Render deployment (production)

The app now uses the appropriate URL based on the environment:
- Development: `http://localhost:8000`
- Production: `https://trabajo-de-grado.onrender.com`

### 2. Updated API URL References

Updated all hardcoded URL references in:
- `auth_controller.dart`
- `profile_view.dart`
- `company_view.dart`
- `users_view.dart`
- `register_company_view.dart`

### 3. Helper Method for API URLs

Added a helper method `getApiUrl()` to make it easy to construct fully qualified API URLs.

## How It Works

The app detects the environment by checking the host of the current URL:
- If running on localhost, it uses the local server URL
- If running on any other host, it uses the Render deployment URL

## Rebuilding the App

After these changes, you should rebuild the app with:

```bash
./rebuild.sh
```

This script will:
1. Clean the Flutter cache
2. Get dependencies
3. Build the web app in release mode

## Deploying to Render

After building, deploy the contents of the `build/web` directory to your Render site.

## Troubleshooting

If you encounter connection issues:
1. Make sure your backend is running and accessible
2. Check CORS settings on the backend if needed
3. Verify the correct URL is being used in the logs 