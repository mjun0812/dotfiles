import type { AgentInfo } from "claude-code";

export type RowSource = Pick<
  AgentInfo,
  | "id"
  | "name"
  | "kind"
  | "description"
  | "label"
  | "taskStatus"
  | "model"
  | "effort"
  | "contextWindowSize"
  | "tokenCount"
  | "cwd"
  | "startTime"
>;

const BRAILLE = " ⣀⣄⣤⣦⣶⣷⣿";
const BAR_WIDTH = 6;
const R = "\x1b[0m";
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const SEP = ` ${DIM}│${R} `;
const ANSI = /\x1b\[[0-9;]*m/g;
const DESC_MAX_WIDTH = 40;

// 表示幅2で数える主な範囲: ハングル字母、CJKの各ブロック (かな、Yiを含む)、ハングル音節、CJK互換、全角形、絵文字、CJK拡張
const WIDE =
  /[\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\uf900-\ufaff\uff00-\uff60\uffe0-\uffe6\u{1f300}-\u{1f64f}\u{1f900}-\u{1f9ff}\u{20000}-\u{3fffd}]/u;

const STATUS_GLYPHS: Partial<Record<AgentInfo["taskStatus"], string>> = {
  running: `${CYAN}●${R}`,
  completed: `${GREEN}✓${R}`,
  failed: `${RED}✗${R}`,
};

// 列ごとの区切り。全agentの列幅を揃えるため、まずセルを集めてから描画する
const JOINERS = ["", "  ", SEP, SEP, SEP];

/**
 * 各agentの行の本文を作る。modelの無いagentは含めない (本体の標準の行に任せる).
 */
export function renderBodies(agents: RowSource[], now: number, home: string): Map<string, string> {
  const rows: { id: string; cells: string[] }[] = [];
  for (const agent of agents) {
    const { model } = agent;
    if (!model) continue;
    // effortはlevel文字列か数値のトークン予算で、未指定なら項目自体が無い
    const effort = typeof agent.effort === "number" ? humanizeTokens(agent.effort) : agent.effort;
    const modelLabel = effort ? `${shorten(model)} ${effort}` : shorten(model);
    const head = `${STATUS_GLYPHS[agent.taskStatus] ?? " "} ${agent.name || agent.kind} ${DIM}[${modelLabel}]${R}`;
    const description = truncate(agent.description || agent.label || "", DESC_MAX_WIDTH);

    const window = agent.contextWindowSize;
    const ctx = window ? formatContext((agent.tokenCount / window) * 100) : "";
    const cwd = agent.cwd ? `${DIM}${R} ${shortPath(agent.cwd, home)}` : "";

    const rightParts: string[] = [];
    if (agent.startTime) {
      const secs = Math.max(Math.floor((now - agent.startTime) / 1000), 0);
      rightParts.push(secs >= 60 ? `${Math.floor(secs / 60)}m ${secs % 60}s` : `${secs}s`);
    }
    if (agent.tokenCount) rightParts.push(`${humanizeTokens(agent.tokenCount)} tokens`);
    const right = rightParts.length ? `${DIM}${rightParts.join(" · ")}${R}` : "";

    rows.push({ id: agent.id, cells: [head, description, ctx, cwd, right] });
  }

  const widths = JOINERS.map((_, i) =>
    Math.max(0, ...rows.map(({ cells }) => displayWidth(cells[i] ?? ""))),
  );
  return new Map(
    rows.map(({ id, cells }) => {
      const line = cells
        .map((cell, i) => {
          const width = widths[i] ?? 0;
          if (!width) return "";
          // セルが無い行は区切りごと空白にして、後続の列位置を保つ
          const joiner = JOINERS[i] ?? "";
          const lead = cell ? joiner : " ".repeat(displayWidth(joiner));
          return lead + cell + " ".repeat(width - displayWidth(cell));
        })
        .join("");
      return [id, line.trimEnd()];
    }),
  );
}

function formatContext(pct: number): string {
  return `${DIM}ctx${R} ${gradient(pct)}${brailleBar(pct)}${R} ${Math.round(pct)}%`;
}

function gradient(pct: number): string {
  if (pct < 50) return `\x1b[38;2;${Math.trunc(pct * 5.1)};200;80m`;
  return `\x1b[38;2;255;${Math.max(Math.trunc(200 - (pct - 50) * 4), 0)};60m`;
}

function brailleBar(pct: number): string {
  const level = Math.min(Math.max(pct, 0), 100) / 100;
  let bar = "";
  for (let i = 0; i < BAR_WIDTH; i++) {
    const segStart = i / BAR_WIDTH;
    const segEnd = (i + 1) / BAR_WIDTH;
    if (level >= segEnd) bar += BRAILLE.charAt(7);
    else if (level <= segStart) bar += BRAILLE.charAt(0);
    else {
      const frac = (level - segStart) / (segEnd - segStart);
      bar += BRAILLE.charAt(Math.min(Math.trunc(frac * 7), 7));
    }
  }
  return bar;
}

function shortPath(path: string, home: string, maxLen = 30): string {
  if (path === home) return "~";
  const full = home && path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path;
  if ([...full].length <= maxLen) return full;
  const parts = full.split("/");
  if (parts.length <= 2) return full.slice(full.lastIndexOf("/") + 1) || full;
  const tail = parts.at(-1);
  const shortened = [
    parts[0],
    ...parts
      .slice(1, -1)
      .filter(Boolean)
      .map((p) => [...p][0]),
    tail,
  ].join("/");
  if ([...shortened].length <= maxLen) return shortened;
  return tail || full;
}

/** モデルIDを表示用の短い名前にする (例: claude-haiku-4-5-20251001 -> haiku-4-5, claude-opus-5-5[1m] -> opus-5-5[1m]). */
function shorten(modelId: string): string {
  const m = /^claude-([a-z]+(?:-\d+)*?)(?:-\d{8})?(\[\w+\])?$/.exec(modelId);
  return m ? `${m[1]}${m[2] ?? ""}` : modelId;
}

/** ANSIエスケープを除き、全角文字を2桁として数えた表示幅. */
function displayWidth(s: string): number {
  let width = 0;
  for (const c of s.replace(ANSI, "")) width += WIDE.test(c) ? 2 : 1;
  return width;
}

/** 表示幅がmaxWidthを超える文字列を切り詰め、末尾に…を付ける. */
function truncate(s: string, maxWidth: number): string {
  if (displayWidth(s) <= maxWidth) return s;
  let out = "";
  let width = 0;
  for (const c of s) {
    width += displayWidth(c);
    if (width > maxWidth - 1) break;
    out += c;
  }
  return `${out}…`;
}

/** トークン数を短い表記にする (例: 12345 -> 12.3k). */
function humanizeTokens(count: number): string {
  if (count < 1000) return String(count);
  return `${(count / 1000).toFixed(1)}k`;
}
