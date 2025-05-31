class AppConfig {
  // Determine the API base URL based on the current environment
  // This allows the app to work both in development and production
  static String get apiBaseUrl {
    // Check if we're running on web and in production
    final host = Uri.base.host;
    final isLocalhost = host == 'localhost' || host == '127.0.0.1';

    // If we're on the Render deployment or any non-localhost environment, use the Render URL
    if (!isLocalhost && host.isNotEmpty) {
      return 'https://trabajo-de-grado.onrender.com';
    }

    // For local development with an Android emulator, use 10.0.2.2
    // For local development with an iOS simulator or web, use localhost
    return 'http://localhost:8000';
  }

  // Helper method to get full API URL
  static String getApiUrl(String endpoint) {
    // Ensure endpoint doesn't start with a slash
    final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$apiBaseUrl/api/$path';
  }
}
