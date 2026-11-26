// OpenCodeのtool hookから、Claude Code・Codexと共有するhookスクリプトをいつ呼び、結果をeventへどう反映するかを決める。
// OpenCodeにも外部コマンドにも依存させず、必要な操作はPortsで受け取る。

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

export function createHooks(ports: Ports): Hooks {
  throw new Error("skeleton: not implemented");
}
