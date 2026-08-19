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
};

type Score =
  | "exact"
  | "same_length_one_error"
  | "one_character_shorter"
  | "contains_query"
  | "contains_one_error";

type Result = {
  relativePath: string;
  fileName: string;
  fileExtension: string;
  size: number | null;
  modifiedAt: string | null;
  score: Score;
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
    toolPath: resolve(value.toolPath),
    rootPath: resolve(value.rootPath),
    timeoutMs: Math.max(1_000, Math.min(300_000, number(value.timeoutMs, 20_000))),
  };
}

function resultFrom(value: unknown): Result | null {
  const candidate = object(value);
  const relativePath = string(candidate.relativePath);
  const fileName = string(candidate.fileName);
  const fileExtension = string(candidate.fileExtension);
  const score = string(candidate.score);
  // Only relative paths are ever exposed to the model. This also rejects traversal.
  if (
    !relativePath ||
    path.isAbsolute(relativePath) ||
    relativePath.split(path.sep).includes("..") ||
    !fileName ||
    !isScore(score)
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

function isScore(value: string): value is Score {
  return [
    "exact",
    "same_length_one_error",
    "one_character_shorter",
    "contains_query",
    "contains_one_error",
  ].includes(value);
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

async function resolveDirectory(cfg: FuzzySearchConfig, input: string): Promise<string | null> {
  if (!input || !path.isAbsolute(input)) return null;
  try {
    const [authorizedRoot, directory] = await Promise.all([
      fs.realpath(cfg.rootPath),
      fs.realpath(input),
    ]);
    const relative = path.relative(authorizedRoot, directory);
    if (
      relative === ".." ||
      relative.startsWith(`..${path.sep}`) ||
      path.isAbsolute(relative) ||
      !(await fs.stat(directory)).isDirectory()
    ) {
      return null;
    }
    return directory;
  } catch {
    return null;
  }
}

const plugin = {
  id: "fuzzy-search",
  name: "Fuzzy Search",
  description:
    "All-results tiered fuzzy filename search within an agent-specified authorized directory, backed by Myers bit-parallel Swift search",

  register(api: OpenClawPluginApi) {
    const cfg = config(api.pluginConfig, api.resolvePath);
    api.registerTool({
      name: "fuzzy_search",
      label: "Fuzzy Search",
      description:
        "When you know both a filename query and its directory, call this tool before broader exploration. " +
        "directory is required, must be an absolute path, and is the only directory searched recursively. " +
        "When you know a directory only broadly, first use directory exploration to determine the precise absolute directory, then call this tool. " +
        "when you think the user might mistakenly provide query, search TWICE with the original and the corrected later to avoid problem!" +
        "The directory must be inside the host-authorized root. This is a tiered fuzzy filename search: " +
        "exact matches first; then same-length names with one substitution or adjacent character exchange; " +
        "then names one character shorter; then longer names containing the query; and finally longer names " +
        "containing a one-error query window. All matches are returned, grouped in that order. " +
        "score is the textual match category: exact, same_length_one_error, one_character_shorter, contains_query, or contains_one_error. " +
        "Returns file metadata and paths relative to directory only." +
        "You need to return to user at least one result and the number of results when the request the clear",
      parameters: {
        type: "object" as const,
        required: ["query", "directory"],
        properties: {
          query: { type: "string" as const, description: "Known filename stem query; omit the extension" },
          directory: {
            type: "string" as const,
            description:
              "Required absolute directory path to search recursively; must be inside the host-authorized root",
          },
        },
      },
      async execute(_toolCallId, params) {
        if (!cfg.enabled) {
          return {
            content: [],
            details: { ok: false, result: { reason: "disabled" } },
          };
        }
        const query = string(params.query);
        if (!query)
          return {
            content: [],
            details: { ok: false, result: { reason: "empty_query", message: "query must not be empty" } },
          };
        const requestedDirectory = string(params.directory);
        if (!requestedDirectory || !path.isAbsolute(requestedDirectory))
          return {
            content: [],
            details: {
              ok: false,
              result: { reason: "invalid_directory", message: "directory must be an absolute path" },
            },
          };
        const runtimeError = await validateRuntime(cfg);
        if (runtimeError)
          return {
            content: [],
            details: { ok: false, result: { reason: "invalid_runtime", message: runtimeError } },
          };
        const directory = await resolveDirectory(cfg, requestedDirectory);
        if (!directory)
          return {
            content: [],
            details: {
              ok: false,
              result: {
                reason: "unauthorized_directory",
                message:
                  "directory must exist, be a directory, and remain inside the host-authorized root",
              },
            },
          };
        const swiftModuleCachePath = path.join(os.tmpdir(), "openclaw-fuzzy-search-module-cache");
        const useSwiftSource = cfg.toolPath.endsWith(".swift");
        let temporaryToolDirectory = "";
        let toolCommand = cfg.toolPath;
        let args: string[] = [];
        try {
          if (useSwiftSource) {
            await fs.mkdir(swiftModuleCachePath, { recursive: true });
            temporaryToolDirectory = await fs.mkdtemp(
              path.join(os.tmpdir(), "openclaw-fuzzy-search-"),
            );
            const compiledToolPath = path.join(
              temporaryToolDirectory,
              "myers-bit-parallel-fuzzy-search",
            );
            await execFileAsync(
              "/usr/bin/swiftc",
              [
                "-D",
                "FUZZY_SEARCH_CLI",
                "-parse-as-library",
                "-module-cache-path",
                swiftModuleCachePath,
                cfg.toolPath,
                "-o",
                compiledToolPath,
              ],
              {
                timeout: cfg.timeoutMs,
                maxBuffer: 1024 * 1024,
                encoding: "utf8",
                env: { ...process.env, CLANG_MODULE_CACHE_PATH: swiftModuleCachePath },
              },
            );
            toolCommand = compiledToolPath;
          }
          args.push("search", query, "--root", directory);
          const output = await execFileAsync(toolCommand, args, {
            timeout: cfg.timeoutMs,
            maxBuffer: 64 * 1024 * 1024,
            encoding: "utf8",
          });
          const parsed: unknown = JSON.parse(output.stdout);
          const results = Array.isArray(parsed)
            ? parsed.map(resultFrom).filter((entry): entry is Result => entry !== null)
            : [];
          return {
            content: [],
            details: {
              ok: true,
              result: {
                directory,
                results,
              },
            },
          };
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : String(error);
          api.logger.warn(`fuzzy-search: Swift search failed: ${message}`);
          return {
            content: [],
            details: { ok: false, result: { reason: "search_failed", message } },
          };
        } finally {
          if (temporaryToolDirectory) {
            await fs.rm(temporaryToolDirectory, { recursive: true, force: true });
          }
        }
      },
    });
  },
};

export default plugin;
