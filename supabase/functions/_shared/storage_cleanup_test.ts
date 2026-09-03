import { deleteUserStorageObjects } from "./storage_cleanup.ts";

Deno.test("recursively lists nested folders and deletes every file", async () => {
  const requests: Array<{ method: string; body: Record<string, unknown> }> = [];
  const listings = new Map<string, Array<Record<string, unknown>>>([
    ["user-1", [{ name: "backup", id: null, metadata: null }]],
    [
      "user-1/backup",
      [
        { name: "full_backup.json", id: "a", metadata: {} },
        { name: "tasks_backup.json", id: "b", metadata: {} },
      ],
    ],
  ]);

  const result = await deleteUserStorageObjects("user-1", {
    supabaseUrl: "https://example.supabase.co",
    serviceRoleKey: "test-service-role",
    fetcher: (_input, init) => {
      const method = init?.method ?? "GET";
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      requests.push({ method, body });
      if (method === "POST") {
        const prefix = String(body.prefix);
        return Promise.resolve(Response.json(listings.get(prefix) ?? []));
      }
      return Promise.resolve(Response.json([]));
    },
  });

  if (!result) throw new Error("recursive storage cleanup failed");
  const deletion = requests.find((request) => request.method === "DELETE");
  const paths = deletion?.body.prefixes as string[] | undefined;
  if (
    JSON.stringify(paths) !==
      JSON.stringify([
        "user-1/backup/full_backup.json",
        "user-1/backup/tasks_backup.json",
      ])
  ) {
    throw new Error(`unexpected deletion paths: ${JSON.stringify(paths)}`);
  }
});

Deno.test("paginates listings and deletes in bounded batches", async () => {
  const deletedBatches: string[][] = [];
  const result = await deleteUserStorageObjects("user-2", {
    supabaseUrl: "https://example.supabase.co",
    serviceRoleKey: "test-service-role",
    pageSize: 2,
    fetcher: (_input, init) => {
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      if (init?.method === "POST") {
        const offset = Number(body.offset);
        const entries = offset === 0
          ? [
            { name: "one.json", id: "1", metadata: {} },
            { name: "two.json", id: "2", metadata: {} },
          ]
          : offset === 2
          ? [{ name: "three.json", id: "3", metadata: {} }]
          : [];
        return Promise.resolve(Response.json(entries));
      }
      deletedBatches.push(body.prefixes as string[]);
      return Promise.resolve(Response.json([]));
    },
  });

  if (!result) throw new Error("paginated storage cleanup failed");
  if (deletedBatches.length !== 2) {
    throw new Error(`expected 2 delete batches, got ${deletedBatches.length}`);
  }
  if (deletedBatches.flat().length !== 3) {
    throw new Error("not every listed file was deleted");
  }
});

Deno.test("fails closed on malformed listings or delete failure", async () => {
  const malformed = await deleteUserStorageObjects("user-3", {
    supabaseUrl: "https://example.supabase.co",
    serviceRoleKey: "test-service-role",
    fetcher: () => Promise.resolve(Response.json({ not: "a list" })),
  });
  if (malformed) throw new Error("malformed listing must fail closed");

  const deleteFailure = await deleteUserStorageObjects("user-3", {
    supabaseUrl: "https://example.supabase.co",
    serviceRoleKey: "test-service-role",
    fetcher: (_input, init) =>
      Promise.resolve(
        init?.method === "POST"
          ? Response.json([{ name: "backup.json", id: "1", metadata: {} }])
          : new Response("failed", { status: 500 }),
      ),
  });
  if (deleteFailure) throw new Error("delete failure must fail closed");
});
