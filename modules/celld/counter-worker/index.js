const HTTP_OK = 200;
const CELL_NAME = "onix-celld-lab";

export class Counter {
  constructor(state) {
    this.state = state;
  }

  async fetch() {
    const previous = (await this.state.storage.get("counter")) ?? 0;
    const counter = previous + 1;
    await this.state.storage.put("counter", counter);

    return new Response(JSON.stringify({ counter }), {
      status: HTTP_OK,
      headers: { "content-type": "application/json" },
    });
  }
}

export default {
  async fetch(request, env) {
    const objectId = env.COUNTER.idFromName(CELL_NAME);
    return env.COUNTER.get(objectId).fetch(request);
  },
};
