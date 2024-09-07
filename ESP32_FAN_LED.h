#include <WiFi.h>
#include <PubSubClient.h>
#include "Freenove_WS2812_Lib_for_ESP32.h"
#include <ArduinoJson.h>

#define LEDS_COUNT  8
#define LEDS_PIN    21
#define CHANNEL     0
#define PWM_CHANNEL 0
#define PWM_RES     8
#define PWM_FREQ    5000

#define FAN_PIN     13
#define RELAY_PIN   14
#define SWITCH1_PIN 11
#define SWITCH2_PIN 12
#define RELAY_CTRL_PIN 15

Freenove_ESP32_WS2812 strip = Freenove_ESP32_WS2812(LEDS_COUNT, LEDS_PIN, CHANNEL, TYPE_GRB);

const char* ssid = "your_wifi_ssid";
const char* password = "your_wifi_password";
const char* mqtt_server = "192.168.1.25";
const char* mqtt_user = "mqtt_user";
const char* mqtt_password = "mqtt_password";
const int mqtt_port = 1883;

// MQTT 发现配置变量
const char* deviceModel = "ESP32S3";
const char* swVersion = "0.1";
const char* manufacturer = "WJB";
String deviceName = "PWMfan";
String mqttStatusTopic = "esp32iotctrl/" + deviceName;

WiFiClient espClient;
PubSubClient client(espClient);

int fanSpeed = 0;
bool relayState = false;
bool switch1State = false;
bool switch2State = false;

void setup() {
  pinMode(FAN_PIN, OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(RELAY_CTRL_PIN, INPUT);  // 将开关引脚设置为输入模式
  pinMode(SWITCH1_PIN, INPUT_PULLUP);
  pinMode(SWITCH2_PIN, INPUT_PULLUP);


  strip.begin();
  strip.setBrightness(20);

  Serial.begin(115200);
  delay(500);

  Serial.println("");
  Serial.println("");
  Serial.println("----------------------------------------------");
  Serial.print("MODEL: ");
  Serial.println(deviceModel);
  Serial.print("DEVICE: ");
  Serial.println(deviceName);
  Serial.print("SW Rev: ");
  Serial.println(swVersion);
  Serial.println("----------------------------------------------");

  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(MqttReceiverCallback);

  ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RES);
  ledcAttachPin(FAN_PIN, PWM_CHANNEL);
}

void loop() {
  if (!client.connected()) {
    MqttReconnect();
  }
  client.loop();

  // 读取开关状态
  switch1State = digitalRead(SWITCH1_PIN) == LOW;
  switch2State = digitalRead(SWITCH2_PIN) == LOW;

  // 控制风扇
  if (switch2State) {
    fanSpeed = 255; // 风扇全速
  } else if (switch1State) {
    fanSpeed = 128; // 风扇半速
  } else {
    fanSpeed = 0; // 关闭风扇
  }
  ledcWrite(PWM_CHANNEL, fanSpeed);

  // 控制继电器
  // 读取开关引脚 RELAY_CTRL_PIN 的状态
  bool switchState = digitalRead(RELAY_CTRL_PIN);

  // 根据开关状态控制继电器
  // 如果开关是低电平（表示开关打开），则开启继电器；否则，关闭继电器
  if (switchState == LOW) {  
    digitalWrite(RELAY_PIN, HIGH);  // 开启继电器
  } else {  
    digitalWrite(RELAY_PIN, LOW);   // 关闭继电器
  }


  // 更新LED灯条效果
  updateLEDs();
}

void setup_wifi() {
  delay(10);
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("Connected!");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void MqttReconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_password)) {
      Serial.println("connected");
      client.subscribe("homeassistant/status");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void MqttReceiverCallback(char* topic, byte* payload, unsigned int length) {
  String messageTemp;
  for (int i = 0; i < length; i++) {
    messageTemp += (char)payload[i];
  }

  if (String(topic) == "homeassistant/status") {
    if (messageTemp == "online") {
      mqttHomeAssistantDiscovery();
    }
  }
}

void mqttHomeAssistantDiscovery() {
  if (client.connected()) {
    String discoveryTopic;
    String strPayload;

    // 发送风扇配置
    discoveryTopic = "homeassistant/fan/esp32_fan/config";
    StaticJsonDocument<600> payload;
    payload["name"] = "Fan";
    payload["uniq_id"] = "fan_01";
    payload["command_topic"] = mqttStatusTopic + "/fan/set";
    payload["state_topic"] = mqttStatusTopic + "/fan/state";
    payload["speed_command_topic"] = mqttStatusTopic + "/fan/speed/set";
    payload["speed_state_topic"] = mqttStatusTopic + "/fan/speed/state";
    serializeJson(payload, strPayload);
    client.publish(discoveryTopic.c_str(), strPayload.c_str(), true);
    delay(500);

    // 发送继电器配置
    discoveryTopic = "homeassistant/switch/esp32_relay/config";
    payload.clear();
    payload["name"] = "Relay";
    payload["uniq_id"] = "relay_01";
    payload["command_topic"] = mqttStatusTopic + "/relay/set";
    payload["state_topic"] = mqttStatusTopic + "/relay/state";
    serializeJson(payload, strPayload);
    client.publish(discoveryTopic.c_str(), strPayload.c_str(), true);
    delay(500);

    // 发送 WS2812 控制配置
    discoveryTopic = "homeassistant/light/esp32iotfan/" + deviceName + "_ws2812/config";
    payload.clear();
    payload["name"] = deviceName + ".ws2812";
    payload["uniq_id"] = deviceName + "_ws2812";
    payload["cmd_t"] = mqttStatusTopic + "/ws2812/set";
    payload["stat_t"] = mqttStatusTopic + "/ws2812/state";
    payload["name"] = "WS2812 Control";
    payload["qos"] = 1;
    payload["retain"] = false;
    serializeJson(payload, strPayload);
    client.publish(discoveryTopic.c_str(), strPayload.c_str(), true);
    delay(500);
  }
}

void updateLEDs() {
  if (fanSpeed == 0) {
    // 风扇关闭，LED条熄灭
    for (int i = 0; i < LEDS_COUNT; i++) {
      strip.setLedColorData(i, strip.Color(0, 0, 0)); // 关闭
    }
    strip.show();
  } else if (fanSpeed > 0 && fanSpeed < 128) {
    // 0-128 之间的速度，红色闪烁频率增强
    int blinkInterval = map(fanSpeed, 0, 128, 500, 50); // 闪烁频率随速度增强
    for (int i = 0; i < LEDS_COUNT; i++) {
      strip.setLedColorData(i, strip.Color(255, 0, 0)); // 红色
    }
    strip.show();
    delay(blinkInterval);
    for (int i = 0; i < LEDS_COUNT; i++) {
      strip.setLedColorData(i, strip.Color(0, 0, 0)); // 关闭
    }
    strip.show();
    delay(blinkInterval);
  } else if (fanSpeed == 128) {
    // 风扇半速，LED显示绿色
    for (int i = 0; i < LEDS_COUNT; i++) {
      strip.setLedColorData(i, strip.Color(0, 255, 0)); // 绿色
    }
    strip.show();
  } else if (fanSpeed > 128 && fanSpeed < 255) {
    // 128-255 之间的速度，蓝色闪烁频率增强
    int blinkInterval = map(fanSpeed, 128, 255, 500, 50); // 闪烁频率随速度增强
    for (int i = 0; i < LEDS_COUNT; i++) {
      strip.setLedColorData(i, strip.Color(0, 0, 255)); // 蓝色
    }
    strip.show();
    delay(blinkInterval);
    for (int i = 0; i < LEDS_COUNT; i++) {
      strip.setLedColorData(i, strip.Color(0, 0, 0)); // 关闭
    }
    strip.show();
    delay(blinkInterval);
  } else if (fanSpeed == 255) {
    // 风扇全速，LED条呈现彩虹波动效果
    for (int j = 0; j < 255; j += 2) {
      for (int i = 0; i < LEDS_COUNT; i++) {
        strip.setLedColorData(i, strip.Wheel((i * 256 / LEDS_COUNT + j) & 255));
      }
      strip.show();
      delay(10);
    }
  }
}

