#include <Wire.h>
#include <MPU9250_asukiaaa.h>
//#include <Adafruit_BMP280.h>

// Incluindo as bibliotecas BLE nativas do ESP32 v3.1.3
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Definição dos pinos I2C para ESP32-C3
#define SDA_PIN 7
#define SCL_PIN 6

// Definição dos pinos I2C para ESP32
//#define SDA_PIN 21
//#define SCL_PIN 22


// Definições dos modos de operação
#define MODE_IMPACT_ONLY 0     // Modo 1: Apenas Impactos
#define MODE_CONTINUOUS 1      // Modo 2: Monitorização Contínua
#define MODE_NEUTRAL 2         // Modo 3: Modo Neutro

// Limites de aceleração (em g)
#define IMPACT_THRESHOLD 10.0  // Limiar de impacto (10g)
#define MOVEMENT_THRESHOLD 2.0 // Limiar de movimento (2.0g)

// Configurações do buffer de impacto
#define BUFFER_SIZE 50        // ~1 segundo a 50Hz
#define PRE_IMPACT_RATIO 0.7  // 70% dos dados serão de antes do impacto
#define POST_IMPACT_RATIO 0.3 // 30% dos dados serão de após o impacto
#define POST_IMPACT_SAMPLES (BUFFER_SIZE * POST_IMPACT_RATIO)

// Pino do botão para alternar modos (backup manual)
#define MODE_BUTTON_PIN 8
// Pinos LED para indicar modo atual
#define LED_MODE_IMPACT 3
#define LED_MODE_CONTINUOUS 4

// Pino do botão e LEDs(ESP32)
//#define MODE_BUTTON_PIN 15
//#define LED_MODE_IMPACT 2
//#define LED_MODE_CONTINUOUS 4

struct SensorData {
  float ax, ay, az, accelTotal;
  float gx, gy, gz, gyroTotal;
  float temperature, pressure, altitude;
  unsigned long timestamp;
};
SensorData circularBuffer[BUFFER_SIZE];
int bufferIndex = 0;

// Variáveis para controle de modo e estado
int currentMode = MODE_NEUTRAL;   // Inicia no modo de apenas impactos
bool impactDetected = false;
bool inMovement = false;
unsigned long buttonPressStartTime = 0;  // Para detectar pressionamento longo
bool buttonPressed = false;              // Estado do botão
const int longPressTime = 3000;          // Tempo para considerar pressionamento longo (3 segundos)
unsigned long lastStopCommandTime = 0;   // Controle para comando de parada rápida
bool emergencyStopActive = false;        // Flag para parada emergencial
bool collectingPostImpact = false;       // Flag para coleta pós-impacto
int postImpactSamplesCollected = 0;      // Contador de amostras pós-impacto

// Sensor objects
MPU9250_asukiaaa mpu;
//Adafruit_BMP280 bmp;

// BLE service & characteristic UUIDs (must match Flutter)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CONTROL_CHAR_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26a9" // Para controle do modo

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
BLECharacteristic* pControlCharacteristic = NULL; // Para receber comandos
bool deviceConnected = false;
bool oldDeviceConnected = false;
//bool bmpAvailable = false;

// Função para atualizar os LEDs conforme o modo atual
void updateModeLEDs() {
  if (currentMode == MODE_IMPACT_ONLY) {
    digitalWrite(LED_MODE_IMPACT, HIGH);
    digitalWrite(LED_MODE_CONTINUOUS, LOW);
    Serial.println("Modo IMPACT ONLY ativado");
  } else if (currentMode == MODE_CONTINUOUS) {
    digitalWrite(LED_MODE_IMPACT, LOW);
    digitalWrite(LED_MODE_CONTINUOUS, HIGH);
    Serial.println("Modo CONTINUOUS ativado");
  } else if (currentMode == MODE_NEUTRAL) {
    // No modo neutro, piscar os LEDs alternadamente
    digitalWrite(LED_MODE_IMPACT, millis() % 1000 < 500);
    digitalWrite(LED_MODE_CONTINUOUS, millis() % 1000 >= 500);
    
    if (millis() % 3000 < 10) {  // Log apenas ocasionalmente para não sobrecarregar
      Serial.println("Modo NEUTRAL ativado");
    }
  }
}

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

// Classe para callback de controle via BLE
// Modifique a classe ControlCallbacks no ESP32 para forçar a mudança de modo

class ControlCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      // Obter os dados brutos
      uint8_t* data = pCharacteristic->getData();
      size_t length = pCharacteristic->getLength();
      
      if (length > 0) {
        char receivedChar = (char)data[0];
        Serial.print("COMANDO RECEBIDO: ");
        Serial.println(receivedChar);
        
        // Forçar uma interrupção completa do envio de dados 
        // para qualquer comando de mudança de modo
        inMovement = false;
        impactDetected = false;
        collectingPostImpact = false;
        postImpactSamplesCollected = 0;

        // Processar o comando recebido
        if (receivedChar == '0') {
          // Ativar modo de impacto - força reset do estado
          currentMode = MODE_IMPACT_ONLY;
          Serial.println("*** MUDANDO PARA MODO IMPACT ***");
        } 
        else if (receivedChar == '1') {
          // Ativar modo contínuo - força reset do estado
          currentMode = MODE_CONTINUOUS;
          Serial.println("*** MUDANDO PARA MODO CONTINUOUS ***");
        } 
        else if (receivedChar == '2' || receivedChar == '9') {
          // Ativar modo neutro ou processando stop de emergência
          // Para ambos, forçamos ir para neutro para quebrar qualquer ciclo
          currentMode = MODE_NEUTRAL;
          Serial.println("*** MUDANDO PARA MODO NEUTRAL ***");
          
          if (receivedChar == '9') {
            Serial.println("*** STOP EMERGENCIAL ATIVADO ***");
          }
        }
        
        // Atualizar LEDs para o novo modo
        updateModeLEDs();
        
        // Enviar confirmação forte para o app
        if (deviceConnected) {
          String confirmation = "MODE_CHANGE:" + String(currentMode);
          pCharacteristic->setValue(confirmation.c_str());
          pCharacteristic->notify();
          
          // Enviar uma segunda confirmação com delay para garantir recepção
          delay(50);
          pCharacteristic->setValue(confirmation.c_str());
          pCharacteristic->notify();
        }
      }
    }
};

// Função para verificar botão de mudança de modo com pressionamento longo (3 segundos)
void checkModeButton() {
  int buttonState = digitalRead(MODE_BUTTON_PIN);
  
  // Verificar se o botão acabou de ser pressionado
  if (buttonState == LOW && !buttonPressed) {
    buttonPressed = true;
    buttonPressStartTime = millis();
  }
  
  // Verificar se o botão está sendo mantido pressionado por tempo suficiente
  if (buttonPressed && buttonState == LOW) {
    if (millis() - buttonPressStartTime >= longPressTime) {
      // Pressionamento longo detectado (3+ segundos)
      // Alternar entre os três modos ciclicamente
      if (currentMode == MODE_IMPACT_ONLY) {
        currentMode = MODE_CONTINUOUS;
      } else if (currentMode == MODE_CONTINUOUS) {
        currentMode = MODE_NEUTRAL;
      } else {  // MODE_NEUTRAL
        currentMode = MODE_IMPACT_ONLY;
      }
      
      // Atualizar LEDs indicadores e resetar estados
      updateModeLEDs();
      impactDetected = false;
      inMovement = false;
      collectingPostImpact = false;
      postImpactSamplesCollected = 0;
      
      // Prevent multiple triggers
      buttonPressStartTime = millis();
      
      Serial.println("Botão pressionado por 3+ segundos - Modo alterado para " + String(currentMode));
    }
  }
  
  // Verificar se o botão foi solto
  if (buttonState == HIGH && buttonPressed) {
    buttonPressed = false;
  }
}

// Função para adicionar dados ao buffer circular
void addToBuffer(float ax, float ay, float az, float accelTotal,
                 float gx, float gy, float gz, float gyroTotal) {
  circularBuffer[bufferIndex].ax = ax;
  circularBuffer[bufferIndex].ay = ay;
  circularBuffer[bufferIndex].az = az;
  circularBuffer[bufferIndex].accelTotal = accelTotal;
  circularBuffer[bufferIndex].gx = gx;
  circularBuffer[bufferIndex].gy = gy;
  circularBuffer[bufferIndex].gz = gz;
  circularBuffer[bufferIndex].gyroTotal = gyroTotal;
  circularBuffer[bufferIndex].timestamp = millis();
  
  // Avançar o índice de forma circular
  bufferIndex = (bufferIndex + 1) % BUFFER_SIZE;

  // Se estamos coletando amostras pós-impacto, verificar contador
  if (collectingPostImpact) {
    postImpactSamplesCollected++;
    
    // Quando atingirmos o número desejado de amostras pós-impacto,
    // processar o evento de impacto completo
    if (postImpactSamplesCollected >= POST_IMPACT_SAMPLES) {
      prepareImpactEvent();
      collectingPostImpact = false;
      postImpactSamplesCollected = 0;
    }
  }
}

// Variável global para armazenar dados de impacto completos
struct ImpactEvent {
  unsigned long impactTimestamp;
  int totalSamples;
  int preImpactSamples;
  SensorData samples[BUFFER_SIZE];
  bool ready;
};

ImpactEvent currentImpact;

// Função chamada quando o buffer pós-impacto está completo
void prepareImpactEvent() {
  Serial.println("IMPACTO DETECTADO! Preparando dados...");
  
  // Armazenar timestamp do impacto
  currentImpact.impactTimestamp = millis();
  currentImpact.totalSamples = BUFFER_SIZE;
  currentImpact.preImpactSamples = BUFFER_SIZE - postImpactSamplesCollected;
  
  // Copiar todos os dados do buffer circular para o evento
  for (int i = 0; i < BUFFER_SIZE; i++) {
    int idx = (bufferIndex + i) % BUFFER_SIZE;
    currentImpact.samples[i] = circularBuffer[idx];
  }
  
  currentImpact.ready = true;
  
  Serial.println("Dados de impacto prontos para envio!");
  Serial.println("Total de amostras: " + String(BUFFER_SIZE));
  Serial.println("Amostras pré-impacto: " + String(currentImpact.preImpactSamples));
  Serial.println("Amostras pós-impacto: " + String(postImpactSamplesCollected));
}

// Função para enviar evento de impacto via BLE
void sendImpactEvent() {
  if (!currentImpact.ready || !deviceConnected) {
    Serial.println("Evento de impacto não está pronto ou dispositivo desconectado");
    return;
  }
  
  Serial.println("Iniciando envio de evento de impacto via BLE...");
  
  // 1. Enviar cabeçalho do impacto
  String impactHeader = "IMPACT_START:" + 
                        String(currentImpact.impactTimestamp) + "," + 
                        String(currentImpact.totalSamples) + "," + 
                        String(currentImpact.preImpactSamples);
  
  pCharacteristic->setValue(impactHeader.c_str());
  pCharacteristic->notify();
  delay(30);
  Serial.println("→ " + impactHeader);
  
  // 2. Enviar todas as amostras sequencialmente
  for (int i = 0; i < currentImpact.totalSamples; i++) {
    // Determinar se é pré ou pós-impacto
    bool isPreImpact = (i < currentImpact.preImpactSamples);
    
    // Formatar dados da amostra
    String sampleData = "IMPACT_DATA:" + 
      String(currentImpact.impactTimestamp) + "," +
      String(i) + "," +
      String(isPreImpact ? 1 : 0) + "," +
      String(currentImpact.samples[i].timestamp) + "," +
      String(currentImpact.samples[i].ax, 4) + "," + 
      String(currentImpact.samples[i].ay, 4) + "," + 
      String(currentImpact.samples[i].az, 4) + "," + 
      String(currentImpact.samples[i].accelTotal, 4) + "," +
      String(currentImpact.samples[i].gx, 4) + "," + 
      String(currentImpact.samples[i].gy, 4) + "," + 
      String(currentImpact.samples[i].gz, 4) + "," + 
      String(currentImpact.samples[i].gyroTotal, 4);
    
    pCharacteristic->setValue(sampleData.c_str());
    pCharacteristic->notify();
    
    // Delay adaptativo baseado no progresso
    if (i % 10 == 0) {
      delay(25);  // Delay maior a cada 10 amostras
      Serial.println("→ Progresso: " + String(i + 1) + "/" + String(currentImpact.totalSamples));
    } else {
      delay(15);
    }
  }
  
  // 3. Enviar marcador de fim
  String impactEnd = "IMPACT_END:" + String(currentImpact.impactTimestamp);
  pCharacteristic->setValue(impactEnd.c_str());
  pCharacteristic->notify();
  delay(30);
  Serial.println("→ " + impactEnd);
  
  Serial.println("✓ Evento de impacto enviado com sucesso!");
  
  // Limpar o evento
  currentImpact.ready = false;
  impactDetected = false;
}

void setup() {
  Serial.begin(115200);
  
  // Iniciar a comunicação I2C com os pinos específicos do ESP32-C3
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.beginTransmission(0x68);

  // Configurar pinos de modo e LEDs
  pinMode(MODE_BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_MODE_IMPACT, OUTPUT);
  pinMode(LED_MODE_CONTINUOUS, OUTPUT);
  
  // Configurar LEDs iniciais
  updateModeLEDs();
  
  // Aguardar inicialização do monitor serial
  delay(1000);
  Serial.println("Iniciando sistema com ESP32-C3...");
  /*
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
    bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,     / Operating Mode /
                    Adafruit_BMP280::SAMPLING_X2,     / Temp. oversampling /
                    Adafruit_BMP280::SAMPLING_X16,    / Pressure oversampling /
                    Adafruit_BMP280::FILTER_X16,      / Filtering /
                    Adafruit_BMP280::STANDBY_MS_500); / Standby time /
  }
  */
  
  
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
  
  // Criando a BLE Characteristic para dados
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
                    
  // Criando um BLE Descriptor para notificações
  pCharacteristic->addDescriptor(new BLE2902());
  
  // Criando a BLE Characteristic para controle
  pControlCharacteristic = pService->createCharacteristic(
                            CONTROL_CHAR_UUID,
                            BLECharacteristic::PROPERTY_READ |
                            BLECharacteristic::PROPERTY_WRITE
                          );
  
  // Definindo callbacks para a característica de controle
  pControlCharacteristic->setCallbacks(new ControlCallbacks());
  
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
  Serial.println("Dual mode system initialized - Impact and Continuous modes available.");
  Serial.println("Modes can be changed via App or by pressing button for 3 seconds.");

  
}

// Ler valores do acelerômetro
float ax;
float ay;
float az;
float accelTotal;
float gx;
float gy;
float gz;
float gyroTotal;

void loop() {
  // Verificar botão de mudança de modo (backup manual)
  checkModeButton();
  
  // Atualizar os LEDs com base no modo atual
  updateModeLEDs();

  // Sempre realizar leitura dos sensores
  mpu.accelUpdate();
  mpu.gyroUpdate();
  
  // Ler valores do acelerômetro
  ax = mpu.accelX();
  ay = mpu.accelY();
  az = mpu.accelZ();
  accelTotal = sqrt(ax * ax + ay * ay + az * az);

  

  // Ler valores do giroscópio
  gx = mpu.gyroX();
  gy = mpu.gyroY();
  gz = mpu.gyroZ();
  gyroTotal = sqrt(gx * gx + gy * gy + gz * gz);
  
  /*
  // Read BMP280 (if available)
  float temperature = 0.0;
  float pressure = 0.0;
  float altitude = 0.0;
  if (bmpAvailable) {
    temperature = bmp.readTemperature();
    pressure = bmp.readPressure() / 100.0; // Convert Pa to hPa
    altitude = bmp.readAltitude(1013.25);
  }
  */
  // Verificar se é um impacto
  bool isImpact = (accelTotal >= IMPACT_THRESHOLD);
  bool isMoving = (accelTotal >= MOVEMENT_THRESHOLD);
  
  // Sempre adicionar ao buffer circular
  addToBuffer(ax, ay, az, accelTotal, gx, gy, gz, gyroTotal);
  
  // String de dados do sensor para envio
  String sensorData = "A:" + String(ax, 2) + "," + String(ay, 2) + "," + String(az, 2) + ", " +
                      "At:" + String(accelTotal, 2) + ", " +
                      "G:" + String(gx, 2) + "," + String(gy, 2) + "," + String(gz, 2) + ", " +
                      "Gt:" + String(gyroTotal, 2);
  
  // Verificar parada emergencial
  if (millis() - lastStopCommandTime < 500 && lastStopCommandTime > 0) {
    emergencyStopActive = true;
    Serial.println("Parada emergencial ativa...");
  } else {
    emergencyStopActive = false;
  }
  
  // Processar dados conforme o modo atual (se não estiver em parada emergencial)
  if (!emergencyStopActive) {
    switch (currentMode) {
      case MODE_IMPACT_ONLY:
        // MODO DE IMPACTO: monitorar impactos e enviar dados quando detectados
        
        // Se já detectamos um impacto e não estamos coletando dados pós-impacto,
        // ignorar o resto da lógica
        if (impactDetected && !collectingPostImpact) {
          Serial.println("[IMPACT MODE] Aguardando fim do processamento de impacto...");
          break;
        }
        
        // Se detectamos um novo impacto
        if (isImpact && !impactDetected && !collectingPostImpact) {
          Serial.println("[IMPACT MODE] **IMPACTO DETECTADO!** (At=" + String(accelTotal, 2) + ")");
          impactDetected = true;
          collectingPostImpact = true;
          postImpactSamplesCollected = 0;
          
          // Enviar notificação imediata de impacto detectado
          if (deviceConnected) {
            String impactAlert = "IMPACT_DETECTED:" + String(millis());
            pCharacteristic->setValue(impactAlert.c_str());
            pCharacteristic->notify();
          }
        }
        
        // Log para debug
        Serial.println("[IMPACT MODE] " + sensorData + 
                      (isImpact ? " - IMPACT!" : "") +
                      (collectingPostImpact ? " - Collecting post-impact..." : ""));
        break;
        
      case MODE_CONTINUOUS:
        // MODO CONTÍNUO: enviar dados quando estiver em movimento
        
        if (isMoving) {
          // Em movimento, enviar dados
          if (deviceConnected) {
            pCharacteristic->setValue(sensorData.c_str());
            pCharacteristic->notify();
          }
          
          // Detectar impactos mesmo no modo contínuo
          if (isImpact && !impactDetected) {
            impactDetected = true;
            
            // Enviar alerta de impacto
            if (deviceConnected) {
              String impactAlert = "IMPACT_ALERT:" + String(accelTotal, 2);
              pCharacteristic->setValue(impactAlert.c_str());
              pCharacteristic->notify();
            }
            
            // Resetar flag após um tempo
            delay(50);
            impactDetected = false;
          }
          
          inMovement = true;
          Serial.println("[CONTINUOUS MODE - ACTIVE] " + sensorData + 
                        (isImpact ? " - IMPACT!" : ""));
        }
        else if (inMovement) {
          // Transição de movimento para parado
          if (deviceConnected) {
            String idleMessage = "IDLE:Movimento abaixo do limiar";
            pCharacteristic->setValue(idleMessage.c_str());
            pCharacteristic->notify();
          }
          
          inMovement = false;
          Serial.println("[CONTINUOUS MODE - IDLE] " + sensorData);
        }
        else {
          // Permanece parado
          Serial.println("[CONTINUOUS MODE - IDLE] " + sensorData);
        }
        break;
        
      case MODE_NEUTRAL:
      default:
        // MODO NEUTRO: não enviar dados, apenas heartbeat
        
        // Enviar heartbeat a cada 3 segundos
        if (deviceConnected && (millis() % 3000) < 10) {
          String heartbeat = "NEUTRAL:Device in standby mode";
          pCharacteristic->setValue(heartbeat.c_str());
          pCharacteristic->notify();
          Serial.println("[NEUTRAL MODE] Sending heartbeat");
        }
        
        // Log periódico
        if (millis() % 1000 < 10) {
          Serial.println("[NEUTRAL MODE] " + sensorData);
        }
        break;
    }
  }
  
  // Gerenciar reconexões BLE
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Reiniciando advertising...");
    oldDeviceConnected = deviceConnected;
  }
  
  // Detectar novas conexões
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("Dispositivo conectado! Modo atual: " + String(currentMode));
    
    // Enviar status atual
    String statusMsg = "STATUS:Device in mode " + String(currentMode);
    pCharacteristic->setValue(statusMsg.c_str());
    pCharacteristic->notify();
  }

  // === NOVO: Enviar evento de impacto se estiver pronto ===
  if (currentImpact.ready && deviceConnected && currentMode == MODE_IMPACT_ONLY) {
    Serial.println("[IMPACT MODE] Enviando evento de impacto...");
    sendImpactEvent();
  }
  
  // Manter a mesma taxa de amostragem em todos os modos
  delay(20); // 50Hz
}