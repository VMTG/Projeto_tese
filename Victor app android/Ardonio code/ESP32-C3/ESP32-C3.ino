#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <Adafruit_BMP280.h>

// Incluindo as bibliotecas BLE nativas do ESP32 v3.1.3
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Definição dos pinos I2C para ESP32-C3
#define SDA_PIN 7
#define SCL_PIN 6

// Sensor objects
MPU9250_asukiaaa mpu;
Adafruit_BMP280 bmp;

// BLE service & characteristic UUIDs (must match Flutter)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool bmpAvailable = false;

// Create custom server callbacks to handle connect/disconnect events
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected!");
    }
};

void setup() {
  Serial.begin(115200);
  
  // Iniciar a comunicação I2C com os pinos específicos do ESP32-C3
  Wire.begin(SDA_PIN, SCL_PIN);
  
  // Aguardar inicialização do monitor serial
  delay(1000);
  Serial.println("Iniciando sistema com ESP32-C3...");

  // Initialize BMP280 – try 0x76 (or 0x77 if needed)
  if (!bmp.begin(0x76)) {
    Serial.println("BMP280 sensor not found at 0x76!");
    // Tente o endereço alternativo
    if (!bmp.begin(0x77)) {
      Serial.println("BMP280 not found at 0x77 either!");
      bmpAvailable = false;
    } else {
      Serial.println("BMP280 initialized at address 0x77.");
      bmpAvailable = true;
    }
  } else {
    Serial.println("BMP280 initialized at address 0x76.");
    bmpAvailable = true;
  }

  // Configurações do BMP280 - ajustadas para ESP32-C3
  if (bmpAvailable) {
    bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,     /* Operating Mode */
                    Adafruit_BMP280::SAMPLING_X2,     /* Temp. oversampling */
                    Adafruit_BMP280::SAMPLING_X16,    /* Pressure oversampling */
                    Adafruit_BMP280::FILTER_X16,      /* Filtering */
                    Adafruit_BMP280::STANDBY_MS_500); /* Standby time */
  }

  // Initialize MPU9250 sensors
  mpu.setWire(&Wire);
  mpu.beginAccel();
  mpu.beginGyro();
  mpu.beginMag();

  // Configurando o BLE
  BLEDevice::init("ESP32_GY91");
  
  // Criando o BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  // Criando o BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Criando a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
                    
  // Criando um BLE Descriptor para notificações
  pCharacteristic->addDescriptor(new BLE2902());
  
  // Iniciando o serviço
  pService->start();
  
  // Iniciando a publicidade do BLE
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  // Ajustes para melhorar a compatibilidade com iOS
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE advertising started. ESP32-C3 ready!");
}

void loop() {
  // Update MPU9250 readings
  mpu.accelUpdate();
  mpu.gyroUpdate();
  mpu.magUpdate();

  // Read accelerometer
  float ax = mpu.accelX();
  float ay = mpu.accelY();
  float az = mpu.accelZ();
  float accelTotal = sqrt(ax * ax + ay * ay + az * az);

  // Read gyroscope
  float gx = mpu.gyroX();
  float gy = mpu.gyroY();
  float gz = mpu.gyroZ();
  float gyroTotal = sqrt(gx * gx + gy * gy + gz * gz);

  // Read BMP280 (if available)
  float temperature = 0.0;
  float pressure = 0.0;
  float altitude = 0.0;
  if (bmpAvailable) {
    temperature = bmp.readTemperature();
    pressure = bmp.readPressure() / 100.0; // Convert Pa to hPa
    altitude = bmp.readAltitude(1013.25); // Altitude calculada com base na pressão do nível do mar padrão
  }

  // Build complete sensor data string with newline delimiter.
  String sensorData = "T:" + String(temperature, 2) + ", " +
                      "P:" + String(pressure, 2) + ", " +
                      "A:" + String(ax, 2) + "," + String(ay, 2) + "," + String(az, 2) + ", " +
                      "At:" + String(accelTotal, 2) + ", " +
                      "G:" + String(gx, 2) + "," + String(gy, 2) + "," + String(gz, 2) + ", " +
                      "Gt:" + String(gyroTotal, 2);

  // Verificar se dispositivo está conectado antes de notificar
  if (deviceConnected) {
    // Atualizar e notificar os clientes BLE
    pCharacteristic->setValue(sensorData.c_str());
    pCharacteristic->notify();
  }
  
  // Debug output
  Serial.println(sensorData);

  // Gerenciar reconexões
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Dar tempo ao Bluetooth para ficar pronto
    pServer->startAdvertising(); // Reiniciar advertising
    Serial.println("Restarting advertising...");
    oldDeviceConnected = deviceConnected;
  }
  
  // Conectando
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  // Implementar verificação básica de erros
  if (isnan(accelTotal) || isnan(gyroTotal)) {
    Serial.println("Erro na leitura do MPU9250. Tentando reiniciar...");
    mpu.beginAccel();
    mpu.beginGyro();
    mpu.beginMag();
    delay(100);
  }

  delay(500);
}