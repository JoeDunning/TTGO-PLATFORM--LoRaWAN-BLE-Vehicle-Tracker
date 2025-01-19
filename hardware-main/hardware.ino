/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Library imports
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\



// Libraries for MQTT, BLE and required utility
#include <lmic.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEAdvertisedDevice.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ESP Libraries
#include <esp32/ulp.h>
#include <esp_deep_sleep.h>
#include <driver/i2c.h>
#include <driver/rtc_io.h>

// LMIC, LPP & GPS (TinyGPS++)
#include <TinyGPS++.h>
#include <CayenneLPP.h>

// Utility Libraries
#include <HardwareSerial.h>
#include <Wire.h>
#include <SPI.h>
#include <hal/hal.h>
#include <Adafruit_ADXL343.h>

// Config files
#include "deviceconfig.h"
#include "seckeys.h"



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Instances and Address Configurations
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\



// Utility definitions //I2C_AXP192 axp192(I2C_AXP192_DEFAULT_ADDRESS, Wire1);
HardwareSerial GPSSerial(1);
TinyGPSPlus tGps;
CayenneLPP lpp(51);
Adafruit_ADXL343 Accel = Adafruit_ADXL343(23);

void os_getDevEui(u1_t* buf) {}
void os_getArtEui(u1_t* buf) {}
void os_getDevKey(u1_t* buf) {}

// BLE Server Defs 
BLEServer* pServer;
BLECharacteristic* callbackCharacteristic = NULL;
BLECharacteristic* gpsCharacteristic = NULL;
BLECharacteristic* pCharacteristic;

// UUID4 BLE Service IDs
BLEUUID serviceID("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");            // Device Service ID
BLEUUID appDataID("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");            // Device App ID
BLEUUID appMovementID("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");        // Device Movement Bool ID
BLEUUID devGPSID("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");             // Device GPS Data ID

// LoRa LMIC Pin Mapping
const lmic_pinmap lmic_pins = {
  .nss = 18,
  .rxtx = LMIC_UNUSED_PIN,
  .rst = 23,
  .dio = { 26, 33, 32 },
};

// BLE Data Storage 
float callbackValue = 0;                    // Float var for handling storage of BLE callback value
char s[32];                                 // Storage array for BLE characteristics
uint8_t armvalue_store[1];                  // Int store for arm value callback data - used with BLE characteristics
uint8_t mv_store[1];                        // Int store for movement detection callback value - used with BLE characteristics

// SOS Handling Vars
unsigned long button_time;                  // Long var for storing time button has been held with millis() output
bool button_held;                           // Bool for IO38 button status
int sos_input;                              // Digital input capture variable for IO38 (stored as Int)
bool sos_triggered = false;                 // Bool for storing SOS status

// Device Status Variables | Initial ADXL343 X, Y & Z Position | Initial ADXL343 X, Y & Z Offset | Last confirmed position
double initialX, initialY, initialZ;
double offsetXMin, offsetXMax, offsetYMin, offsetYMax, offsetZMin, offsetZMax;
double lastConfirmedLat, lastConfirmedLng;  

// Device Status Check & Timing Variables
bool armed_status = false;                  // Bool - Is deviced armed via app over BLE
bool safety_status = true;                  // Bool - Is device safe to transmit
bool ble_connected = false;                 // Bool - Is app detected via bluetooth
bool device_triggered = false;              // Bool - If device has left range set by Geofencing then true

bool moving_status;                         // Bool - If device is currently moving or not, true if moving.
bool initial_run = true;                    // Bool - Has initial run of system following a restart or initial setup been completed, true on initial run, false otherwise

double movement_time;                       // Double - Amount of time the device has been moving in millis
int_config accel_int_enabled = { 0 };       // Int - ADXL movement detection, 0 if false, 1 if true

// Packet & BLE Address Definitions
static osjob_t singlepacket;
void send_data(osjob_t* d);



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\



///////// -- BLE Functions

// Method for initialising BLE
void bleStart() {
  pServer->getAdvertising()->start();  // Start advertising
}

// Callback for general server & BLE state handling
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    ble_connected = true;
  };

  void onDisconnect(BLEServer* pServer) {
    ble_connected = false;

    if (safety_status) {
      pServer->getAdvertising()->start();
    } else {
      safety_status = false;
    }
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  //this method will be call to perform writes to characteristic
  void onWrite(BLECharacteristic* pCharacteristic) {

    // Check for if arm value UUID == found UUID
    if (appDataID.equals(pCharacteristic->getUUID())) {  
      uint8_t* value = pCharacteristic->getData();
      String decodedData = "";
      for (int i = 0; i < pCharacteristic->getValue().length(); i++) {
        decodedData += (char)pCharacteristic->getValue()[i];
      }
    }
  }
};

///////// -- GPS Functions

// Function used for checking and encoding the last confirmed lat and lng positions for use in situations where GPS signal may of been lost, aka SOS mode
void checkValidGPS() {
  if (tGps.location.isValid() && tGps.location.age() < 4000) {
    lastConfirmedLat = tGps.location.lat();
    lastConfirmedLng = tGps.location.lng();
  }
}

// Function for encoding our TinyGPS++ object with actual GPS data from our on-board chip. Also stores last known GPS in-case of lost 
void encodeGPS() {
  int previousMillis = millis();
  while ((previousMillis + 1000) > millis()) {
    while (GPSSerial.available()) {
      char data = GPSSerial.read();
      tGps.encode(data);
    }
  }
  checkValidGPS();
}

// Function for sending GPS info via BLE, used for active position with geo-fencing
void sendGPS() {
  if (ble_connected) {
    encodeGPS();              // Method for encoding GPSSerial data onto TinyGPS++ Object
    char callbackString[24];  // Char store for sending values
    Serial.println(tGps.location.age());
    if (tGps.location.age() < 5000) {
      
      // BLE Lat Handling
      snprintf(callbackString, sizeof(callbackString), "lat:%.15f", tGps.location.lat(), 15);
      callbackCharacteristic->setValue((uint8_t*)callbackString, strlen(callbackString));
      callbackCharacteristic->notify();
      Serial.println("BLE LAT Notified...");
      Serial.print(tGps.location.lat(), 15);

      // BLE Lng Handling
      snprintf(callbackString, sizeof(callbackString), "lng:%.15f", tGps.location.lng(), 15);
      callbackCharacteristic->setValue((uint8_t*)callbackString, strlen(callbackString));
      callbackCharacteristic->notify();
      Serial.println("BLE LNG Notified...");
      Serial.print(tGps.location.lng(), 15);

      // BLE Alt Handling
      snprintf(callbackString, sizeof(callbackString), "alt:%.1f", tGps.altitude.meters(), 1);
      callbackCharacteristic->setValue((uint8_t*)callbackString, strlen(callbackString));
      callbackCharacteristic->notify();
      Serial.println("BLE ALT Notified...");
      Serial.println(tGps.altitude.meters(), 1);
    } else {
      
      // Callback for unavailable GPS
      snprintf(callbackString, sizeof(callbackString), "gpn");
      callbackCharacteristic->setValue((uint8_t*)callbackString, strlen(callbackString));
      callbackCharacteristic->notify();
      Serial.println("GPS Awaiting Fix... BLE Notified...");
    }
  }
}

// Function for notifying app of movement safety check
void sendMV() {
  if (ble_connected) { 
    char callbackString[4];  // Char store for sending values          

    snprintf(callbackString, sizeof(callbackString), "mvd");
    gpsCharacteristic->setValue((uint8_t*)callbackString, strlen(callbackString));
    gpsCharacteristic->notify();
    Serial.println("BLE MV Notified...");
  }
}

///////// -- LMIC Functions

// LMIC Event Handling - Function for handling different required LMIC states
void onEvent(ev_t ev) {
  switch (ev) {
    case EV_JOINED:
      Serial.println(F("EV_JOINED"));
      // Disable link check validation (automatically enabled during join, but not supported by TTN at this time).
      LMIC_setLinkCheckMode(0);
      break;
    case EV_TXSTART:
      Serial.println(F("EV_TXSTART"));             
      break;
    case EV_TXCOMPLETE:
      Serial.println(F("EV_TXCOMPLETE (includes wait for RX window)"));
      Serial.println(F("Packet Queued..."));
      Serial.print(F("Packet Size: "));
      Serial.println(lpp.getSize());
      digitalWrite(BUILTIN_LED, LOW);
      if (LMIC.txrxFlags & TXRX_ACK) {
        Serial.println(F("Received ACK!"));
      }
      if (LMIC.dataLen != 0) {
        sprintf(s, "Received %i bytes in RX", LMIC.dataLen);
        Serial.println(s);
        sprintf(s, "RSSI: %d SNR: %.1d", LMIC.rssi, LMIC.snr);
        Serial.println(s);
        for (int i = 0; i < LMIC.dataLen; i++) {  // Datalen can be used as a iterator for the buffer
          if (LMIC.frame[LMIC.dataBeg + i] < 0x10) {
            Serial.print(F("0"));
            Serial.print(LMIC.frame[LMIC.dataBeg + i], HEX);  // Print out the byte
          }
        }
      }

      Serial.println("Next Packet in 1 seconds!");
      os_setTimedCallback(&singlepacket, os_getTime() + sec2osticks(1), send_data);
      break;

    case EV_RXSTART:
      Serial.println(F("EV_RESET"));
      break;

    case EV_RXCOMPLETE:
      Serial.println(F("EV_RXCOMPLETE"));
      Serial.println("RX Data Received!");
      break;

    default:
      Serial.println(F("Unknown event"));
      break;
  }
} 

// Function for handling the transmit of LPP packets via LoRa using LMIC
void send_data(osjob_t* d) {
  if (LMIC.opmode & OP_TXRXPEND) {
    Serial.println("Job Ongoing, Re-parsing...");
  } else {
    encodeGPS();
  if (armed_status && safety_status && device_triggered && tGps.location.age() < 5000) {
      digitalWrite(BUILTIN_LED, HIGH);
      lpp.reset();
      lpp.addGPS(1, lastConfirmedLat, lastConfirmedLng, tGps.altitude.meters());
    
      LMIC_setTxData2(1, lpp.getBuffer(), lpp.getSize(), 0);
    } 
    
    else if (sos_triggered) {
      Serial.println("SOS Override: Sending location & help request to API..");
      digitalWrite(BUILTIN_LED, HIGH);
      lpp.reset();
      lpp.addGPS(1, lastConfirmedLat, lastConfirmedLng, tGps.altitude.meters());

      LMIC_setTxData2(2, lpp.getBuffer(), lpp.getSize(), 0);
    } 
    
    else if (ble_connected && !device_triggered) {
      os_setTimedCallback(&singlepacket, os_getTime() + sec2osticks(1), send_data);
      Serial.println("Device Safe: Handling BLE Callbacks & Checking Against Radius..");
      Serial.print("Current GPS Fix Age: ");
      Serial.println(tGps.location.age());
      sendGPS();
    } 
    
    else if (ble_connected) {
      Serial.println("BLE Debug: Re-parsing in 1 second...");
      os_setTimedCallback(&singlepacket, os_getTime() + sec2osticks(1), send_data);
      // FOR DEBUG ONLY
      sendGPS();
      //movementDetected();
    }

    else {
      Serial.println("Status Undefined: Awaiting Connection, Re-parsing in 1 second...");
      Serial.print("GPS Age: ");
      Serial.print(tGps.location.age());
      os_setTimedCallback(&singlepacket, os_getTime() + sec2osticks(1), send_data);
    }
  }
}

///////// -- Sys Functions

// Debug andler for movement detection
void movementDetected() {
  sendMV();
  if (armed_status) {
    safetyModeInit();
  }
}

// Sleep trigger for when movement stealth mode is activated
void safetyModeInit() {
  esp_sleep_enable_timer_wakeup(7000000);
  esp_deep_sleep_start();
}

// Function for handling SOS mode, used for regular function of alarm trigger, however, this packet when identified by TTN will use an SMS webhook to contact an emergency contact with information
void SOS_trigger () {
  sos_triggered = true;
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Setup method - Called upon init of system //esp_sleep_enable_ulp_wakeup(); //os_setCallback(&singlepacket, send_data);
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\



void setup() {
  Serial.begin(115200); // Initialise serial 
  Serial.println("LoRa32 GPS Tracker"); // Init message

  // Pinmode Configs
  pinMode(BUTTON_PIN, INPUT_PULLUP);      // SOS Button - Pin Mode Definition
  pinMode(ACCEL_INT, INPUT);              // ADXL343 Interrupt - Pin Mode Definition
  pinMode(BUILTIN_LED, OUTPUT);           // System LED - Pin Mode Defininition
  digitalWrite(BUILTIN_LED, LOW);         // System LED - Reserved for Status Update
  
  // Unility Initialisation
  Wire.begin(); // Init wire for use in ADXL & GPS
  os_init(); // Init LMIC os - handles LMIC internals

  // LMIC Configuration
  LMIC_reset(); // Resets LMIC internals
  LMIC_setAdrMode(1); // Current Address Mode - 0 for moving device, 1 for static 
  LMIC_setSession(0x1, DEVADDR, NWKSKEY, APPSKEY);  // Sets ABP session info for TTN connection

  LMIC_setupChannel(0, 868100000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(1, 868300000, DR_RANGE_MAP(DR_SF12, DR_SF7B), BAND_CENTI);      // G-Band
  LMIC_setupChannel(2, 868500000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(3, 867100000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(4, 867300000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(5, 867500000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(6, 867700000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(7, 867900000, DR_RANGE_MAP(DR_SF12, DR_SF7),  BAND_CENTI);      // G-Band
  LMIC_setupChannel(8, 868800000, DR_RANGE_MAP(DR_FSK,  DR_FSK),  BAND_MILLI);      // G2-Band 
  LMIC.dn2Dr = DR_SF9;
  LMIC_setDrTxpow(DR_SF7, 14);

  // BLE Configuration
  BLEDevice::init("RideSafe Debug");  // BLE Initialisation

  BLEServer* pServer = BLEDevice::createServer();
  BLEService* pService = pServer->createService(serviceID);
  pServer->setCallbacks(new MyServerCallbacks());

  // GPS BLE Characteristic
  callbackCharacteristic = pService->createCharacteristic(
    devGPSID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_INDICATE);
  callbackCharacteristic->addDescriptor(new BLE2902());

  // MV Detect Characteristic
  gpsCharacteristic = pService->createCharacteristic(
    appMovementID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_INDICATE);
  gpsCharacteristic->addDescriptor(new BLE2902());

  // Arm BLE Characteristic
  BLECharacteristic* armCharacteristic = pService->createCharacteristic(
    appDataID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ);
  armCharacteristic->setValue(armvalue_store, 1);
  armCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();  // Start the service
  bleStart();

  // Module Config 
  // NEO-M8N Initialisation
  GPSSerial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX); // GPS Serial begin on pre-defined pins     
  GPSSerial.setTimeout(2);  // GPS Timeout Config

  // ADXL343 Accelerometer Initialisation
  accel_int_enabled.bits.activity = true;

  Accel.begin();                                
  Accel.setRange(ADXL343_RANGE_16_G);
  Accel.setDataRate(ADXL343_DATARATE_100_HZ);
  Accel.enableInterrupts(accel_int_enabled);
  attachInterrupt(digitalPinToInterrupt(ACCEL_INT), movementDetected, RISING);

  // Send data initial call - starts loop of callbacks via LMIC
  send_data(&singlepacket);
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Loop method - Dependant on LMIC state
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\



void loop() {
  sos_input = digitalRead(BUTTON_PIN); // Int Variable - Stores digital read of IO38 to be used for hold detection

  sensors_event_t event;    // ADXL sensor event variable
  Accel.getEvent(&event);   // ADXL event capture & assignment

  float x = event.acceleration.x;   // Get x-axis acceleration value
  float y = event.acceleration.y;   // Get y-axis acceleration value
  float z = event.acceleration.z;   // Get z-axis acceleration value

  // Method to check button hold time for SOS trigger
  if (sos_input == LOW) {
    if (!button_held) {
      button_held = true;
      button_time = millis();
    } else {
      unsigned long holdTime = millis() - button_time;
      if (holdTime >= 5000) {
        SOS_trigger();
        return;
      }
    }
  } else {
    button_held = false; // Reset button hold var
  }

  // ADXL343 Initial Call - Stores initial variables in a function for use in offset calculation
  if (initial_run) {
    if (event.acceleration.x) {
      initialX = x;
      offsetXMin = initialX - 0.3;
      offsetXMax = initialX + 0.3;
    }
    if (event.acceleration.y) {
      initialY = y;
      offsetYMin = initialY - 0.3;
      offsetYMax = initialY + 0.3;
    }
    if (event.acceleration.z) {
      initialZ = z;
      offsetZMin = initialZ - 0.3;
      offsetZMax = initialZ + 0.3;
    }
    initial_run = false;
  }

  // ADXL343 Movement Comparison / Detection Function - Compares values against defined offsets
  if (x > offsetXMax || x < offsetXMin || y > offsetYMax || y < offsetYMin || z > offsetZMax || z < offsetZMin) {
    if (ble_connected) {
      movementDetected();
      safety_status = false;
      moving_status = true;
      movement_time = millis();
    } else {
      safety_status = false;
    }
  }
  delay(100);         // Loop Delay - used for functions outside of LMIC
  os_runloop_once();  // LMIC Loop Function - manages LMIC internals and states
}