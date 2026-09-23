import type { SiTimingInput, UserTimingValue } from "./si_timing_plan.ts";

// The model selects short passages, not clock or duration values. The server
// reads those values from the cited user text and rejects ambiguous passages.
export const SI_TIMING_OUTPUT_CONFIG = {
  format: {
    type: "json_schema",
    schema: {
      type: "object",
      properties: {
        closingQuote: { type: "string" },
        travelQuote: { type: "string" },
        activityQuote: { type: "string" },
      },
      required: ["closingQuote", "travelQuote", "activityQuote"],
      additionalProperties: false,
    },
  },
} as const;

export const SI_TIMING_EXTRACTION_INSTRUCTION =
  "For this timing question, output only JSON matching the schema. " +
  "Select the shortest exact passages from the person's current question or " +
  "scenario that state a store closing clock time, a travel duration, and an " +
  "activity or shopping duration. Use an empty string when absent or unclear. " +
  "Do not copy a saved task's scheduled start into any of these fields. " +
  "Do not infer a departure or shopping start, and do not answer in prose.";

export interface SiTimingExtractedFacts {
  closing: UserTimingValue<number>;
  travelMinutes: UserTimingValue<number>;
  activityMinutes: UserTimingValue<number>;
}

export interface SiTimingRequest {
  userTurns: readonly string[];
  taskDay: string | null;
  taskTimeZoneId: string | null;
  recordedTaskStart: string | null;
  language: "en" | "es";
}

export function siTimingRequest(
  context: unknown,
  prompt: string,
): SiTimingRequest | null {
  if (!context || typeof context !== "object" || Array.isArray(context)) {
    return null;
  }
  const record = context as Record<string, unknown>;
  if (record.surface !== "si" || record.mode !== "findConflict") {
    return null;
  }
  const scenario = typeof record.scenarioAssumption === "string"
    ? record.scenarioAssumption
    : "";
  const currentText = `${prompt} ${scenario}`;
  // Route by the selected analysis mode and a closing-time question, never by
  // words in the model's answer. Other SI conversation paths stay untouched.
  if (
    !/\b(?:clos(?:e|es|ing)|shuts?|cierra|cierre)\b/i.test(currentText) ||
    !/\b(?:shop(?:ping)?|grocer(?:y|ies)|supermarket|compras?|supermercado)\b/i
      .test(
        currentText,
      ) ||
    !/\b\d{1,2}(?::\d{2})?\s*(?:[ap]\.?(?:\s*m\.?)|[ap]m)\b|\b\d{1,2}:\d{2}\b/i
      .test(currentText)
  ) return null;
  const tasks = Array.isArray(record.tasks) ? record.tasks : [];
  const attachedId = record.explicitlyAttachedTaskId;
  const focusedId = record.focusedTaskId;
  const chosenId = typeof attachedId === "string"
    ? attachedId
    : typeof focusedId === "string"
    ? focusedId
    : null;
  const task = chosenId !== null
    ? tasks.find((item) =>
      item && typeof item === "object" &&
      (item as Record<string, unknown>).id === chosenId
    )
    : tasks.length === 1
    ? tasks[0]
    : null;
  const saved = task && typeof task === "object" && !Array.isArray(task)
    ? task as Record<string, unknown>
    : null;
  const start = typeof saved?.scheduledStart === "string"
    ? saved.scheduledStart
    : null;
  return {
    // Earlier chat turns may describe an obsolete trip. Only the current
    // question and the scenario field can provide facts for this calculation.
    userTurns: [prompt, ...(scenario ? [scenario] : [])],
    taskDay: start?.slice(0, 10) ?? null,
    taskTimeZoneId: typeof record.taskTimeZoneId === "string"
      ? record.taskTimeZoneId
      : null,
    recordedTaskStart: start,
    language: record.language === "es" ? "es" : "en",
  };
}

function source(
  quote: string,
  userTurns: readonly string[],
): number | null {
  if (!quote || quote.length > 160 || quote.trim() !== quote) return null;
  // The current question takes priority when the same wording also appeared
  // earlier. A quote from app records alone is never eligible.
  for (let i = userTurns.length - 1; i >= 0; i--) {
    if (userTurns[i].includes(quote)) return i;
  }
  return null;
}

function clockMinute(quote: string): number | null {
  const normalized = quote.toLowerCase().replace(/\./g, "");
  const matches = [
    ...normalized.matchAll(
      /\b(\d{1,2})(?::(\d{2}))?\s*([ap])\s*m\b|\b(\d{1,2}):(\d{2})\b/g,
    ),
  ];
  if (matches.length !== 1) return null;
  const match = matches[0];
  if (match[3]) {
    const hour = Number(match[1]);
    const minute = Number(match[2] ?? 0);
    if (hour < 1 || hour > 12 || minute > 59) return null;
    return (hour % 12 + (match[3] === "p" ? 12 : 0)) * 60 + minute;
  }
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  return hour <= 23 && minute <= 59 ? hour * 60 + minute : null;
}

function duration(quote: string): number | null {
  // A quote with multiple numbers cannot establish which one is the duration.
  const numbers = [...quote.matchAll(/(?<!\d)\d{1,4}(?!\d)/g)];
  if (numbers.length !== 1 || !/\b(?:min(?:ute)?s?|minutos?)\b/i.test(quote)) {
    return null;
  }
  const value = Number(numbers[0][0]);
  return Number.isSafeInteger(value) && value >= 0 && value <= 1440
    ? value
    : null;
}

export function parseSiTimingExtraction(
  value: unknown,
  userTurns: readonly string[],
): SiTimingExtractedFacts | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const closingQuote = record.closingQuote;
  const travelQuote = record.travelQuote;
  const activityQuote = record.activityQuote;
  if (
    typeof closingQuote !== "string" ||
    typeof travelQuote !== "string" ||
    typeof activityQuote !== "string"
  ) return null;
  const closingTurn = source(closingQuote, userTurns);
  const travelTurn = source(travelQuote, userTurns);
  const activityTurn = source(activityQuote, userTurns);
  if (closingTurn === null || travelTurn === null || activityTurn === null) {
    return null;
  }
  // These are extraction confidence checks, not a broad free-text answer
  // classifier. Unusual wording gets a clarification rather than false math.
  if (
    !/\b(?:clos(?:e|es|ing)|shuts?|cierra|cierre)\b/i.test(closingQuote) ||
    !/\b(?:travel|drive|walk|trip|viaje|trayecto|conducir|caminar)\b/i.test(
      travelQuote,
    ) ||
    !/\b(?:shop|shopping|grocer(?:y|ies)|supermarket|compras?|supermercado)\b/i
      .test(activityQuote)
  ) return null;
  const closingClockMinutes = clockMinute(closingQuote);
  const travelMinutes = duration(travelQuote);
  const activityMinutes = duration(activityQuote);
  if (
    closingClockMinutes === null || travelMinutes === null ||
    activityMinutes === null
  ) return null;
  return {
    closing: {
      value: closingClockMinutes,
      source: "user",
      turnIndex: closingTurn,
      quote: closingQuote,
    },
    travelMinutes: {
      value: travelMinutes,
      source: "user",
      turnIndex: travelTurn,
      quote: travelQuote,
    },
    activityMinutes: {
      value: activityMinutes,
      source: "user",
      turnIndex: activityTurn,
      quote: activityQuote,
    },
  };
}

export function timingInputForTaskDay(
  facts: SiTimingExtractedFacts,
  userTurns: readonly string[],
  taskDay: string,
  taskTimeZoneId: string,
): SiTimingInput | null {
  const day = /^(\d{4})-(\d{2})-(\d{2})$/.exec(taskDay);
  if (!day || !taskTimeZoneId || taskTimeZoneId.length > 80) return null;
  const year = Number(day[1]);
  const month = Number(day[2]);
  const date = Number(day[3]);
  const midnight = Date.UTC(year, month - 1, date);
  const checked = new Date(midnight);
  if (
    checked.getUTCFullYear() !== year ||
    checked.getUTCMonth() + 1 !== month ||
    checked.getUTCDate() !== date
  ) return null;
  const closing = instantForLocalClock(
    year,
    month,
    date,
    facts.closing.value,
    taskTimeZoneId,
  );
  if (!closing) return null;
  return {
    userTurns,
    closing: { ...facts.closing, value: closing },
    travelMinutes: facts.travelMinutes,
    activityMinutes: facts.activityMinutes,
  };
}

function instantForLocalClock(
  year: number,
  month: number,
  day: number,
  clockMinutes: number,
  timeZoneId: string,
): string | null {
  const hour = Math.floor(clockMinutes / 60);
  const minute = clockMinutes % 60;
  const naiveUtc = Date.UTC(year, month - 1, day, hour, minute);
  let formatter: Intl.DateTimeFormat;
  try {
    formatter = new Intl.DateTimeFormat("en-GB", {
      timeZone: timeZoneId,
      calendar: "gregory",
      numberingSystem: "latn",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    });
  } catch {
    return null;
  }
  const parts = (instant: number) => {
    const values = Object.fromEntries(
      formatter.formatToParts(new Date(instant))
        .map((part) => [part.type, part.value]),
    );
    return {
      year: Number(values.year),
      month: Number(values.month),
      day: Number(values.day),
      hour: Number(values.hour),
      minute: Number(values.minute),
    };
  };
  const offsets = new Set<number>();
  for (const hours of [-36, -12, 0, 12, 36]) {
    const probe = naiveUtc + hours * 3_600_000;
    const local = parts(probe);
    const localAsUtc = Date.UTC(
      local.year,
      local.month - 1,
      local.day,
      local.hour,
      local.minute,
    );
    offsets.add((localAsUtc - probe) / 60_000);
  }
  const matches: number[] = [];
  for (const offset of offsets) {
    const candidate = naiveUtc - offset * 60_000;
    const local = parts(candidate);
    if (
      local.year === year && local.month === month && local.day === day &&
      local.hour === hour && local.minute === minute
    ) matches.push(candidate);
  }
  // Reject spring-forward gaps and fall-back clocks that map to two instants.
  return matches.length === 1 ? new Date(matches[0]).toISOString() : null;
}
