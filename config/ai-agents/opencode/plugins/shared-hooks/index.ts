// Claude Code・Codexと共有するhookスクリプト (config/ai-agents/hooks/) を、OpenCodeのtool hookから呼ぶ。
// OpenCodeには設定ファイルにコマンドを書く種類のhookが無いので、サーバー側のpluginがその役目を持つ。
import { Plugin } from "@opencode/plugin";
import { homedir } from "node:os";
import { createHooks, type ScriptResult } from "./hooks.ts";

const HOOKS_DIR = `${homedir()}/.dotfiles/config/ai-agents/hooks`;

export default Plugin.define({
  id: "mjun.shared-hooks",
  async setup(ctx) {
    const hooks = createHooks({
      run: (script, payload, timeoutMs) => run(`${HOOKS_DIR}/${script}`, payload, timeoutMs),
      directory: async (sessionID) => (await ctx.session.get({ sessionID })).location.directory,
      putInstruction: (sessionID, key, value) =>
        ctx.session.instructions.entry.put({ sessionID, key, value }),
    });
    await ctx.tool.hook("execute.before", (event) => hooks.before(event));
    await ctx.tool.hook("execute.after", (event) => hooks.after(event));
  },
});

function run(path: string, payload: unknown, timeoutMs: number): Promise<ScriptResult> {
  throw new Error("skeleton: not implemented");
}
