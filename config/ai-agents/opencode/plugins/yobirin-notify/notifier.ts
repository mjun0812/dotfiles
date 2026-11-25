// OpenCodeのイベントから、どの場面で何を通知するかを決める。
// OpenCodeにも外部コマンドにも依存させず、必要な操作はPortsで受け取る。

export interface SessionInfo {
  parentID?: string;
  directory?: string;
}

export interface Ports {
  // OpenCodeが持っているセッションの情報。まだ無ければundefined
  session(id: string): SessionInfo | undefined;
  // 親のセッションに、実行中の子セッションがあるか
  hasRunningChild(id: string): boolean;
  // セッションの最後の応答の本文。取れなければ空文字列
  lastAssistantText(id: string): Promise<string>;
  notify(title: string, body: string, sessionID: string): void;
  cancel(sessionID: string): void;
}

// OpenCodeのイベント (details)。使うのは type、created、data だけ
export interface Event {
  type: string;
  created: number;
  data: any;
}

// 利用者の入力からこのミリ秒数未満で終わったターンは通知しない。
const MIN_ELAPSED_MS = 300_000;
const BODY_MAX_CHARS = 100;

export function createNotifier(
  ports: Ports,
  env: { MJUN_ORCH_WORKER?: string },
): (event: Event) => Promise<void> {
  // mjun-orchestrateのworkerの状態はorchestratorが受け取ってユーザーへ伝えるので、通知しない。
  if (env.MJUN_ORCH_WORKER) return async () => {};

  // 子セッションの実行が始まった時点では、ports.sessionにまだparentIDが入っていないことがある。
  // session.createdのparentIDを覚えておき、それで子セッションを見分ける。
  const parents = new Map<string, string>();
  const turnStartedAt = new Map<string, number>();

  const parentOf = (id: string) => parents.get(id) ?? ports.session(id)?.parentID;

  // 通知の取り消しとpaneへ戻る動作はセッションIDで束ねているので、子セッションの通知も親のIDで出す。
  const rootOf = (id: string) => {
    let root = id;
    for (let parent = parentOf(root); parent; parent = parentOf(root)) root = parent;
    return root;
  };

  const notify = (emoji: string, body: string, sessionID: string) => {
    const repo = ports.session(sessionID)?.directory?.split("/").pop() || "unknown";
    // OpenCodeのセッションIDは先頭が作成時刻に近い値なので、見分けられる末尾を出す。
    ports.notify(`${emoji} OpenCode [${repo}] #${sessionID.slice(-8)}`, sanitize(body), sessionID);
  };

  return async ({ type, created, data }) => {
    switch (type) {
      case "session.created":
        if (data.parentID) parents.set(data.sessionID, data.parentID);
        return;
      case "session.inbox.enqueued":
        // サブエージェントの結果が親へ届く入力 (synthetic) は、利用者から見たターンの途中なので数えない。
        if (data.item.type !== "user" || parentOf(data.sessionID)) return;
        turnStartedAt.set(data.sessionID, created);
        ports.cancel(data.sessionID);
        return;
      case "permission.asked":
        notify(
          "🔐",
          `${data.action}: ${data.resources.join(" ")} の許可を待っています`,
          rootOf(data.sessionID),
        );
        return;
      case "form.created": {
        const { form } = data;
        const field = form.fields?.[0];
        notify("❓", field?.description || field?.title || form.title, rootOf(form.sessionID));
        return;
      }
      case "session.execution.succeeded": {
        const id = data.sessionID;
        // 子の実行中に親の実行が一度終わることがある。子の結果を受けた後の終了まで開始時刻を残す。
        if (parentOf(id) || ports.hasRunningChild(id)) return;
        const startedAt = turnStartedAt.get(id);
        turnStartedAt.delete(id);
        // 開始時刻が無いセッション (pluginの読み込みより前に始まったターンなど) は通知する。
        if (startedAt !== undefined && created - startedAt < MIN_ELAPSED_MS) return;
        notify("✅", (await ports.lastAssistantText(id)).trim() || "次の指示を待っています", id);
        return;
      }
      case "session.execution.failed":
        if (parentOf(data.sessionID)) return;
        turnStartedAt.delete(data.sessionID);
        notify("⚠️", "応答がエラーで打ち切られました", data.sessionID);
        return;
      case "session.execution.interrupted":
        turnStartedAt.delete(data.sessionID);
        return;
    }
  };
}

// サロゲートペアを割らないよう、コードポイント単位で切る。
function sanitize(text: string): string {
  return Array.from(text.replace(/\s+/g, " ").trim()).slice(0, BODY_MAX_CHARS).join("");
}
