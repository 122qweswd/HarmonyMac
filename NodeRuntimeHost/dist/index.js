import process from "node:process";

const READY_MARKER = "NODE_RUNTIME_READY";
const SHUTDOWN_MARKER = "NODE_RUNTIME_STOPPED";
const DEFAULT_HEARTBEAT_INTERVAL_MS = 30000;

function resolveConfig(argv) {
  const configIndex = argv.findIndex((arg) => arg === "--config");
  const configPath =
    configIndex >= 0 && configIndex + 1 < argv.length ? argv[configIndex + 1] : null;

  return {
    configPath,
    heartbeatIntervalMs: DEFAULT_HEARTBEAT_INTERVAL_MS,
  };
}

function log(message) {
  process.stdout.write(`${message}\n`);
}

function logError(message) {
  process.stderr.write(`${message}\n`);
}

const runtimeConfig = resolveConfig(process.argv.slice(2));

log(`[node-runtime] pid=${process.pid}`);
log(`[node-runtime] configPath=${runtimeConfig.configPath ?? "null"}`);
log(READY_MARKER);

const heartbeat = setInterval(() => {
  log(`[node-runtime] heartbeat pid=${process.pid}`);
}, runtimeConfig.heartbeatIntervalMs);

heartbeat.unref();

let shuttingDown = false;

function shutdown(signal) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  clearInterval(heartbeat);
  log(`[node-runtime] received ${signal}`);
  log(SHUTDOWN_MARKER);
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

process.on("uncaughtException", (error) => {
  logError(`[node-runtime] uncaughtException: ${error.stack ?? error.message}`);
  process.exit(1);
});

process.on("unhandledRejection", (reason) => {
  logError(`[node-runtime] unhandledRejection: ${String(reason)}`);
  process.exit(1);
});
