export interface StorageCleanupOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
  bucket?: string;
  pageSize?: number;
  fetcher?: typeof fetch;
}

interface ListedObject {
  id?: unknown;
  metadata?: unknown;
  name?: unknown;
}

const DEFAULT_BUCKET = "chronospark-sync";
const MAX_OBJECTS = 200_000;

export async function deleteUserStorageObjects(
  userId: string,
  options: StorageCleanupOptions,
): Promise<boolean> {
  const {
    supabaseUrl,
    serviceRoleKey,
    bucket = DEFAULT_BUCKET,
    pageSize = 1000,
    fetcher = fetch,
  } = options;
  if (
    !supabaseUrl || !serviceRoleKey || !isSafePathSegment(userId) ||
    !isSafePathSegment(bucket) || pageSize < 1 || pageSize > 1000
  ) {
    return false;
  }

  const serviceHeaders = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
  };
  const listUrl = `${supabaseUrl}/storage/v1/object/list/${bucket}`;
  const folders: string[] = [userId];
  const visitedFolders = new Set<string>();
  const filePaths: string[] = [];

  while (folders.length > 0) {
    const folder = folders.shift()!;
    if (visitedFolders.has(folder)) continue;
    visitedFolders.add(folder);

    let offset = 0;
    while (true) {
      const response = await fetcher(listUrl, {
        method: "POST",
        headers: serviceHeaders,
        body: JSON.stringify({ prefix: folder, limit: pageSize, offset }),
      });
      if (!response.ok) return false;

      let entries: unknown;
      try {
        entries = await response.json();
      } catch {
        return false;
      }
      if (!Array.isArray(entries)) return false;

      for (const rawEntry of entries) {
        if (!isListedObject(rawEntry) || !isSafePathSegment(rawEntry.name)) {
          return false;
        }
        const path = `${folder}/${rawEntry.name}`;
        if (isFolder(rawEntry)) {
          if (!visitedFolders.has(path)) folders.push(path);
        } else {
          filePaths.push(path);
          if (filePaths.length > MAX_OBJECTS) return false;
        }
      }

      if (entries.length < pageSize) break;
      offset += entries.length;
    }
  }

  const deleteUrl = `${supabaseUrl}/storage/v1/object/${bucket}`;
  for (let offset = 0; offset < filePaths.length; offset += pageSize) {
    const prefixes = filePaths.slice(offset, offset + pageSize);
    const response = await fetcher(deleteUrl, {
      method: "DELETE",
      headers: serviceHeaders,
      body: JSON.stringify({ prefixes }),
    });
    if (!response.ok) return false;
  }
  return true;
}

function isListedObject(value: unknown): value is ListedObject {
  return typeof value === "object" && value !== null;
}

function isFolder(value: ListedObject): boolean {
  return value.id == null && value.metadata == null;
}

function isSafePathSegment(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value !== "." &&
    value !== ".." && !value.includes("/") && !value.includes("\\");
}
