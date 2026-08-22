type MigrationEntry = {
  version: string;
  local_path: string;
};

type EdgeFunctionEntry = {
  slug: string;
  verify_jwt: boolean;
  source_path: string;
  source_sha256?: string;
  captured_source_sha256?: string;
};

type ExcludedLocalArtifact = {
  path: string;
  reason: string;
};

type DriftManifest = {
  remote_migrations: MigrationEntry[];
  local_unapplied_migrations_at_capture: string[];
  excluded_local_artifacts_at_capture: ExcludedLocalArtifact[];
  remote_edge_functions: EdgeFunctionEntry[];
  remote_tables: {
    count: number;
    names: string[];
    all_rls_enabled: boolean;
    account_deletion_fk_audit: {
      tables_requiring_cascade_migration: string[];
      rows_in_each_table_at_capture: number;
    };
  };
};

const driftRoot = new URL("./", import.meta.url);
const manifestUrl = new URL("remote_state_2026-08-09.json", driftRoot);
const migrationsUrl = new URL("../migrations/", driftRoot);

async function sha256(url: URL): Promise<string> {
  const bytes = await Deno.readFile(url);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function exists(url: URL): Promise<boolean> {
  try {
    await Deno.stat(url);
    return true;
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return false;
    throw error;
  }
}

export async function verifyManifest(): Promise<string[]> {
  const manifest = JSON.parse(
    await Deno.readTextFile(manifestUrl),
  ) as DriftManifest;
  const failures: string[] = [];
  const migrationFiles: string[] = [];

  for await (const entry of Deno.readDir(migrationsUrl)) {
    if (entry.isFile && entry.name.endsWith(".sql")) {
      migrationFiles.push(entry.name);
    }
  }

  const seenVersions = new Set<string>();
  for (const migration of manifest.remote_migrations) {
    if (!/^\d{12,14}$/.test(migration.version)) {
      failures.push(`Invalid migration version: ${migration.version}`);
    }
    if (seenVersions.has(migration.version)) {
      failures.push(`Duplicate remote migration version: ${migration.version}`);
    }
    seenVersions.add(migration.version);

    const matches = migrationFiles.filter((name) =>
      name.startsWith(`${migration.version}_`)
    );
    if (matches.length !== 1) {
      failures.push(
        `Expected one local migration for ${migration.version}; found ${matches.length}`,
      );
    }
    if (!await exists(new URL(migration.local_path, driftRoot))) {
      failures.push(`Missing local migration path: ${migration.local_path}`);
    }
  }

  for (const pendingPath of manifest.local_unapplied_migrations_at_capture) {
    if (!await exists(new URL(pendingPath, driftRoot))) {
      failures.push(`Missing captured local-only migration: ${pendingPath}`);
    }
  }

  for (const artifact of manifest.excluded_local_artifacts_at_capture) {
    if (
      manifest.local_unapplied_migrations_at_capture.includes(artifact.path)
    ) {
      failures.push(
        `Excluded artifact is also listed as a migration: ${artifact.path}`,
      );
    }
    if (!artifact.path.trim() || !artifact.reason.trim()) {
      failures.push("Excluded local artifact requires a path and reason");
    }
  }

  const slugs = new Set<string>();
  for (const fn of manifest.remote_edge_functions) {
    if (slugs.has(fn.slug)) {
      failures.push(`Duplicate Edge Function slug: ${fn.slug}`);
    }
    slugs.add(fn.slug);
    if (!fn.verify_jwt) {
      failures.push(`Edge Function does not verify JWT: ${fn.slug}`);
    }

    const sourceUrl = new URL(fn.source_path, driftRoot);
    if (!await exists(sourceUrl)) {
      failures.push(`Missing Edge Function source evidence: ${fn.source_path}`);
      continue;
    }
    if (fn.source_sha256) {
      const actual = await sha256(sourceUrl);
      if (actual !== fn.source_sha256) {
        failures.push(`Source hash mismatch for ${fn.slug}: ${actual}`);
      }
    }
    if (
      fn.captured_source_sha256 &&
      !/^[0-9a-f]{64}$/.test(fn.captured_source_sha256)
    ) {
      failures.push(`Invalid captured source hash for ${fn.slug}`);
    }
  }

  if (manifest.remote_tables.names.length !== manifest.remote_tables.count) {
    failures.push(
      `Remote table count mismatch: expected ${manifest.remote_tables.count}, ` +
        `listed ${manifest.remote_tables.names.length}`,
    );
  }
  if (
    new Set(manifest.remote_tables.names).size !==
      manifest.remote_tables.names.length
  ) {
    failures.push("Remote table inventory contains duplicate names");
  }
  if (!manifest.remote_tables.all_rls_enabled) {
    failures.push(
      "Manifest does not attest RLS enabled on every inventoried public table",
    );
  }

  const deletionAudit = manifest.remote_tables.account_deletion_fk_audit;
  if (deletionAudit.tables_requiring_cascade_migration.length !== 12) {
    failures.push(
      "Account-deletion FK audit must list the twelve non-cascading tables",
    );
  }
  if (
    new Set(deletionAudit.tables_requiring_cascade_migration).size !==
      deletionAudit.tables_requiring_cascade_migration.length
  ) {
    failures.push("Account-deletion FK audit contains duplicate tables");
  }
  if (deletionAudit.rows_in_each_table_at_capture !== 0) {
    failures.push(
      "Account-deletion cascade migration requires a fresh orphan audit",
    );
  }

  return failures;
}

if (import.meta.main) {
  const failures = await verifyManifest();
  if (failures.length > 0) {
    for (const failure of failures) console.error(failure);
    Deno.exit(1);
  }
  console.log("Supabase drift manifest is internally consistent.");
}
