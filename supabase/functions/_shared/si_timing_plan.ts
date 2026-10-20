// Timing arithmetic is deliberately independent of a model's prose. A saved
// task start cannot enter either proposed slot without an explicit user source.
export interface UserTimingValue<T> {
  value: T;
  source: "user";
  turnIndex: number;
  quote: string;
}

// A free-text model extraction is not enough to assign a clock value to a
// departure or activity-start role. The person must choose that role in a
// labeled control; otherwise the calculation stays a conditional window.
export interface ExplicitTimingProposal {
  value: string;
  source: "explicit_control";
  control: "departure" | "activity_start";
}

export interface SiTimingInput {
  userTurns: readonly string[];
  proposedDeparture?: ExplicitTimingProposal;
  proposedActivityStart?: ExplicitTimingProposal;
  closing?: UserTimingValue<string>;
  travelMinutes?: UserTimingValue<number>;
  activityMinutes?: UserTimingValue<number>;
}

export interface SiTimingPolicy {
  // Supplied by the server, never by a model or an app record.
  nowMs: number;
  optionalBufferMinutes: number;
}

export type SiTimingResult =
  | { status: "missing"; fields: readonly string[] }
  | { status: "invalid"; reason: string }
  | {
    status: "window";
    closing: string;
    latestDeparture: string;
    optionalDeparture: string;
    optionalBufferMinutes: number;
    optionalDepartureStillPossible: boolean;
    latestDepartureStillPossible: boolean;
    // No user-specified departure or activity start was supplied. The saved
    // task start must not be silently substituted to fill this timeline.
  }
  | {
    status: "calculated";
    departure: string;
    arrival: string;
    activityStart: string;
    finish: string;
    closing: string;
    bufferMinutes: number;
    latestDeparture: string;
    viable: boolean;
    departureStillPossible: boolean;
  };

function cited(
  fact: UserTimingValue<unknown> | undefined,
  turns: readonly string[],
): boolean {
  return fact === undefined ||
    (fact.source === "user" && Number.isInteger(fact.turnIndex) &&
      fact.turnIndex >= 0 && fact.turnIndex < turns.length &&
      fact.quote.trim().length > 0 &&
      turns[fact.turnIndex].includes(fact.quote));
}

function instant(value: string): number | null {
  // The caller must supply an unambiguous date and offset. A bare clock time
  // would silently borrow the server's date or timezone.
  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/
      .test(value)
  ) {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function minutes(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0 && value <= 24 * 60;
}

export function calculateSiTiming(
  input: SiTimingInput,
  policy: SiTimingPolicy,
): SiTimingResult {
  if (
    !Number.isSafeInteger(policy.nowMs) ||
    !Number.isSafeInteger(policy.optionalBufferMinutes) ||
    policy.optionalBufferMinutes < 1 || policy.optionalBufferMinutes > 120
  ) return { status: "invalid", reason: "invalid_server_timing_policy" };
  const facts = [
    input.closing,
    input.travelMinutes,
    input.activityMinutes,
  ];
  if (facts.some((fact) => !cited(fact, input.userTurns))) {
    return { status: "invalid", reason: "unverified_user_source" };
  }
  if (
    (input.proposedDeparture &&
      (input.proposedDeparture.source !== "explicit_control" ||
        input.proposedDeparture.control !== "departure")) ||
    (input.proposedActivityStart &&
      (input.proposedActivityStart.source !== "explicit_control" ||
        input.proposedActivityStart.control !== "activity_start"))
  ) return { status: "invalid", reason: "unverified_timing_role" };
  const missing: string[] = [];
  if (!input.closing) missing.push("closing");
  if (!input.travelMinutes) missing.push("travel_minutes");
  if (!input.activityMinutes) missing.push("activity_minutes");
  if (missing.length) return { status: "missing", fields: missing };

  const travel = input.travelMinutes!.value;
  const activity = input.activityMinutes!.value;
  const closing = instant(input.closing!.value);
  const departure = input.proposedDeparture
    ? instant(input.proposedDeparture.value)
    : null;
  const proposedStart = input.proposedActivityStart
    ? instant(input.proposedActivityStart.value)
    : null;
  if (
    !minutes(travel) || !minutes(activity) || closing === null ||
    (input.proposedDeparture && departure === null) ||
    (input.proposedActivityStart && proposedStart === null)
  ) return { status: "invalid", reason: "invalid_timing_value" };

  const travelMs = travel * 60_000;
  const activityMs = activity * 60_000;
  const latestDeparture = closing - activityMs - travelMs;
  const optionalDeparture = latestDeparture -
    policy.optionalBufferMinutes * 60_000;
  const iso = (time: number) => new Date(time).toISOString();
  if (!input.proposedDeparture && !input.proposedActivityStart) {
    return {
      status: "window",
      closing: iso(closing),
      latestDeparture: iso(latestDeparture),
      optionalDeparture: iso(optionalDeparture),
      optionalBufferMinutes: policy.optionalBufferMinutes,
      optionalDepartureStillPossible: policy.nowMs <= optionalDeparture,
      latestDepartureStillPossible: policy.nowMs <= latestDeparture,
    };
  }
  const actualDeparture = departure ?? proposedStart! - travelMs;
  const arrival = actualDeparture + travelMs;
  if (proposedStart !== null && arrival !== proposedStart) {
    return { status: "invalid", reason: "proposals_conflict" };
  }
  const finish = arrival + activityMs;
  return {
    status: "calculated",
    departure: iso(actualDeparture),
    arrival: iso(arrival),
    activityStart: iso(arrival),
    finish: iso(finish),
    closing: iso(closing),
    bufferMinutes: (closing - finish) / 60_000,
    latestDeparture: iso(latestDeparture),
    viable: finish <= closing,
    departureStillPossible: policy.nowMs <= actualDeparture,
  };
}
