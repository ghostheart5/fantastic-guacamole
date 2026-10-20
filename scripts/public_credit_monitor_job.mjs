// Read-only billing monitor and an explicitly synthetic notification drill.
import { appendFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import {
  classifyPublicCreditResolutionHealth,
  readPublicCreditResolutionHealth,
} from './check_public_credit_resolutions.mjs';

export async function runPublicCreditMonitor(mode, env = process.env, request = fetch) {
  if (!['check', 'alert-drill'].includes(mode)) {
    throw new Error('Expected check or alert-drill');
  }
  const drill = mode === 'alert-drill';
  try {
    const health = drill ? classifyPublicCreditResolutionHealth({
      awaiting: 1, awaitingOverOneHour: 1, awaitingOverOneDay: 0,
      oldestAwaitingAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      refunded: 0, fulfilled: 0,
    }) : await readPublicCreditResolutionHealth(env, request);
    return {
      schemaVersion: 1, evidenceKind: drill ? 'synthetic-alert-drill' : 'live-aggregate-read',
      observedAt: new Date().toISOString(), ...health,
      exitCode: ['action_required', 'critical'].includes(health.status) ? 2 : 0,
    };
  } catch {
    // Never forward exception text: transports may include credentials or bodies.
    return {
      schemaVersion: 1, evidenceKind: 'live-aggregate-read',
      observedAt: new Date().toISOString(), status: 'unknown', exitCode: 1,
    };
  }
}

export function monitorSummary(result) {
  const drill = result.evidenceKind === 'synthetic-alert-drill';
  return [
    `## Axiomara billing ${drill ? 'ALERT DRILL' : 'monitor'}`,
    '',
    drill ? '**Synthetic drill. No customer payment, database write or refund occurred.**' :
      'Read-only aggregate check; no order, account or purchase-token identifiers are included.',
    '',
    `Status: **${result.status}**`,
    ...(result.status === 'unknown' ? [
      'The queue could not be verified. Do not interpret this as an empty queue.',
    ] : [
      `Awaiting: ${result.awaiting}; over one hour: ${result.awaitingOverOneHour}; over one day: ${result.awaitingOverOneDay}.`,
    ]),
    '',
    result.exitCode === 0 ? 'No overdue payment was detected by this check.' :
      'Billing owner: inspect the restricted queue/provider state, preserve the one-time refund claim, and keep new public sales closed until the remedy is verified. Never retry an uncertain refund blindly.',
    '',
    drill ? 'Delivery passes only when the intended recipient receives the email for this exact run. This intentional job failure is not a production incident.' :
      'A successful run is a point-in-time check, not proof that scheduled monitoring or email delivery is active.',
    '',
  ].join('\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = process.argv.slice(2);
    if (args.length !== 1) throw new Error('Invalid monitor invocation');
    const result = await runPublicCreditMonitor(args[0]);
    console.log(JSON.stringify(result));
    if (process.env.GITHUB_STEP_SUMMARY) {
      await appendFile(process.env.GITHUB_STEP_SUMMARY, monitorSummary(result));
    }
    if (result.exitCode) {
      console.error(result.evidenceKind === 'synthetic-alert-drill' ?
        '::error title=Axiomara billing ALERT DRILL::Intentional synthetic failure; verify delivery of this exact run to the configured billing owner. No payment or refund occurred.' :
        '::error title=Axiomara billing needs attention::Inspect the run summary and restricted payment queue. Public sales must remain closed if recovery cannot be verified.');
    }
    process.exitCode = result.exitCode;
  } catch {
    console.error('Axiomara billing monitor failed before producing trustworthy evidence.');
    process.exitCode = 1;
  }
}
