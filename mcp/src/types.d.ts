declare module "multicast-dns" {
  interface MDNSInstance {
    on(event: "response", callback: (response: any) => void): void;
    query(query: { questions: Array<{ name: string; type: string }> }): void;
    destroy(): void;
  }
  function mdns(): MDNSInstance;
  export default mdns;
}

declare module "qrcode-terminal" {
  function generate(text: string, options?: { small?: boolean }, callback?: (qr: string) => void): void;
  export default { generate };
}

declare module "@iarna/toml" {
  export type JsonMap = Record<string, unknown>;
  export function parse(input: string): JsonMap;
  export function stringify(input: JsonMap): string;
}
