import {
  calculateSiTiming,
  type ExplicitTimingProposal,
  type UserTimingValue,
} from "./si_timing_plan.ts";

function user<T>(value: T, quote: string): UserTimingValue<T> {
  return { value, source: "user", turnIndex: 0, quote };
}

function proposal(
  value: string,
  control: ExplicitTimingProposal["control"],
): ExplicitTimingProposal {
  return { value, source: "explicit_control", control };
}

const policy = {
  nowMs: Date.parse("2026-09-22T12:00:00-05:00"),
  optionalBufferMinutes: 15,
};

Deno.test("a saved list start cannot become departure or shopping start", () => {
  const result = calculateSiTiming({
    userTurns: [
      "Store closes at 8; travel is 15 minutes and shopping takes 30 minutes.",
    ],
    closing: user("2026-09-22T20:00:00-05:00", "8"),
    travelMinutes: user(15, "15 minutes"),
    activityMinutes: user(30, "30 minutes"),
  }, policy);
  if (
    result.status !== "window" ||
    result.latestDeparture !== "2026-09-23T00:15:00.000Z" ||
    result.optionalDeparture !== "2026-09-23T00:00:00.000Z" ||
    !result.optionalDepartureStillPossible ||
    "departure" in result
  ) {
    throw new Error(
      "a recorded 7:13 grocery-list task must not supply departure; only the latest conditional window is known",
    );
  }
});

Deno.test("explicit shopping start produces a distinct earlier departure", () => {
  const result = calculateSiTiming({
    userTurns: [
      "Start shopping at 7:13, store closes at 8, travel 15 minutes, shopping 30 minutes.",
    ],
    proposedActivityStart: proposal(
      "2026-09-22T19:13:00-05:00",
      "activity_start",
    ),
    closing: user("2026-09-22T20:00:00-05:00", "store closes at 8"),
    travelMinutes: user(15, "travel 15 minutes"),
    activityMinutes: user(30, "shopping 30 minutes"),
  }, policy);
  if (
    result.status !== "calculated" ||
    result.departure !== "2026-09-22T23:58:00.000Z" ||
    result.activityStart !== "2026-09-23T00:13:00.000Z" ||
    result.finish !== "2026-09-23T00:43:00.000Z" ||
    result.bufferMinutes !== 17 || !result.viable
  ) {
    throw new Error(`grocery timeline incorrect: ${JSON.stringify(result)}`);
  }
});

Deno.test("source and conflicting proposed times fail closed", () => {
  const turns = [
    "Leave at 7:13, shop at 7:13, travel 15 minutes, shop for 30 minutes, closes at 8.",
  ];
  const input = {
    userTurns: turns,
    proposedDeparture: proposal("2026-09-22T19:13:00-05:00", "departure"),
    proposedActivityStart: proposal(
      "2026-09-22T19:13:00-05:00",
      "activity_start",
    ),
    closing: user("2026-09-22T20:00:00-05:00", "closes at 8"),
    travelMinutes: user(15, "travel 15 minutes"),
    activityMinutes: user(30, "30 minutes"),
  };
  const conflict = calculateSiTiming(input, policy);
  if (
    conflict.status !== "invalid" || conflict.reason !== "proposals_conflict"
  ) {
    throw new Error("inconsistent proposed start and departure were accepted");
  }
  const fabricated = calculateSiTiming({
    ...input,
    proposedDeparture: {
      ...input.proposedDeparture,
      source: "user" as "explicit_control",
    },
  }, policy);
  if (
    fabricated.status !== "invalid" ||
    fabricated.reason !== "unverified_timing_role"
  ) {
    throw new Error("a model-extracted departure role was accepted");
  }
});

Deno.test("a quoted task start is not an explicit departure control", () => {
  const result = calculateSiTiming({
    userTurns: [
      "Task starts at 7:13 PM. Store closes at 8 PM. Travel 15 minutes. Shopping 30 minutes.",
    ],
    proposedDeparture: {
      value: "2026-09-22T19:13:00-05:00",
      source: "user" as "explicit_control",
      control: "departure",
    },
    closing: user("2026-09-22T20:00:00-05:00", "Store closes at 8 PM"),
    travelMinutes: user(15, "Travel 15 minutes"),
    activityMinutes: user(30, "Shopping 30 minutes"),
  }, policy);
  if (
    result.status !== "invalid" || result.reason !== "unverified_timing_role"
  ) {
    throw new Error("the exact Moto ambiguity was accepted as departure");
  }
});

Deno.test("an optional cushion is marked unavailable once its departure passes", () => {
  const input = {
    userTurns: [
      "Store closes at 8 PM; travel takes 15 minutes and shopping takes 30 minutes.",
    ],
    closing: user("2026-09-22T20:00:00-05:00", "closes at 8 PM"),
    travelMinutes: user(15, "15 minutes"),
    activityMinutes: user(30, "30 minutes"),
  };
  const afterCushion = calculateSiTiming(input, {
    ...policy,
    nowMs: Date.parse("2026-09-22T19:05:00-05:00"),
  });
  if (
    afterCushion.status !== "window" ||
    afterCushion.optionalDepartureStillPossible ||
    !afterCushion.latestDepartureStillPossible
  ) throw new Error("past cushion option was presented as still possible");

  const afterDeadline = calculateSiTiming(input, {
    ...policy,
    nowMs: Date.parse("2026-09-22T19:16:00-05:00"),
  });
  if (
    afterDeadline.status !== "window" ||
    afterDeadline.latestDepartureStillPossible
  ) throw new Error("past latest departure was presented as still possible");
});
