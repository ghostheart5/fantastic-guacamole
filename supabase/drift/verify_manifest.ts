type BaselineMigration = { version: string; name: string };
type BaselineFunction = { slug: string; verify_jwt: boolean };
type ProductionBaseline = {
  schema_version: number;
  project: { ref: string; name: string; region: string; status: string };
  migrations: BaselineMigration[];
  edge_functions: BaselineFunction[];
};
type BundleFile = { local_path: string; characters: number };
type BundleFunction = BaselineFunction & {
  version: number;
  status: string;
  ezbr_sha256: string;
  files: BundleFile[];
};
type BundleManifest = {
  schema_version: number;
  project_ref: string;
  functions: BundleFunction[];
};
type StatementCapture = {
  project_ref: string;
  migrations: Array<BaselineMigration & { statements: string[] }>;
};

const projectRef = "qpwhuckyirnqtmvhpede";
const forwardMigrations: BaselineMigration[] = [
  {
    version: "20260816203547",
    name: "optimize_owner_policies_and_remove_duplicates",
  },
];
const driftRoot = new URL("./", import.meta.url);
const repositoryRoot = new URL("../../", driftRoot);
const migrationsUrl = new URL("../migrations/", driftRoot);
const configUrl = new URL("../config.toml", driftRoot);

async function readJson<T>(relativePath: string): Promise<T> {
  return JSON.parse(
    await Deno.readTextFile(new URL(relativePath, driftRoot)),
  ) as T;
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

function configVerifyJwt(
  config: string,
  functionName: string,
): boolean | null {
  const escaped = functionName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const section = new RegExp(
    String.raw`\[functions\.${escaped}\]([\s\S]*?)(?=\n\[|$)`,
  ).exec(config)?.[1];
  if (!section) return null;
  const value = /^\s*verify_jwt\s*=\s*(true|false)\s*$/m.exec(section)?.[1];
  return value === "true" ? true : value === "false" ? false : null;
}

export async function verifyManifest(): Promise<string[]> {
  const failures: string[] = [];
  const baseline = await readJson<ProductionBaseline>(
    "../ghostheart5_production_baseline_20260816.json",
  );
  const bundles = await readJson<BundleManifest>(
    "../ghostheart5_edge_function_bundles_20260816.json",
  );
  const statementCapture = await readJson<StatementCapture>(
    "../ghostheart5_live_migration_statements_20260816.json",
  );
  const config = await Deno.readTextFile(configUrl);

  if (
    baseline.project.ref !== projectRef || bundles.project_ref !== projectRef ||
    statementCapture.project_ref !== projectRef
  ) {
    failures.push("Every current Supabase manifest must identify GhostHeart5");
  }
  if (
    baseline.project.name !== "ghostheart5's Project" ||
    baseline.project.region !== "us-west-2" ||
    baseline.project.status !== "ACTIVE_HEALTHY"
  ) failures.push("GhostHeart5 project metadata is inconsistent");

  const migrationFiles = new Set<string>();
  for await (const entry of Deno.readDir(migrationsUrl)) {
    if (entry.isFile && entry.name.endsWith(".sql")) {
      migrationFiles.add(entry.name);
    }
  }
  if (baseline.migrations.length !== 23) {
    failures.push(
      `Expected 23 production migrations; found ${baseline.migrations.length}`,
    );
  }
  if (
    migrationFiles.size !==
      baseline.migrations.length + forwardMigrations.length
  ) {
    failures.push(
      `Expected ${baseline.migrations.length + forwardMigrations.length} ` +
        `tracked migrations; found ${migrationFiles.size}`,
    );
  }
  const migrationVersions = new Set<string>();
  for (const migration of baseline.migrations) {
    if (!/^\d{12,14}$/.test(migration.version)) {
      failures.push(`Invalid migration version: ${migration.version}`);
    }
    if (migrationVersions.has(migration.version)) {
      failures.push(`Duplicate migration version: ${migration.version}`);
    }
    migrationVersions.add(migration.version);
    const expected = `${migration.version}_${migration.name}.sql`;
    if (!migrationFiles.has(expected)) {
      failures.push(`Missing production migration: ${expected}`);
    }
  }
  for (const migration of forwardMigrations) {
    if (migrationVersions.has(migration.version)) {
      failures.push(
        `Duplicate forward migration version: ${migration.version}`,
      );
    }
    migrationVersions.add(migration.version);
    const expected = `${migration.version}_${migration.name}.sql`;
    if (!migrationFiles.has(expected)) {
      failures.push(`Missing forward migration: ${expected}`);
    }
  }

  for (const captured of statementCapture.migrations) {
    const migrationPath = new URL(
      `../migrations/${captured.version}_${captured.name}.sql`,
      driftRoot,
    );
    if (!await exists(migrationPath)) {
      failures.push(`Missing recovered migration: ${captured.version}`);
      continue;
    }
    const source = await Deno.readTextFile(migrationPath);
    if (captured.statements.length === 0) {
      failures.push(
        `Recovered migration has no statements: ${captured.version}`,
      );
    }
    for (const [index, statement] of captured.statements.entries()) {
      if (!source.includes(statement)) {
        failures.push(
          `Recovered statement ${
            index + 1
          } is not exact in ${captured.version}`,
        );
      }
    }
  }

  const baselineBySlug = new Map(
    baseline.edge_functions.map((fn) => [fn.slug, fn]),
  );
  if (baselineBySlug.size !== 10 || bundles.functions.length !== 10) {
    failures.push("Expected exactly ten deployed GhostHeart5 Edge Functions");
  }
  const bundleSlugs = new Set<string>();
  for (const fn of bundles.functions) {
    if (bundleSlugs.has(fn.slug)) {
      failures.push(`Duplicate Edge Function bundle: ${fn.slug}`);
    }
    bundleSlugs.add(fn.slug);
    const baselineFunction = baselineBySlug.get(fn.slug);
    if (!baselineFunction || baselineFunction.verify_jwt !== fn.verify_jwt) {
      failures.push(`Baseline/bundle auth mismatch: ${fn.slug}`);
    }
    if (configVerifyJwt(config, fn.slug) !== fn.verify_jwt) {
      failures.push(`config.toml auth mismatch: ${fn.slug}`);
    }
    if (fn.version < 1 || !/^[0-9a-f]{64}$/.test(fn.ezbr_sha256)) {
      failures.push(`Invalid deployed bundle metadata: ${fn.slug}`);
    }
    for (const file of fn.files) {
      const relative = file.local_path.replace(/^supabase\//, "");
      const fileUrl = new URL(relative, new URL("../", driftRoot));
      if (!await exists(fileUrl)) {
        failures.push(`Missing recovered bundle file: ${file.local_path}`);
        continue;
      }
      const source = await Deno.readTextFile(fileUrl);
      // apply_patch preserves repository text files with one terminal newline;
      // the Management API source strings omit that framing newline.
      const deployedSource = source.endsWith("\n")
        ? source.slice(0, -1)
        : source;
      if (deployedSource.length !== file.characters) {
        failures.push(
          `Recovered source length mismatch: ${file.local_path} ` +
            `(${deployedSource.length} != ${file.characters})`,
        );
      }
    }
  }

  const localEntrypoints = new Set<string>();
  const functionsUrl = new URL("../functions/", driftRoot);
  for await (const entry of Deno.readDir(functionsUrl)) {
    if (
      entry.isDirectory &&
      await exists(new URL(`${entry.name}/index.ts`, functionsUrl))
    ) localEntrypoints.add(entry.name);
  }
  for (const slug of bundleSlugs) {
    if (!localEntrypoints.has(slug)) {
      failures.push(`Missing local entrypoint: ${slug}`);
    }
  }
  for (const slug of localEntrypoints) {
    if (!bundleSlugs.has(slug)) {
      failures.push(`Uncaptured local entrypoint: ${slug}`);
    }
  }

  if (await exists(new URL("supabase/.temp/project-ref", repositoryRoot))) {
    const ignore = await Deno.readTextFile(
      new URL(".gitignore", repositoryRoot),
    );
    if (!ignore.includes("supabase/.temp/")) {
      failures.push("Supabase CLI cache is not ignored");
    }
  }
  return failures;
}

if (import.meta.main) {
  const failures = await verifyManifest();
  if (failures.length > 0) {
    failures.forEach((failure) => console.error(failure));
    Deno.exit(1);
  }
  console.log("GhostHeart5 Supabase preservation manifests are consistent.");
}
