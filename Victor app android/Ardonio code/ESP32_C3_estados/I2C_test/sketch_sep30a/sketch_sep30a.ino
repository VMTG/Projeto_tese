// Ultra-basic I2C test for ESP32-C3
// This will help identify if the I2C bus is working at all

#include <Wire.h>

// Try each of these pin combinations one at a time
// Uncomment ONLY ONE set at a time

// Configuration 1 - Your current pins
//#define SDA_PIN 7
//#define SCL_PIN 6

// Configuration 2 - Try if above fails
//#define SDA_PIN 6
//#define SCL_PIN 7

// Configuration 3 - Alternative ESP32-C3 I2C pins
#define SDA_PIN 6
#define SCL_PIN 7

// Configuration 4 - Another common combination
// #define SDA_PIN 8
// #define SCL_PIN 9

// Configuration 5 - Yet another option
// #define SDA_PIN 0
// #define SCL_PIN 1

void setup() {
  Serial.begin(115200);
  delay(3000); // Wait for serial monitor
  
  Serial.println("\n\n========================================");
  Serial.println("ESP32-C3 BASIC I2C CONNECTION TEST");
  Serial.println("========================================\n");
  
  Serial.println("Pin Configuration:");
  Serial.println("  SDA: GPIO " + String(SDA_PIN));
  Serial.println("  SCL: GPIO " + String(SCL_PIN));
  Serial.println();
  
  // Test 1: Can we initialize I2C?
  Serial.println("TEST 1: Initializing I2C bus...");
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(10000); // Start VERY slow - 10kHz
  delay(200);
  Serial.println("  ✓ I2C initialized");
  Serial.println();
  
  // Test 2: Silent scan (minimal probing)
  Serial.println("TEST 2: Silent scan of critical addresses only...");
  Serial.println("  (This minimizes error messages)");
  Serial.println();
  
  byte criticalAddresses[] = {0x68, 0x69, 0x76, 0x77};
  bool foundAny = false;
  
  for(int i = 0; i < 4; i++) {
    byte addr = criticalAddresses[i];
    
    Wire.beginTransmission(addr);
    delay(10);
    byte error = Wire.endTransmission();
    
    Serial.print("  Address 0x");
    if(addr < 16) Serial.print("0");
    Serial.print(addr, HEX);
    Serial.print(": ");
    
    if(error == 0) {
      Serial.println("✓ DEVICE FOUND!");
      foundAny = true;
    } else {
      Serial.println("No response");
    }
    
    delay(50);
  }
  
  Serial.println();
  
  if(!foundAny) {
    Serial.println("========================================");
    Serial.println("⚠ NO DEVICES DETECTED");
    Serial.println("========================================\n");
    
    Serial.println("TROUBLESHOOTING STEPS:\n");
    
    Serial.println("1. VERIFY PHYSICAL CONNECTIONS:");
    Serial.println("   - Use a multimeter to check continuity");
    Serial.println("   - ESP32-C3 Pin " + String(SDA_PIN) + " → GY-91 SDA");
    Serial.println("   - ESP32-C3 Pin " + String(SCL_PIN) + " → GY-91 SCL");
    Serial.println("   - ESP32-C3 3.3V → GY-91 VCC");
    Serial.println("   - ESP32-C3 GND → GY-91 GND");
    Serial.println();
    
    Serial.println("2. CHECK POWER:");
    Serial.println("   - Measure voltage at GY-91 VCC pin");
    Serial.println("   - Should read 3.3V (±0.1V)");
    Serial.println("   - If reading 0V, check power connection");
    Serial.println();
    
    Serial.println("3. CHECK PULL-UP RESISTORS:");
    Serial.println("   - Measure voltage on SDA and SCL lines");
    Serial.println("   - Should read close to 3.3V when idle");
    Serial.println("   - If reading 0V or floating, pull-ups missing");
    Serial.println();
    
    Serial.println("4. TRY DIFFERENT PINS:");
    Serial.println("   - Edit the code and try different pin combinations");
    Serial.println("   - Some ESP32-C3 boards use different I2C pins");
    Serial.println("   - Try swapping SDA and SCL definitions");
    Serial.println();
    
    Serial.println("5. CHECK YOUR GY-91 MODULE:");
    Serial.println("   - Does it have a voltage regulator?");
    Serial.println("   - Some modules need 5V instead of 3.3V");
    Serial.println("   - Look for small components near VCC pin");
    Serial.println();
    
    Serial.println("6. TEST WITH ANOTHER DEVICE:");
    Serial.println("   - Try a different I2C device to verify pins work");
    Serial.println("   - Or test GY-91 with Arduino/different board");
    Serial.println();
    
    Serial.println("========================================");
    Serial.println("PHOTOS NEEDED FOR FURTHER DIAGNOSIS:");
    Serial.println("========================================");
    Serial.println("Please take clear photos of:");
    Serial.println("  1. Your complete wiring setup");
    Serial.println("  2. ESP32-C3 board (close-up of pins)");
    Serial.println("  3. GY-91 module (both sides)");
    Serial.println("  4. All connection points");
    
  } else {
    Serial.println("========================================");
    Serial.println("✓ SUCCESS - I2C DEVICE(S) FOUND!");
    Serial.println("========================================\n");
    Serial.println("Your I2C bus is working correctly.");
    Serial.println("You can now use your main program.");
  }
}

void loop() {
  delay(5000);
  
  Serial.println("\n--- Quick recheck ---");
  
  // Quick recheck of main addresses
  byte addr = 0x68;
  Wire.beginTransmission(addr);
  if(Wire.endTransmission() == 0) {
    Serial.println("MPU9250 still connected at 0x68");
  }
  
  addr = 0x76;
  Wire.beginTransmission(addr);
  if(Wire.endTransmission() == 0) {
    Serial.println("BMP280 still connected at 0x76");
  }
}