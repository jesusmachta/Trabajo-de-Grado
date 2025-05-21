/**
 * ESP32-CAM Heat Map Generator for Categories
 *
 * This code detects Bluetooth devices nearby to estimate foot traffic
 * and sends the data to the backend server to create a heat map for a specific category.
 * It uses RSSI signal strength to determine proximity to the category.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

// WiFi credentials
const char *ssid = "REFUGIO";
const char *password = "mirefugio2203#";

// Your backend API endpoint
const char *serverName = "https://trabajo-de-grado.onrender.com/api/heatmap/data";

// Category configuration - CHANGE THESE VALUES FOR EACH ESP32-CAM DEVICE!
// Use the Tipo_Producto ID from your database
const int TIPO_PRODUCTO = 1; // Set this to match your category ID
String empresa = "CataSus";  // Company identifier

// RSSI threshold values for proximity determination
const int RSSI_CLOSE = -60;  // Strong signal (very close) - Main category
const int RSSI_MEDIUM = -75; // Medium signal (medium distance) - Medium category
const int RSSI_FAR = -90;    // Weak signal (far distance) - Far category

// Bluetooth scanning parameters
int scanTime = 5; // Seconds to scan for BLE devices
BLEScan *pBLEScan;
int closeCount = 0;  // Count of devices in close proximity (main category)
int mediumCount = 0; // Count of devices at medium distance
int farCount = 0;    // Count of devices at far distance
unsigned long lastScanTime = 0;
const unsigned long scanInterval = 60000; // Scan every minute

class MyAdvertisedDeviceCallbacks : public BLEAdvertisedDeviceCallbacks
{
    void onResult(BLEAdvertisedDevice advertisedDevice)
    {
        // Get RSSI for the discovered device
        int rssi = advertisedDevice.getRSSI();

        // Categorize by RSSI strength
        if (rssi >= RSSI_CLOSE)
        {
            // Strong signal - device is very close to this category
            closeCount++;
        }
        else if (rssi >= RSSI_MEDIUM)
        {
            // Medium signal - device is at medium distance
            mediumCount++;
        }
        else if (rssi >= RSSI_FAR)
        {
            // Weak signal - device is far away
            farCount++;
        }

        Serial.printf("Advertised Device: %s - RSSI: %d\n", advertisedDevice.toString().c_str(), rssi);
    }
};

void setup()
{
    Serial.begin(115200);

    // Connect to WiFi
    WiFi.begin(ssid, password);
    Serial.println("Connecting to WiFi...");

    while (WiFi.status() != WL_CONNECTED)
    {
        delay(1000);
        Serial.print(".");
    }

    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());

    // Initialize Bluetooth
    Serial.println("Initializing Bluetooth scanner...");
    BLEDevice::init("");
    pBLEScan = BLEDevice::getScan();
    pBLEScan->setAdvertisedDeviceCallbacks(new MyAdvertisedDeviceCallbacks());
    pBLEScan->setActiveScan(true); // Active scan uses more power, but gets results faster
    pBLEScan->setInterval(100);
    pBLEScan->setWindow(99); // Less than interval value

    Serial.print("ESP32-CAM configured for Category ID: ");
    Serial.println(TIPO_PRODUCTO);
    Serial.println("Setup completed");
}

void loop()
{
    unsigned long currentTime = millis();

    // Check if it's time to perform a scan
    if (currentTime - lastScanTime >= scanInterval)
    {
        // Reset device counts before scanning
        closeCount = 0;
        mediumCount = 0;
        farCount = 0;

        // Start BLE scan
        Serial.println("Starting BLE scan...");
        pBLEScan->start(scanTime, false);

        Serial.print("Close proximity devices (main category): ");
        Serial.println(closeCount);
        Serial.print("Medium distance devices: ");
        Serial.println(mediumCount);
        Serial.print("Far distance devices: ");
        Serial.println(farCount);

        // Send data to server
        if (WiFi.status() == WL_CONNECTED)
        {
            sendHeatMapData(closeCount, mediumCount, farCount);
        }
        else
        {
            Serial.println("WiFi Disconnected. Trying to reconnect...");
            WiFi.begin(ssid, password);
        }

        // Update last scan time
        lastScanTime = currentTime;

        // Clear results
        pBLEScan->clearResults();
    }

    delay(1000); // Small delay in the main loop
}

void sendHeatMapData(int count, int medium, int far)
{
    HTTPClient http;

    // Your domain name with URL path or IP address with path
    http.begin(serverName);

    // Specify content-type header
    http.addHeader("Content-Type", "application/json");

    // Format locationId as a string matching the category ID
    String locationId = String(TIPO_PRODUCTO);

    // Prepare JSON data
    String httpRequestData = "{\"location_id\":\"" + locationId +
                             "\",\"count\":" + String(count) +
                             ",\"medium\":" + String(medium) +
                             ",\"far\":" + String(far) +
                             ",\"empresa\":\"" + empresa + "\"}";

    Serial.print("Sending data: ");
    Serial.println(httpRequestData);

    // Send HTTP POST request
    int httpResponseCode = http.POST(httpRequestData);

    if (httpResponseCode > 0)
    {
        Serial.print("HTTP Response code: ");
        Serial.println(httpResponseCode);
        String payload = http.getString();
        Serial.println(payload);
    }
    else
    {
        Serial.print("Error code: ");
        Serial.println(httpResponseCode);
    }

    // Free resources
    http.end();
}