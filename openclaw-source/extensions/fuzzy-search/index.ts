import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import type { OpenClawPluginApi } from "openclaw/plugin-sdk";

const execFileAsync = promisify(execFile);

type FuzzySearchConfig = {
  enabled: boolean;
  toolPath: string;
  rootPath: string;
  timeoutMs: number;
  maxLimit: number;
};

type Result = {
  relativePath: string;
  fileName: string;
  fileExtension: string;
  size: number | null;
  modifiedAt: string | null;
  score: number;
};

function object(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function string(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function number(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function boolean(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function config(raw: unknown, resolvePath: (input: string) => string): FuzzySearchConfig {
  const value = object(raw);
  const resolve = (input: unknown) => {
    const configured = string(input);
    return configured ? resolvePath(configured) : "";
  };
  return {
    enabled: boolean(value.enabled),
    toolPath: resolve(value.toolPath ?? value.executablePath),
    rootPath: resolve(value.rootPath),
    timeoutMs: Math.max(1_000, Math.min(120_000, number(value.timeoutMs, 20_000))),
    maxLimit: Math.max(1, Math.min(200, Math.floor(number(value.maxLimit, 50)))),
  };
}

function resultFrom(value: unknown): Result | null {
  const candidate = object(value);
  const relativePath = string(candidate.relativePath);
  const fileName = string(candidate.fileName);
  const fileExtension = string(candidate.fileExtension);
  const score = number(candidate.score, Number.NaN);
  // Only relative paths are ever exposed to the model. This also rejects traversal.
  if (
    !relativePath ||
    path.isAbsolute(relativePath) ||
    relativePath.split(path.sep).includes("..") ||
    !fileName ||
    !Number.isFinite(score)
  ) {
    return null;
  }
  return {
    relativePath,
    fileName,
    fileExtension,
    size:
      typeof candidate.size === "number" && Number.isFinite(candidate.size) ? candidate.size : null,
    modifiedAt: typeof candidate.modifiedAt === "string" ? candidate.modifiedAt : null,
    score,
  };
}

async function validateRuntime(cfg: FuzzySearchConfig): Promise<string | null> {
  if (
    !cfg.toolPath ||
    !cfg.rootPath ||
    !path.isAbsolute(cfg.toolPath) ||
    !path.isAbsolute(cfg.rootPath)
  ) {
    return "configuration must use absolute toolPath and rootPath";
  }
  const basename = path.basename(cfg.toolPath);
  if (basename !== "MyersBitParallelFuzzySearch.swift" && basename !== "myers-bit-parallel-fuzzy-search") {
    return "toolPath must reference MyersBitParallelFuzzySearch.swift or its compiled executable";
  }
  try {
    const [tool, root] = await Promise.all([
      fs.stat(cfg.toolPath),
      fs.stat(cfg.rootPath),
    ]);
    if (!tool.isFile() || !root.isDirectory())
      return "configured paths have unexpected file types";
  } catch {
    return "configured tool or root is unavailable";
  }
  return null;
}

const plugin = {
  id: "fuzzy-search",
  name: "Fuzzy Search",
  description: "Controlled local fuzzy file search backed by Myers bit-parallel Swift search",

  register(api: OpenClawPluginApi) {
    const cfg = config(api.pluginConfig, api.resolvePath);
    api.registerTool({
      name: "fuzzy_search",
      label: "Fuzzy Search",
      description:
        "Fuzzy-search the configured user-authorized directory. The search root is fixed by host configuration. " +
        "The Swift tool enumerates files directly and returns metadata plus relative paths only.",
      parameters: {
        type: "object" as const,
        required: ["query"],
        properties: {
          query: { type: "string" as const, description: "Filename or relative-path query" },
          limit: {
            type: "number" as const,
            description: "Result cap, bounded by host configuration",
          },
        },
      },
      async execute(_toolCallId, params) {
        if (!cfg.enabled) {
          return {
            content: [
              { type: "text" as const, text: "Fuzzy search is disabled by plugin configuration." },
            ],
            details: { ok: false, reason: "disabled" },
          };
        }
        const query = string(params.query);
        if (!query)
          return {
            content: [{ type: "text" as const, text: "query must not be empty" }],
            details: { ok: false, reason: "empty_query" },
          };
        const runtimeError = await validateRuntime(cfg);
        if (runtimeError)
          return {
            content: [{ type: "text" as const, text: `Fuzzy search unavailable: ${runtimeError}` }],
            details: { ok: false, reason: "invalid_runtime" },
          };
        const mode = string(params.mode) === "fuzzy" ? "fuzzy" : "indexed";
        const limit = Math.max(
          1,
          Math.min(cfg.maxLimit, Math.floor(number(params.limit, cfg.maxLimit))),
        );
        const swiftModuleCachePath = path.join(os.tmpdir(), "openclaw-fuzzy-search-module-cache");
        const useSwiftSource = cfg.toolPath.endsWith(".swift");
        if (useSwiftSource) {
          await fs.mkdir(swiftModuleCachePath, { recursive: true });
        }
        const toolCommand = useSwiftSource ? "/usr/bin/swift" : cfg.toolPath;
        const args = useSwiftSource ? ["-module-cache-path", swiftModuleCachePath, cfg.toolPath] : [];
        args.push(
          "search",
          query,
          "--limit",
          String(limit),
          "--root",
          cfg.rootPath,
        );
        try {
          const output = await execFileAsync(toolCommand, args, {
            timeout: cfg.timeoutMs,
            maxBuffer: 1024 * 1024,
            encoding: "utf8",
            env: useSwiftSource
              ? { ...process.env, CLANG_MODULE_CACHE_PATH: swiftModuleCachePath }
              : process.env,
          });
          const parsed: unknown = JSON.parse(output.stdout);
          const results = Array.isArray(parsed)
            ? parsed.map(resultFrom).filter((entry): entry is Result => entry !== null)
            : [];
          return {
            content: [{ type: "text" as const, text: JSON.stringify(results) }],
            details: { ok: true, mode: "fuzzy", results },
          };
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : String(error);
          api.logger.warn(`fuzzy-search: Swift search failed: ${message}`);
          return {
            content: [{ type: "text" as const, text: `Fuzzy search failed: ${message}` }],
            details: { ok: false, error: message },
          };
        }
      },
    });
  },
};

export default plugin;
