// OpenCodeのtool hookから、Claude Code・Codexと共有するhookスクリプトをいつ呼び、結果をeventへどう反映するかを決める。
// OpenCodeにも外部コマンドにも依存させず、必要な操作はPortsで受け取る。
import { createHash } from "node:crypto";
import { resolve } from "node:path";

export interface ScriptResult {
  code: number;
  stdout: string;
  stderr: string;
}

export interface Ports {
  // config/ai-agents/hooks/ のscriptを、payloadのJSONをstdinへ渡して実行する。起動できないときと時間切れは例外にする
  run(script: string, payload: unknown, timeoutMs: number): Promise<ScriptResult>;
  // sessionのdirectory
  directory(sessionID: string): Promise<string>;
  // sessionの指示へ、keyを付けた文を加える
  putInstruction(sessionID: string, key: string, value: string): Promise<void>;
}

// OpenCodeのtool hookのevent。使う項目だけ
export interface BeforeEvent {
  tool: string;
  sessionID: string;
  id: string;
  input: any;
}

export interface AfterEvent extends BeforeEvent {
  status: "completed" | "error";
  result?: { content?: string | Array<{ type: string; text?: string }>; [key: string]: unknown };
}

export interface Hooks {
  // コマンドを拒否するときだけ例外を投げる
  before(event: BeforeEvent): Promise<void>;
  after(event: AfterEvent): Promise<void>;
}

// scriptがstdoutのJSONで返すhookSpecificOutputのうち、読む項目
interface Decision {
  permissionDecision?: string;
  permissionDecisionReason?: string;
  updatedInput?: { command?: string };
  additionalContext?: string;
}

const EDIT_TOOLS = new Set(["edit", "write", "patch"]);

export function createHooks(ports: Ports): Hooks {
  // 書き換えの知らせは、書き換えたコマンドの結果と一緒に届ける。beforeとafterは呼び出しIDで対応づける
  const notices = new Map<string, string>();

  // scriptが失敗したときは、検査を飛ばしてtoolを止めない
  const call = async (script: string, payload: unknown, timeoutMs: number) => {
    try {
      return await ports.run(script, payload, timeoutMs);
    } catch {
      return undefined;
    }
  };

  const decide = async (
    script: string,
    payload: unknown,
    timeoutMs: number,
  ): Promise<Decision | undefined> => {
    const result = await call(script, payload, timeoutMs);
    if (result?.code !== 0 || !result.stdout.trim()) return undefined;
    try {
      return JSON.parse(result.stdout).hookSpecificOutput;
    } catch {
      return undefined;
    }
  };

  return {
    async before(event) {
      if (event.tool !== "shell") return;
      const directory = await ports.directory(event.sessionID);
      const cwd = event.input.workdir ? resolve(directory, event.input.workdir) : directory;
      const payload = (command: string) => ({
        session_id: event.sessionID,
        cwd,
        hook_event_name: "PreToolUse",
        tool_name: "Bash",
        tool_input: { command },
      });

      const guard = await decide("shell-path-guard-hook.sh", payload(event.input.command), 10_000);
      if (guard?.permissionDecision === "deny") throw new Error(guard.permissionDecisionReason);
      const command = guard?.updatedInput?.command ?? event.input.command;

      const body = await decide("gh-body-hook.sh", payload(command), 45_000);
      if (body?.permissionDecision === "deny") throw new Error(body.permissionDecisionReason);

      if (command === event.input.command) return;
      event.input.command = command;
      if (guard?.additionalContext) notices.set(event.id, guard.additionalContext);
    },

    async after(event) {
      if (event.tool === "shell") {
        const notice = notices.get(event.id);
        notices.delete(event.id);
        if (notice && event.status === "completed") append(event, notice);
        return;
      }
      if (!EDIT_TOOLS.has(event.tool) || event.status !== "completed") return;

      const base = { session_id: event.sessionID, cwd: await ports.directory(event.sessionID) };
      // edited-files.shは、file_pathかpatch本文 (command) のどちらかから編集したファイルを読む
      const patch: string | undefined = event.tool === "patch" ? event.input.patchText : undefined;

      const report = await call(
        "report-hook.sh",
        {
          ...base,
          hook_event_name: "PostToolUse",
          tool_input: patch === undefined ? { file_path: event.input.path } : { command: patch },
        },
        30_000,
      );
      if (report?.code === 2) append(event, report.stderr);

      // codex-rules-hook.shはpatchの見出しからパスを読むので、edit・writeも見出しの形で渡す
      const rules = await decide(
        "codex-rules-hook.sh",
        {
          ...base,
          hook_event_name: "PreToolUse",
          tool_input: { command: patch ?? `*** Update File: ${event.input.path}` },
        },
        10_000,
      );
      if (!rules?.additionalContext) return;
      // 本文から決めたkeyなら、scriptの記録が消えて同じ本文が返っても、指示エントリが増えない
      const key = `rules-${createHash("sha256").update(rules.additionalContext).digest("hex").slice(0, 12)}`;
      try {
        await ports.putInstruction(event.sessionID, key, rules.additionalContext);
      } catch {
        // 指示へ加えられなくても、編集は済んでいるので止めない
      }
    },
  };
}

function append(event: AfterEvent, text: string) {
  const content = event.result?.content;
  event.result = {
    ...event.result,
    content:
      typeof content === "string" ? content + text : [...(content ?? []), { type: "text", text }],
  };
}
