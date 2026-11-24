import type { Register } from "claude-code";
import { renderBodies } from "./render.js";

export const register: Register = (on) => {
  on("ui.render", { component: "AgentRow" }, async ($, e, next) => {
    const { rowIds } = e.props;
    // 全行の列幅を揃えるため、表示中のほかのagentの情報も要る。この行は最新のpropsを使う
    const agents = (await $.agent.list())
      .filter((agent) => rowIds.includes(agent.id))
      .map((agent) => (agent.id === e.props.id ? e.props : agent));
    const home = (await $.env.get("HOME")) ?? "";
    const body = renderBodies(agents, await $.clock.now(), home).get(e.props.id);
    // modelの無い行は描き換えず、本体の標準の行に任せる
    if (body === undefined) return next(e);
    return next({ ...e, props: { ...e.props, body } });
  });
};
