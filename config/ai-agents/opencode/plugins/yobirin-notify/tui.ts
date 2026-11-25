// OpenCodeの許可待ち・質問待ち・長いターンの終了・エラーを、yobirinのopencodeプロファイルで通知する。
// サーバーは端末のpaneとは別のプロセスで常駐するので、WEZTERM_PANEが見える端末側のpluginで通知する。
import { Plugin } from "@opencode/plugin/tui";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { createNotifier } from "./notifier.ts";

const NOTIFY_SH = `${homedir()}/.dotfiles/script/notify/notify.sh`;

export default Plugin.define({
  id: "mjun.yobirin-notify",
  setup(context) {
    const session = context.data.session;
    const notifier = createNotifier(
      {
        session(id) {
          const info = session.get(id);
          return info && { parentID: info.parentID, directory: info.location.directory };
        },
        hasRunningChild(id) {
          return session
            .family(id)
            .some(
              (child) => session.get(child)?.parentID === id && session.status(child) === "running",
            );
        },
        async lastAssistantText(id) {
          try {
            await session.message.sync(id);
          } catch {
            return "";
          }
          const last = session.message
            .list(id)
            ?.findLast((message) => message.type === "assistant");
          return (last?.content ?? [])
            .filter((part) => part.type === "text")
            .map((part) => part.text)
            .join(" ");
        },
        notify(title, body, sessionID) {
          run(NOTIFY_SH, [title, body, sessionID, "opencode"]);
        },
        cancel(sessionID) {
          // 応答待ちのyobirinのプロセスを止めると、通知センターから自分の通知を消して終わる。
          run("pkill", ["-f", `dotfiles-wezterm-${sessionID}`]);
        },
      },
      process.env,
    );
    const stop = context.data.listen(({ details }) => void notifier(details));
    return () => stop();
  },
});

// detachedにすると子プロセスが端末から切り離され、SSH先でnotify.shが/dev/ttyへ書けなくなる。
function run(command: string, args: string[]) {
  spawn(command, args, { stdio: "ignore" }).unref();
}
