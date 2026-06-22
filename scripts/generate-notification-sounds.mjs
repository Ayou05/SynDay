import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sampleRate = 22050;

const definitions = {
  review_wood: [
    { at: 0, duration: 0.22, frequency: 430, gain: 0.42, decay: 18 },
    { at: 0.12, duration: 0.22, frequency: 330, gain: 0.32, decay: 20 },
  ],
  bedtime_bell: [
    { at: 0, duration: 0.9, frequency: 784, gain: 0.2, decay: 4 },
    { at: 0, duration: 0.9, frequency: 1568, gain: 0.08, decay: 6 },
  ],
  partner_task: [
    { at: 0, duration: 0.12, frequency: 980, gain: 0.12, decay: 24, noise: 0.16 },
    { at: 0.09, duration: 0.16, frequency: 620, gain: 0.16, decay: 18, noise: 0.09 },
  ],
  partner_join: [
    { at: 0, duration: 0.28, frequency: 523.25, gain: 0.2, decay: 8 },
    { at: 0.2, duration: 0.34, frequency: 659.25, gain: 0.2, decay: 7 },
  ],
  streak_milestone: [
    { at: 0, duration: 0.24, frequency: 523.25, gain: 0.16, decay: 8 },
    { at: 0.16, duration: 0.25, frequency: 659.25, gain: 0.18, decay: 8 },
    { at: 0.32, duration: 0.42, frequency: 783.99, gain: 0.19, decay: 6 },
  ],
};

function render(events) {
  const lengthSeconds = Math.max(...events.map((event) => event.at + event.duration)) + 0.08;
  const samples = new Float32Array(Math.ceil(lengthSeconds * sampleRate));
  let seed = 0x51f15e;
  const random = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 0xffffffff;
  };

  for (const event of events) {
    const start = Math.floor(event.at * sampleRate);
    const count = Math.floor(event.duration * sampleRate);
    for (let index = 0; index < count; index += 1) {
      const t = index / sampleRate;
      const envelope = Math.exp(-(event.decay || 8) * t) * Math.min(1, t / 0.008);
      const tone = Math.sin(2 * Math.PI * event.frequency * t);
      const noise = event.noise ? (random() * 2 - 1) * event.noise : 0;
      samples[start + index] += (tone * event.gain + noise) * envelope;
    }
  }
  return samples;
}

function wav(samples) {
  const dataLength = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataLength);
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + dataLength, 4);
  buffer.write("WAVE", 8);
  buffer.write("fmt ", 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(dataLength, 40);
  samples.forEach((sample, index) => {
    buffer.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + index * 2);
  });
  return buffer;
}

const destinations = [
  path.join(root, "frontend/src-tauri/sounds"),
  path.join(root, "frontend/src-tauri/gen/apple/assets/sounds"),
  path.join(root, "frontend/src-tauri/gen/android/app/src/main/res/raw"),
];

for (const destination of destinations) {
  fs.mkdirSync(destination, { recursive: true });
}

for (const [name, events] of Object.entries(definitions)) {
  const data = wav(render(events));
  for (const destination of destinations) {
    fs.writeFileSync(path.join(destination, `${name}.wav`), data);
  }
}

console.log(`Generated ${Object.keys(definitions).length} notification sounds.`);

