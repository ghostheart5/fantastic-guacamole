import { calculateSiTiming } from "./si_timing_plan.ts";
import { renderSiTimingReply } from "./si_timing_reply.ts";

const userTurns = [
  "Does this task conflict with an 8 PM store closing? Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM.",
];
const facts = {
  userTurns,
  closing: {
    value: "2026-09-23T20:00:00-05:00",
    source: "user" as const,
    turnIndex: 0,
    quote: "8 PM store closing",
  },
  travelMinutes: {
    value: 15,
    source: "user" as const,
    turnIndex: 0,
    quote: "Travel 15 minutes",
  },
  activityMinutes: {
    value: 30,
    source: "user" as const,
    turnIndex: 0,
    quote: "Shopping 30 minutes",
  },
};
const policy = {
  nowMs: Date.parse("2026-09-23T12:00:00-05:00"),
  optionalBufferMinutes: 15,
};

Deno.test("SI gives a conditional human answer without a false task conflict", () => {
  const result = calculateSiTiming(facts, policy);
  const reply = renderSiTimingReply(result, {
    language: "en",
    timeZoneId: "America/Chicago",
    travelMinutes: 15,
    activityMinutes: 30,
    recordedTaskStart: "7:13 PM",
  });
  if (
    !reply.includes("does not establish when you leave") ||
    !reply.includes("If that closing is on the saved task's date") ||
    !reply.includes("7:15 PM") ||
    !reply.includes("7:00 PM") ||
    !reply.includes("optional 15-minute cushion") ||
    reply.includes("there is a conflict") ||
    reply.includes("7:13 PM departure")
  ) throw new Error(`SI conditional answer regressed: ${reply}`);
});

Deno.test("Spanish and already-passed options do not recommend impossible times", () => {
  const result = calculateSiTiming(facts, {
    ...policy,
    nowMs: Date.parse("2026-09-23T19:16:00-05:00"),
  });
  const reply = renderSiTimingReply(result, {
    language: "es",
    timeZoneId: "America/Chicago",
    travelMinutes: 15,
    activityMinutes: 30,
    recordedTaskStart: "7:13 p. m.",
  });
  if (
    !reply.includes("ya pasó") ||
    !reply.includes("Si ese cierre es el mismo día de la tarea guardada") ||
    !reply.includes("7:15 p. m.") ||
    reply.includes("apunta a salir")
  ) throw new Error(`past Spanish option was recommended: ${reply}`);
});
