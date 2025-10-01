#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <Adafruit_BMP280.h>  // Instala a biblioteca Adafruit BMP280

// Objetos dos sensores
MPU9250_asukiaaa myIMU;
Adafruit_BMP280 bmp; 

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("Iniciando teste de comunicação com GY-91...");

  // Inicia I2C nos pinos default do ESP32-C3
  // Se necessário, ajusta SDA e SCL conforme teu módulo
  Wire.begin(0x76);
  //Wire.setClock(100000);

  // --- Scan I2C ---
  Serial.println("Scanning I2C bus...");
  byte error, address;
  int nDevices = 0;
  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    if (error == 0) {
      Serial.print("Dispositivo I2C encontrado no endereço 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);
      Serial.println(" !");
      nDevices++;
    }
  }
  
  if (nDevices == 0) {
    Serial.println("Nenhum dispositivo I2C encontrado.");
  } else {
    Serial.println("Scan concluído.");
  }


  // --- Testa MPU9250 ---
  myIMU.setWire(&Wire);
  myIMU.beginAccel();
  myIMU.beginGyro();
  myIMU.beginMag();

  

  Serial.println("Testando MPU9250...");
  myIMU.accelUpdate();
  Serial.print("Accel X: ");
  Serial.println(myIMU.accelX());

  

  // --- Testa BMP280 ---
  Serial.println("Testando BMP280...");
  if (!bmp.begin(0x76)) {  // alguns módulos usam 0x77
    Serial.println("BMP280 não encontrado no endereço 0x76. Tenta 0x77...");
    if (!bmp.begin(0x77)) {
      Serial.println("BMP280 não encontrado!");
    } else {
      Serial.println("BMP280 encontrado em 0x77!");
    }
  } else {
    Serial.println("BMP280 encontrado em 0x76!");
  }

  
}

void loop() {
  // Atualiza leituras do IMU
  myIMU.accelUpdate();
  myIMU.gyroUpdate();
  myIMU.magUpdate();

  Serial.print("Accel [g]: ");
  Serial.print(myIMU.accelX()); Serial.print("\t");
  Serial.print(myIMU.accelY()); Serial.print("\t");
  Serial.println(myIMU.accelZ());

  Serial.print("Gyro [deg/s]: ");
  Serial.print(myIMU.gyroX()); Serial.print("\t");
  Serial.print(myIMU.gyroY()); Serial.print("\t");
  Serial.println(myIMU.gyroZ());

  Serial.print("Mag [µT]: ");
  Serial.print(myIMU.magX()); Serial.print("\t");
  Serial.print(myIMU.magY()); Serial.print("\t");
  Serial.println(myIMU.magZ());

  Serial.print("Temp IMU [°C]: ");
 // Serial.println(myIMU.temperature());

  // BMP280
  if (bmp.begin(0x76) || bmp.begin(0x77)) {
    Serial.print("Temp BMP280 [°C]: ");
    Serial.print(bmp.readTemperature());
    Serial.print("\tPressão [hPa]: ");
    Serial.println(bmp.readPressure() / 100.0);
  }

  Serial.println("-------------------------");
  delay(1000);
}
