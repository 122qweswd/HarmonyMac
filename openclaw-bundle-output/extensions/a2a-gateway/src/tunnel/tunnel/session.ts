/**
 * Embedded tunnel session — logic aligned with a2a-relay-2/tunnel-client/client.js
 *
 * Differences vs standalone CLI (intentional, for in-process use):
 * - No local HTTP proxy port (--local-port); outbound uses forward() directly
 * - Library API: start()/stop()/forward() instead of process.argv + process.exit
 * - error messages with message_id reject the matching pending request
 */

import http from "node:http";
import { randomUUID } from "node:crypto";
import WebSocket from "ws";

import {
  MessageType,
  filterHeaders,
  type TunnelHttpRequest,
  type TunnelHttpResponse,
  type TunnelLogger,
  type TunnelSessionOptions,
} from "./protocol.js";

type Pending = {
  resolve: (value: TunnelHttpResponse) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

type PendingRegister = {
  resolve: () => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout>;
};

const defaultLogger: TunnelLogger = {
  info: (msg, data) => (data !== undefined ? console.log(msg, data) : console.log(msg)),
  warn: (msg, data) => (data !== undefined ? console.warn(msg, data) : console.warn(msg)),
  error: (msg, data) => (data !== undefined ? console.error(msg, data) : console.error(msg)),
};

export class TunnelSession {
  private readonly opts: Required<
    Pick<
      TunnelSessionOptions,
      | "relayUrl"
      | "deviceId"
      | "localServicePort"
      | "heartbeatIntervalMs"
      | "requestTimeoutMs"
      | "reconnectIntervalMs"
      | "maxReconnectAttempts"
    >
  > & { logger: TunnelLogger };

  private ws: WebSocket | null = null;
  private connected = false;
  /** True only after register succeeds; gates auto-reconnect. */
  private running = false;
  private shouldReconnect = false;
  private reconnectAttempts = 0;
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private readonly pendingRequests = new Map<string, Pending>();
  private starting: Promise<void> | null = null;
  private registerWait: PendingRegister | null = null;

  constructor(options: TunnelSessionOptions) {
    this.opts = {
      relayUrl: options.relayUrl,
      deviceId: options.deviceId,
      localServicePort: options.localServicePort,
      heartbeatIntervalMs: options.heartbeatIntervalMs ?? 15_000,
      requestTimeoutMs: options.requestTimeoutMs ?? 300_000,
      reconnectIntervalMs: options.reconnectIntervalMs ?? 5_000,
      maxReconnectAttempts: options.maxReconnectAttempts ?? 10,
      logger: options.logger ?? defaultLogger,
    };
  }

  get isConnected(): boolean {
    return this.connected;
  }

  get deviceId(): string {
    return this.opts.deviceId;
  }

  async start(): Promise<void> {
    if (this.starting) return this.starting;
    this.starting = this.doStart();
    try {
      await this.starting;
    } finally {
      this.starting = null;
    }
  }

  private async doStart(): Promise<void> {
    this.shouldReconnect = true;
    this.running = false;
    this.reconnectAttempts = 0;
    try {
      await this.connectAndRegister();
      this.running = true;
      this.startHeartbeat();
      this.opts.logger.info(
        `a2a-tunnel: connected as ${this.opts.deviceId} → ${this.opts.relayUrl} (local service :${this.opts.localServicePort})`,
      );
    } catch (err) {
      this.shouldReconnect = false;
      this.running = false;
      this.stopHeartbeat();
      this.clearRegisterWait(new Error("Tunnel start aborted"));
      if (this.ws) {
        try {
          this.ws.removeAllListeners();
          this.ws.close();
        } catch {
          // ignore
        }
        this.ws = null;
      }
      this.connected = false;
      throw err;
    }
  }

  async stop(): Promise<void> {
    this.shouldReconnect = false;
    this.running = false;
    this.stopHeartbeat();
    this.clearRegisterWait(new Error("Tunnel stopped"));
    for (const [id, pending] of this.pendingRequests) {
      clearTimeout(pending.timer);
      pending.reject(new Error("Tunnel stopped"));
      this.pendingRequests.delete(id);
    }
    if (this.ws) {
      try {
        this.ws.removeAllListeners();
        this.ws.close();
      } catch {
        // ignore
      }
      this.ws = null;
    }
    this.connected = false;
    this.opts.logger.info("a2a-tunnel: stopped");
  }

  private clearRegisterWait(err?: Error): void {
    if (!this.registerWait) return;
    clearTimeout(this.registerWait.timer);
    if (err) this.registerWait.reject(err);
    this.registerWait = null;
  }

  /**
   * Outbound: same as tunnel-client sendForwardRequest + waiting for forward_response.
   */
  async forward(
    targetDevice: string,
    httpRequest: TunnelHttpRequest,
    timeoutMs = this.opts.requestTimeoutMs,
  ): Promise<TunnelHttpResponse> {
    if (!this.connected || !this.ws) {
      throw new Error("Tunnel not connected");
    }

    const messageId = randomUUID();
    const message = {
      type: MessageType.FORWARD_REQUEST,
      message_id: messageId,
      source_device: this.opts.deviceId,
      target_device: targetDevice,
      http_request: {
        method: httpRequest.method,
        path: httpRequest.path,
        headers: filterHeaders(httpRequest.headers),
        body: httpRequest.body ?? "",
      },
      timeout: Math.floor(timeoutMs / 1000),
    };

    return new Promise<TunnelHttpResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingRequests.delete(messageId);
        reject(new Error(`Tunnel timeout: ${timeoutMs}ms`));
      }, timeoutMs);

      this.pendingRequests.set(messageId, { resolve, reject, timer });

      try {
        this.ws!.send(JSON.stringify(message));
      } catch (err) {
        clearTimeout(timer);
        this.pendingRequests.delete(messageId);
        reject(err instanceof Error ? err : new Error(String(err)));
      }
    });
  }

  private async connectAndRegister(): Promise<void> {
    await this.openSocket();
    const registered = new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.registerWait) {
          this.registerWait = null;
          reject(new Error("Tunnel register timeout"));
        }
      }, 10_000);
      this.registerWait = { resolve, reject, timer };
    });
    if (!this.send({ type: MessageType.REGISTER, device_id: this.opts.deviceId })) {
      this.clearRegisterWait(new Error("Failed to send register message"));
    }
    await registered;
    this.reconnectAttempts = 0;
  }

  private openSocket(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.ws) {
        try {
          this.ws.removeAllListeners();
          this.ws.close();
        } catch {
          // ignore
        }
        this.ws = null;
      }

      const ws = new WebSocket(this.opts.relayUrl);
      this.ws = ws;
      let settled = false;

      const timeout = setTimeout(() => {
        if (settled) return;
        settled = true;
        reject(new Error("Tunnel connection timeout"));
        try {
          ws.close();
        } catch {
          // ignore
        }
      }, 10_000);

      ws.on("open", () => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        this.connected = true;
        resolve();
      });

      ws.on("message", (data) => {
        this.handleMessage(data.toString());
      });

      ws.on("error", (err) => {
        this.opts.logger.error(`a2a-tunnel: websocket error: ${err.message}`);
        this.connected = false;
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        reject(err);
      });

      ws.on("close", () => {
        this.connected = false;
        this.opts.logger.warn("a2a-tunnel: websocket closed");
        this.scheduleReconnect();
      });
    });
  }

  private scheduleReconnect(): void {
    // Only reconnect after a successful start (avoid racing failed open/close)
    if (!this.shouldReconnect || !this.running) return;
    if (this.reconnectAttempts >= this.opts.maxReconnectAttempts) {
      this.opts.logger.error("a2a-tunnel: max reconnect attempts reached");
      return;
    }
    this.reconnectAttempts += 1;
    const attempt = this.reconnectAttempts;
    this.opts.logger.info(
      `a2a-tunnel: reconnecting (${attempt}/${this.opts.maxReconnectAttempts})`,
    );
    setTimeout(() => {
      if (!this.shouldReconnect) return;
      void this.connectAndRegister().catch((err) => {
        this.opts.logger.error(
          `a2a-tunnel: reconnect failed: ${err instanceof Error ? err.message : String(err)}`,
        );
      });
    }, this.opts.reconnectIntervalMs);
  }

  private handleMessage(raw: string): void {
    let message: Record<string, unknown>;
    try {
      message = JSON.parse(raw) as Record<string, unknown>;
    } catch (err) {
      this.opts.logger.error(
        `a2a-tunnel: failed to parse message: ${err instanceof Error ? err.message : String(err)}`,
      );
      return;
    }

    const type = String(message.type || "");

    switch (type) {
      case MessageType.FORWARD_REQUEST:
        void this.handleInboundForward(message);
        break;
      case MessageType.FORWARD_RESPONSE:
        this.handleForwardResponse(message);
        break;
      case MessageType.ERROR: {
        const messageId = typeof message.message_id === "string" ? message.message_id : null;
        const errText = typeof message.error === "string" ? message.error : "Tunnel error";
        this.opts.logger.error(`a2a-tunnel: error from relay: ${errText}`);
        if (messageId) {
          const pending = this.pendingRequests.get(messageId);
          if (pending) {
            clearTimeout(pending.timer);
            this.pendingRequests.delete(messageId);
            pending.reject(new Error(errText));
          }
        } else if (this.registerWait) {
          clearTimeout(this.registerWait.timer);
          this.registerWait.reject(new Error(errText));
          this.registerWait = null;
        }
        break;
      }
      case MessageType.PING:
        this.send({ type: MessageType.PONG });
        break;
      case MessageType.PONG:
        break;
      case MessageType.REGISTERED:
        if (this.registerWait) {
          clearTimeout(this.registerWait.timer);
          this.registerWait.resolve();
          this.registerWait = null;
        }
        break;
      default:
        this.opts.logger.warn(`a2a-tunnel: unknown message type: ${type}`);
    }
  }

  private handleForwardResponse(message: Record<string, unknown>): void {
    const messageId = typeof message.message_id === "string" ? message.message_id : "";
    const pending = this.pendingRequests.get(messageId);
    if (!pending) return;

    clearTimeout(pending.timer);
    this.pendingRequests.delete(messageId);

    const httpResponse = message.http_response as TunnelHttpResponse | undefined;
    if (!httpResponse || typeof httpResponse.status !== "number") {
      pending.reject(new Error("Invalid forward_response"));
      return;
    }
    pending.resolve({
      status: httpResponse.status,
      headers: httpResponse.headers || {},
      body: typeof httpResponse.body === "string" ? httpResponse.body : String(httpResponse.body ?? ""),
    });
  }

  /** Inbound path: same as tunnel-client handler → localServicePort */
  private async handleInboundForward(message: Record<string, unknown>): Promise<void> {
    const messageId = String(message.message_id || "");
    const httpRequest = message.http_request as TunnelHttpRequest | undefined;
    const path = httpRequest?.path || "/";
    const method = (httpRequest?.method || "GET").toUpperCase();
    const localUrl = `http://127.0.0.1:${this.opts.localServicePort}${path}`;

    try {
      const localResponse = await this.makeLocalHttpRequest(
        method,
        localUrl,
        httpRequest?.body ?? "",
        httpRequest?.headers || {},
      );

      this.send({
        type: MessageType.FORWARD_RESPONSE,
        message_id: messageId,
        http_response: {
          status: localResponse.status,
          headers: filterHeaders(localResponse.headers),
          body: localResponse.body,
        },
        status: localResponse.status,
      });
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      this.opts.logger.error(`a2a-tunnel: inbound forward failed: ${errMsg}`);
      this.send({
        type: MessageType.FORWARD_RESPONSE,
        message_id: messageId,
        http_response: {
          status: 500,
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ error: errMsg }),
        },
        status: 500,
      });
    }
  }

  private makeLocalHttpRequest(
    method: string,
    url: string,
    body: string,
    headers: Record<string, string | string[] | undefined>,
  ): Promise<TunnelHttpResponse> {
    return new Promise((resolve, reject) => {
      const forwardHeaders = filterHeaders(headers);
      const options: http.RequestOptions = {
        method,
        headers: { ...forwardHeaders },
      };

      const bodyStr = body || "";
      if (method !== "GET" && method !== "HEAD") {
        (options.headers as Record<string, string | number>)["content-length"] =
          Buffer.byteLength(bodyStr);
      }

      const req = http.request(url, options, (res) => {
        let responseData = "";
        res.on("data", (chunk) => {
          responseData += chunk.toString();
        });
        res.on("end", () => {
          resolve({
            status: res.statusCode || 500,
            headers: res.headers as Record<string, string | string[] | undefined>,
            body: responseData,
          });
        });
        res.on("error", reject);
      });

      req.setTimeout(this.opts.requestTimeoutMs, () => {
        req.destroy();
        reject(new Error(`Local request timeout after ${this.opts.requestTimeoutMs}ms`));
      });
      req.on("error", reject);

      if (method !== "GET" && method !== "HEAD" && bodyStr) {
        req.write(bodyStr);
      }
      req.end();
    });
  }

  private send(message: Record<string, unknown>): boolean {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      this.opts.logger.warn("a2a-tunnel: cannot send, socket not open");
      return false;
    }
    try {
      this.ws.send(JSON.stringify(message));
      return true;
    } catch (err) {
      this.opts.logger.error(
        `a2a-tunnel: send failed: ${err instanceof Error ? err.message : String(err)}`,
      );
      return false;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.connected && this.ws) {
        this.send({ type: MessageType.PING });
      }
    }, this.opts.heartbeatIntervalMs);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }
}

export function createTunnelSession(options: TunnelSessionOptions): TunnelSession {
  return new TunnelSession(options);
}
