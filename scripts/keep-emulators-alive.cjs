// Invoked by emulators:exec after seeding; Ctrl+C stops the local demo.
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error("Emulators required");
}
console.log("Lab 2 demo ready. Emulator UI: http://127.0.0.1:4000 — Ctrl+C to stop.");
const keepAlive = setInterval(() => {}, 60000);
for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => {
    clearInterval(keepAlive);
    process.exit(0);
  });
}
