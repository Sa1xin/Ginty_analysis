/*
  Arduino sketch for dual camera trigger (120 Hz)
  and optional randomized LED pulsing (50 Hz).
*/

const int camTriggerPin = 2;
const int ledPin = 3;
const int ledIndicatorPin = 4; // Optional debug pin

unsigned long lastCamTrigger = 0;
const unsigned long camInterval = 8333; // microseconds (120 Hz)

bool ledEnabled = false;
bool ledOn = false;
unsigned long ledPulseStart = 0;
unsigned long ledInterval = 20000; // 50 Hz = 20 ms
unsigned long ledPulseDuration = 10000; // microseconds per ON pulse (adjustable)

unsigned long stimStart = 0;
unsigned long onDuration = 10000000; // microseconds
unsigned long offDuration = 5000000; // microseconds
bool inStimBlock = false;
unsigned long nextStimBlockTime = 0;

void setup() {
  pinMode(camTriggerPin, OUTPUT);
  pinMode(ledPin, OUTPUT);
  pinMode(ledIndicatorPin, OUTPUT);
  digitalWrite(camTriggerPin, LOW);
  digitalWrite(ledPin, LOW);
  digitalWrite(ledIndicatorPin, LOW);
  Serial.begin(115200);
}

void loop() {
  // Check for serial input
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.startsWith("CONFIG")) {
      float onTime, offTime;
      sscanf(cmd.c_str(), "CONFIG %f %f", &onTime, &offTime);
      onDuration = onTime * 1e6;
      offDuration = offTime * 1e6;
      ledEnabled = true;
    }
    if (cmd == "START") {
      stimStart = micros();
      inStimBlock = ledEnabled;
      nextStimBlockTime = stimStart + (inStimBlock ? onDuration : offDuration);
      Serial.println("STARTED");
    }
  }

  unsigned long now = micros();

  // Trigger camera at 120 Hz
  if (now - lastCamTrigger >= camInterval) {
    digitalWrite(camTriggerPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(camTriggerPin, LOW);
    lastCamTrigger = now;
  }

  // LED logic
  if (stimStart > 0 && ledEnabled) {
    if (inStimBlock) {
      // LED ON block — pulse at 50 Hz
      if ((now - ledPulseStart) >= ledInterval) {
        digitalWrite(ledPin, HIGH);
        digitalWrite(ledIndicatorPin, HIGH);
        delayMicroseconds(ledPulseDuration);
        digitalWrite(ledPin, LOW);
        digitalWrite(ledIndicatorPin, LOW);
        ledPulseStart = now;
      }
    }

    // Check for block duration switch
    if (now >= nextStimBlockTime) {
      inStimBlock = !inStimBlock;
      nextStimBlockTime = now + (inStimBlock ? onDuration : offDuration);
      String msg = inStimBlock ? "LED_ON t=" : "LED_OFF t=";
      msg += String(now);
      Serial.println(msg);
    }
  }
}
