//通过另外一个代码的处理逻辑，用于控制风扇转速，对应LED指示灯，另外单独增加一个控制器。
#include <WiFi.h>
#include <PubSubClient.h>
#include "Freenove_WS2812_Lib_for_ESP32.h"

// LED 灯条相关定义
#define LEDS_COUNT  8           // LED 灯条的 LED 数量
#define LEDS_PIN    21          // 连接 LED 灯条的 GPIO 引脚
#define CHANNEL     0           // LED 灯条的通道

Freenove_ESP32_WS2812 strip = Freenove_ESP32_WS2812(LEDS_COUNT, LEDS_PIN, CHANNEL, TYPE_GRB);

// PWM 风扇相关定义
#define PWM_PIN      13          // 风扇 PWM 控制的 GPIO 引脚
#define PWM_CHANNEL  0           // PWM 通道
#define PWM_FREQUENCY 5000       // PWM 频率
#define PWM_RESOLUTION 8         // PWM 分辨率

// GPIO 引脚定义
#define GPIO11       11          // 物理开关 11 的 GPIO 引脚
#define GPIO12       12          // 物理开关 12 的 GPIO 引脚
#define GPIO14       14          // 继电器的 GPIO 引脚
#define GPIO15       15          // 控制继电器的开关 GPIO 引脚

// MQTT 设置
const char* g_ssid = "your Wifi Name";      // WiFi 名称
const char* g_password = "Wifi Password";   // WiFi 密码
const char* g_mqtt_server = "192.168.1.25"; // MQTT 服务器地址
const char* g_mqttUser = "mosquitto";       // MQTT 用户名
const char* g_mqttPsw = "password";         // MQTT 密码
int g_mqttPort = 1883;                      // MQTT 端口
const char* g_deviceName = "CustomFan";     // 设备名称
const char* g_mqttStatusTopic = "esp32fan/" + String(g_deviceName); // MQTT 状态主题

// 全局变量
WiFiClient g_WiFiClient;                   // WiFi 客户端对象
PubSubClient g_mqttPubSub(g_WiFiClient);  // MQTT 客户端对象
int g_input_Switch11;                     // GPIO11 开关状态
int g_input_Switch12;                     // GPIO12 开关状态
String g_strFanStatus;                    // 风扇状态字符串

// 设置函数
void setup() 
{
    Serial.begin(115200);
    delay(500);

    // 初始化 LED 灯条
    strip.begin();
    strip.setBrightness(20);

    // 初始化 PWM
    ledcSetup(PWM_CHANNEL, PWM_FREQUENCY, PWM_RESOLUTION);
    ledcAttachPin(PWM_PIN, PWM_CHANNEL);

    // 设置 GPIO 模式
    pinMode(GPIO11, INPUT_PULLUP);   // GPIO11 设置为上拉输入模式
    pinMode(GPIO12, INPUT_PULLUP);   // GPIO12 设置为上拉输入模式
    pinMode(GPIO14, OUTPUT);         // GPIO14 设置为输出模式
    pinMode(GPIO15, INPUT_PULLUP);   // GPIO15 设置为上拉输入模式

    // 初始化 WiFi
    setup_wifi();

    // 初始化 MQTT
    g_mqttPubSub.setServer(g_mqtt_server, g_mqttPort);
    g_mqttPubSub.setCallback(MqttReceiverCallback);
}

// 主循环函数
void loop() 
{
    // MQTT 连接
    if (WiFi.status() == WL_CONNECTED)
    {
        if (!g_mqttPubSub.connected())
            MqttReconnect();   // 如果 MQTT 未连接，尝试重连
        else
            g_mqttPubSub.loop(); // 处理 MQTT 消息
    }

    // 读取开关状态
    g_input_Switch11 = digitalRead(GPIO11);
    g_input_Switch12 = digitalRead(GPIO12);

    // 根据开关输入更新风扇转速和 LED 状态
    if (g_input_Switch12 == LOW) 
    {
        // GPIO12 按下，风扇全速运转
        ledcWrite(PWM_CHANNEL, 255);
        g_strFanStatus = "Full Speed";
    } 
    else if (g_input_Switch11 == LOW) 
    {
        // GPIO11 按下，风扇半速运转
        ledcWrite(PWM_CHANNEL, 128);
        g_strFanStatus = "Half Speed";
    } 
    else 
    {
        // 没有按下开关，关闭风扇
        ledcWrite(PWM_CHANNEL, 0);
        g_strFanStatus = "Off";
    }

    // 根据风扇状态更新 LED 灯条
    if (g_strFanStatus == "Full Speed") 
    {
        // 全速运转：红色波动效果
        for (int j = 0; j < 255; j += 2) 
        {
            for (int i = 0; i < LEDS_COUNT; i++) 
            {
                strip.setLedColorData(i, strip.Color(255, 0, 0)); // 红色
            }
            strip.show();
            delay(10);
        }
    } 
    else if (g_strFanStatus == "Half Speed") 
    {
        // 半速运转：黄色波动效果
        for (int j = 0; j < 255; j += 2) 
        {
            for (int i = 0; i < LEDS_COUNT; i++) 
            {
                strip.setLedColorData(i, strip.Color(255, 255, 0)); // 黄色
            }
            strip.show();
            delay(10);
        }
    } 
    else 
    {
        // 关闭：LED 熄灭
        for (int i = 0; i < LEDS_COUNT; i++) 
        {
            strip.setLedColorData(i, strip.Color(0, 0, 0)); // 熄灭
        }
        strip.show();
    }

    // 延时，限制循环执行频率
    delay(100);
}

// 设置 WiFi 连接
void setup_wifi() 
{
    int counter = 0;
    delay(10);
    Serial.print("Connecting to ");
    Serial.println(g_ssid);

    WiFi.begin(g_ssid, g_password);

    while (WiFi.status() != WL_CONNECTED && counter++ < 8) 
    {
        delay(1000);
        Serial.print(".");
    }
    Serial.println("");

    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.println("WiFi connected");
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
    } 
    else
    {
        Serial.println("WiFi NOT connected!!!");
    }
}

// 重新连接到 MQTT
void MqttReconnect() 
{
    while (!g_mqttPubSub.connected()) 
    {
        Serial.print("Attempting MQTT connection...");
        if (g_mqttPubSub.connect(g_deviceName.c_str(), g_mqttUser, g_mqttPsw)) 
        {
            Serial.println("connected");
            g_mqttPubSub.subscribe("homeassistant/status");
            delay(100);
        } 
        else 
        {
            Serial.print("failed, rc=");
            Serial.print(g_mqttPubSub.state());
            Serial.println(" try again in 1 seconds");
            delay(1000);
        }
    }  
}

// 处理 MQTT 消息
void MqttReceiverCallback(char* topic, byte* inFrame, unsigned int length) 
{
    Serial.print("Message arrived on topic: ");
    Serial.print(topic);
    Serial.print(". Message: ");
    String messageTemp;
    
    for (int i = 0; i < length; i++) 
    {
        messageTemp += (char)inFrame[i];
    }
    Serial.println();
  
    if (String(topic) == String("homeassistant/status")) 
    {
        if (messageTemp == "online")
        {
            MqttHomeAssistantDiscovery(); // 处理 Home Assistant 发现
        }
    }
}

// 发送 Home Assistant 发现数据
void MqttHomeAssistantDiscovery()
{
    String discoveryTopic;
    String payload;
    String strPayload;
    
    if (g_mqttPubSub.connected())
    {
        Serial.println("SEND HOME ASSISTANT DISCOVERY!!!");
        StaticJsonDocument<600> payloadDoc;
        JsonObject device;
        JsonArray identifiers;

        // PWM 风扇
        discoveryTopic = "homeassistant/fan/esp32fan/" + String(g_deviceName) + "/config";
        
        payloadDoc["name"] = g_deviceName + ".fan";
        payloadDoc["uniq_id"] = g_deviceName + "_fan";
        payloadDoc["stat_t"] = g_mqttStatusTopic;
        payloadDoc["command_topic"] = g_mqttStatusTopic + "/set";
        payloadDoc["speed_command_topic"] = g_mqttStatusTopic + "/speed/set";
        payloadDoc["val_tpl"] = "{{ value_json.fan_status | is_defined }}";
        payloadDoc["speed_state_topic"] = g_mqttStatusTopic + "/speed/state";
        payloadDoc["speed_state_template"] = "{{ value_json.fan_speed }}";
        device = payloadDoc.createNestedObject("device");
        device["name"] = g_deviceName;
        device["model"] = "ESP32 Fan";
        device["sw_version"] = "1.0";
        device["identifiers"] = JsonArray();
        identifiers.add(g_deviceName);

        serializeJsonPretty(payloadDoc, Serial);
        Serial.println(" ");
        serializeJson(payloadDoc, strPayload);

        g_mqttPubSub.publish(discoveryTopic.c_str(), strPayload.c_str());
    }
}
