import {
  parseSiTimingExtraction,
  siTimingRequest,
  timingInputForTaskDay,
} from "./si_timing_extraction.ts";

Deno.test("extracts the Moto closing and durations without using the task start", () => {
  const turns = [
    "Does this task conflict with an 8 PM store closing?",
    "Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM.",
  ];
  const facts = parseSiTimingExtraction({
    closingQuote: "8 PM store closing",
    travelQuote: "Travel 15 minutes",
    activityQuote: "Shopping 30 minutes",
  }, turns);
  if (
    facts?.closing.value !== 20 * 60 ||
    facts.travelMinutes.value !== 15 ||
    facts.activityMinutes.value !== 30 ||
    facts.closing.turnIndex !== 0 ||
    facts.travelMinutes.turnIndex !== 1
  ) {
    throw new Error(
      `the exact SI inputs were not extracted: ${JSON.stringify(facts)}`,
    );
  }
});

Deno.test("rejects a task-start quote substituted for store closing", () => {
  const turns = [
    "Store closes 8 PM. Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM.",
  ];
  const facts = parseSiTimingExtraction({
    closingQuote: "Task starts 7:13 PM",
    travelQuote: "Travel 15 minutes",
    activityQuote: "Shopping 30 minutes",
  }, turns);
  if (facts !== null) throw new Error("a task start became a closing time");
});

Deno.test("rejects invented passages and ambiguous multi-clock quotes", () => {
  const turns = [
    "Store closes 8 PM. Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM.",
  ];
  const baseline = {
    closingQuote: "Store closes 8 PM",
    travelQuote: "Travel 15 minutes",
    activityQuote: "Shopping 30 minutes",
  };
  if (
    parseSiTimingExtraction(
      { ...baseline, travelQuote: "Travel 20 minutes" },
      turns,
    )
  ) {
    throw new Error("uncited travel duration was accepted");
  }
  if (
    parseSiTimingExtraction({
      ...baseline,
      closingQuote:
        "Store closes 8 PM. Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM",
    }, turns)
  ) throw new Error("multi-clock quote was accepted as one time");
});

Deno.test("reads Spanish closing and duration passages", () => {
  const turns = [
    "La tienda cierra a las 8 p. m. El viaje dura 15 minutos. La compra tarda 30 minutos.",
  ];
  const facts = parseSiTimingExtraction({
    closingQuote: "tienda cierra a las 8 p. m.",
    travelQuote: "viaje dura 15 minutos",
    activityQuote: "compra tarda 30 minutos",
  }, turns);
  if (
    facts?.closing.value !== 1200 ||
    facts.travelMinutes.value !== 15 ||
    facts.activityMinutes.value !== 30
  ) throw new Error("Spanish numeric timing was not extracted");
  const supermarketTurns = [
    "El supermercado cierra a las 8 p. m. El viaje dura 15 minutos. Estaré 30 minutos en el supermercado.",
  ];
  const supermarketFacts = parseSiTimingExtraction({
    closingQuote: "supermercado cierra a las 8 p. m.",
    travelQuote: "viaje dura 15 minutos",
    activityQuote: "30 minutos en el supermercado",
  }, supermarketTurns);
  if (supermarketFacts?.activityMinutes.value !== 30) {
    throw new Error("routed supermarket duration was rejected");
  }
});

Deno.test("anchors a hypothetical closing to the task's local day and zone", () => {
  const turns = [
    "Store closes 8 PM. Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM.",
  ];
  const facts = parseSiTimingExtraction({
    closingQuote: "Store closes 8 PM",
    travelQuote: "Travel 15 minutes",
    activityQuote: "Shopping 30 minutes",
  }, turns);
  if (!facts) throw new Error("valid timing facts were rejected");
  const input = timingInputForTaskDay(
    facts,
    turns,
    "2026-09-23",
    "America/Chicago",
  );
  if (input?.closing?.value !== "2026-09-24T01:00:00.000Z") {
    throw new Error(
      `the local closing was anchored incorrectly: ${JSON.stringify(input)}`,
    );
  }
  if (timingInputForTaskDay(facts, turns, "2026-02-30", "America/Chicago")) {
    throw new Error("invalid task day was accepted");
  }
});

Deno.test("uses the closing-time offset across the fall-back transition", () => {
  const turns = ["Store closes 8 PM. Travel 15 minutes. Shopping 30 minutes."];
  const facts = parseSiTimingExtraction({
    closingQuote: "Store closes 8 PM",
    travelQuote: "Travel 15 minutes",
    activityQuote: "Shopping 30 minutes",
  }, turns);
  if (!facts) throw new Error("valid timing facts were rejected");
  const input = timingInputForTaskDay(
    facts,
    turns,
    "2026-11-01",
    "America/Chicago",
  );
  if (input?.closing?.value !== "2026-11-02T02:00:00.000Z") {
    throw new Error(
      `fall-back closing used an earlier offset: ${JSON.stringify(input)}`,
    );
  }
});

Deno.test("does not invent an instant for skipped or repeated local clocks", () => {
  const check = (quote: string, taskDay: string) => {
    const turns = [
      `Store closes ${quote}. Travel 15 minutes. Shopping 30 minutes.`,
    ];
    const facts = parseSiTimingExtraction({
      closingQuote: `Store closes ${quote}`,
      travelQuote: "Travel 15 minutes",
      activityQuote: "Shopping 30 minutes",
    }, turns);
    if (!facts) throw new Error("valid clock facts were rejected");
    if (timingInputForTaskDay(facts, turns, taskDay, "America/Chicago")) {
      throw new Error(`${quote} on ${taskDay} should not map to one instant`);
    }
  };
  check("2:30 AM", "2026-03-08");
  check("1:30 AM", "2026-11-01");
});

Deno.test("routes the exact SI conflict question while preserving other conversations", () => {
  const context = {
    surface: "si",
    mode: "findConflict",
    language: "en",
    taskTimeZoneId: "America/Chicago",
    scenarioAssumption:
      "Travel 15 minutes. Shopping 30 minutes. Task starts 7:13 PM.",
    tasks: [{
      id: "grocery",
      scheduledStart: "2026-09-23T19:13:00",
    }],
  };
  const request = siTimingRequest(
    context,
    "Does this task conflict with an 8 PM store closing?",
  );
  if (
    request?.taskDay !== "2026-09-23" ||
    request.taskTimeZoneId !== "America/Chicago" ||
    request.userTurns.length !== 2
  ) throw new Error("the Moto SI request did not use the structured route");
  const multipleTasks = {
    ...context,
    focusedTaskId: "grocery",
    tasks: [
      ...context.tasks,
      { id: "work", scheduledStart: "2026-09-24T09:00:00" },
    ],
  };
  const focused = siTimingRequest(
    multipleTasks,
    "Does my grocery list conflict with an 8 PM store closing?",
  );
  if (focused?.taskDay !== "2026-09-23") {
    throw new Error("the selected grocery task was lost among active tasks");
  }
  const ambiguous = siTimingRequest(
    { ...multipleTasks, focusedTaskId: null },
    "Does this task conflict with an 8 PM store closing?",
  );
  if (ambiguous?.taskDay !== null) {
    throw new Error("multiple active tasks were silently assigned a focus");
  }
  const olderAppRequest = siTimingRequest({
    ...context,
    taskTimeZoneId: null,
    tasks: [{ id: "grocery", scheduledStart: "2026-09-23T19:13:00" }],
  }, "Does this task conflict with an 8 PM store closing?");
  if (olderAppRequest?.taskTimeZoneId !== null) {
    throw new Error(
      "a missing task timezone was fabricated for an older app",
    );
  }
  if (
    siTimingRequest(
      { ...context, mode: "explain" },
      "Does this task conflict with an 8 PM store closing?",
    )
  ) throw new Error("unrelated analysis mode was rerouted");
  if (
    siTimingRequest(
      { ...context, scenarioAssumption: "Travel 15 minutes." },
      "Does my work shift conflict with the 8 PM office closing?",
    )
  ) throw new Error("non-shopping timing was rerouted to shopping advice");
});
