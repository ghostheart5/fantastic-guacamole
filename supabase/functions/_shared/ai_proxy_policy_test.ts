import {
  buildServerSystemPrompt,
  containsBlockedAssistantClaim,
  containsRecommendationContradiction,
  containsScheduledStartDepartureConfusion,
} from "./ai_proxy_policy.ts";

Deno.test("builds policy only from allowlisted control fields", () => {
  const prompt = buildServerSystemPrompt("planner", {
    querySurface: "tasks",
    grounded: { taskCount: 2 },
  });
  if (!prompt?.includes("untrusted user data")) {
    throw new Error("server safety policy missing");
  }
  if (!prompt.includes('"taskCount":2')) {
    throw new Error("bounded context missing");
  }
  if (!prompt.includes("context.selectedSources")) {
    throw new Error("selected source policy missing");
  }
  if (!prompt.includes("never describe a late result as on time")) {
    throw new Error("timing consistency policy missing");
  }
  if (!prompt.includes("State every requested milestone time explicitly")) {
    throw new Error("timing milestone policy missing");
  }
  if (!prompt.includes("copy those option labels exactly")) {
    throw new Error("named timing option policy missing");
  }
  if (!prompt.includes("never recommend a departure after it")) {
    throw new Error("latest-departure consistency policy missing");
  }
  if (!prompt.includes("answer every field they requested")) {
    throw new Error("follow-up correction policy missing");
  }
  if (!prompt.includes("opening recommendation is a binding verdict")) {
    throw new Error("opening-verdict consistency policy missing");
  }
  if (!prompt.includes("Never say that I, we, SI, Axiomara")) {
    throw new Error("read-only response wording policy missing");
  }
  if (!prompt.includes("Never mention ChronoSpark")) {
    throw new Error("retired product name policy missing");
  }
  if (buildServerSystemPrompt("override", {}) !== null) {
    throw new Error("unknown personality accepted");
  }
});

Deno.test("scheduled task start cannot become an invented store departure", () => {
  const context = {
    mode: "findConflict",
    scenarioAssumption:
      "Store closes 8 PM tomorrow. Travel 15 minutes. Shopping 30 minutes.",
    tasks: [{
      title: "QA Grocery List 3080",
      scheduledStart: "2026-09-23T19:13:00.000",
      estimatedDurationMinutes: 30,
    }],
  };
  const prompt = "Does this task conflict with an 8 PM store closing?";
  const captured =
    "Scheduled start: 7:13 PM. Depart | 7:13 PM. Arrive at store | 7:28 PM. Shopping complete | 7:58 PM. Yes, there is a conflict.";
  if (!containsScheduledStartDepartureConfusion(captured, context, prompt)) {
    throw new Error("captured SI start-as-departure response was accepted");
  }
  if (
    !containsScheduledStartDepartureConfusion(
      "Inicio programado: 7:13 p. m. Salida | 7:13 p. m. Llegada | 7:28 p. m.",
      context,
      "¿Hay un conflicto con el cierre de la tienda?",
    )
  ) throw new Error("Spanish start-as-departure response was accepted");
  if (
    !containsScheduledStartDepartureConfusion(
      "Inicio programado: 19:13. Salida: 19:13. Llegada: 19:28.",
      context,
      "¿Hay un conflicto con el cierre de la tienda?",
    )
  ) throw new Error("24-hour start-as-departure response was accepted");
  for (const advice of ["Sal a las 19:13", "Salga a las 19:13"]) {
    if (
      !containsScheduledStartDepartureConfusion(
        advice,
        context,
        "¿A qué hora debo ir a la tienda?",
      )
    ) throw new Error(`Spanish departure advice was accepted: ${advice}`);
  }
  if (
    !containsScheduledStartDepartureConfusion(
      "Sal a las 7:13.",
      {
        ...context,
        tasks: [{
          title: "Lista de compras",
          scheduledStart: "2026-09-23T07:13:00.000",
        }],
      },
      "¿Cuándo debo salir?",
    )
  ) throw new Error("unpadded morning departure was accepted");
  if (
    containsScheduledStartDepartureConfusion(
      "Leave at 7:13 PM for the store.",
      {
        ...context,
        tasks: [{
          title: "Pack bags",
          scheduledStart: "2026-09-23T07:13:00.000",
        }],
      },
      "When should I leave?",
    )
  ) throw new Error("morning start matched explicit PM departure");
  for (
    const scheduledStart of [
      "2026-09-23T09:13:00.000",
      "2026-09-23T13:13:00.000",
    ]
  ) {
    if (
      containsScheduledStartDepartureConfusion(
        "Sal a las 19:13; 11:13 PM is another option.",
        {
          ...context,
          tasks: [{ title: "Lista de compras", scheduledStart }],
        },
        "¿Cuándo debo salir?",
      )
    ) throw new Error(`clock suffix matched another hour: ${scheduledStart}`);
  }
  for (
    const advice of [
      "Head to the store at 7:13 PM.",
      "Drive to the store at 7:13 PM.",
      "7:13 PM is your departure.",
      "7:13 p.m. is your departure.",
      "Saldrá a las 19:13.",
    ]
  ) {
    if (!containsScheduledStartDepartureConfusion(advice, context, prompt)) {
      throw new Error(`natural departure phrasing was accepted: ${advice}`);
    }
  }
  if (
    containsScheduledStartDepartureConfusion(
      "Leave by 6:58 PM, arrive and begin shopping at 7:13 PM, finish at 7:43 PM before the 8 PM close.",
      context,
      "I want to start shopping at the task's 7:13 PM time. When should I leave?",
    )
  ) throw new Error("valid grocery timing was rejected");
  if (
    containsScheduledStartDepartureConfusion(
      "If you depart at 7:13 PM, you will arrive at 7:28 PM.",
      context,
      "What if I depart at 7:13 PM?",
    )
  ) throw new Error("user-proposed departure was rejected");
  if (
    containsScheduledStartDepartureConfusion(
      "Yes, depart at 7:13 PM if that is what you choose.",
      context,
      "What if I depart at 7:13 PM?",
    )
  ) {
    throw new Error(
      "conditional user proposal was treated as assistant speculation",
    );
  }
  if (
    containsScheduledStartDepartureConfusion(
      "If you depart at 7:13 PM, you will arrive at 7:28 PM.",
      context,
      "Would that work?",
      ["What if I depart at 7:13 PM?"],
    )
  ) throw new Error("departure from user history was rejected");
  if (
    !containsScheduledStartDepartureConfusion(
      "Depart at 7:13 PM and arrive at 7:28 PM.",
      context,
      "Actually, do not depart at 7:13 PM. What time should I leave?",
      ["What if I depart at 7:13 PM?"],
    )
  ) throw new Error("newer departure correction did not revoke history");
  if (
    !containsScheduledStartDepartureConfusion(
      "Depart at 7:13 PM and arrive at 7:28 PM.",
      context,
      "Actually, that departure is too late; when should I leave?",
      ["What if I depart at 7:13 PM?"],
    )
  ) throw new Error("anaphoric rejection did not revoke history");
  if (
    !containsScheduledStartDepartureConfusion(
      "Depart at 7:13 PM to reach the store.",
      context,
      "Leave the 7:13 PM task unchanged; when should I depart?",
    )
  ) throw new Error("leaving a task unchanged authorized a departure");
  if (
    !containsScheduledStartDepartureConfusion(
      "Leave home at 7:13 AM.",
      {
        ...context,
        tasks: [{
          title: "Pack bags",
          scheduledStart: "2026-09-23T07:13:00.000",
        }],
      },
      "7:13 AM is the train departure; when should I leave home?",
    )
  ) throw new Error("train departure authorized user departure");
  if (
    !containsScheduledStartDepartureConfusion(
      "Leave home at 7:13 AM.",
      {
        ...context,
        tasks: [{
          title: "Pack bags",
          scheduledStart: "2026-09-23T07:13:00.000",
        }],
      },
      "The train departure is at 7:13 AM; when should I leave home?",
    )
  ) throw new Error("verb-first train fact authorized user departure");
  if (
    !containsScheduledStartDepartureConfusion(
      "Leave at 7:13 PM to reach the store.",
      context,
      "I need to leave before 7:13 PM. What time should I depart?",
    )
  ) throw new Error("departure bound authorized its exact clock");
  if (
    !containsScheduledStartDepartureConfusion(
      "Depart at 7:13 PM and arrive at 7:28 PM.",
      {
        ...context,
        scenarioAssumption: "Do not leave at 7:13 PM.",
      },
      "What time should I leave?",
      ["Leave at 7:13 PM."],
    )
  ) throw new Error("current scenario did not revoke historical departure");
  if (
    containsScheduledStartDepartureConfusion(
      "Depart at 7:13 PM and arrive at 7:28 PM.",
      context,
      "Do not leave at 7:13 PM—actually, leave at 7:13 PM.",
    )
  ) throw new Error("later same-turn departure proposal was ignored");
  for (
    const clarification of [
      "7:13 PM is not the departure; leave at 6:58 PM.",
      "Do not depart at 7:13 PM; leave at 6:58 PM.",
      "Do not plan to leave at 7:13 PM; leave at 6:58 PM.",
      "You cannot leave at 7:13 PM; leave at 6:58 PM.",
      "Don’t leave at 7:13 PM; leave at 6:58 PM.",
      "19:13 no es la salida; sal a las 18:58.",
      "No deberías salir a las 19:13; sal a las 18:58.",
      "Leaving at 7:13 PM would be too late; leave at 6:58 PM.",
      "A 7:13 PM departure would be too late; leave at 6:58 PM.",
      "If you leave at 7:13 PM, that is hypothetical; leave at 6:58 PM.",
    ]
  ) {
    if (
      containsScheduledStartDepartureConfusion(clarification, context, prompt)
    ) {
      throw new Error("negated departure clarification was rejected");
    }
  }
  if (
    !containsScheduledStartDepartureConfusion(
      "You don't need to leave until 7:13 PM.",
      context,
      prompt,
    )
  ) throw new Error("inverted necessity hid departure recommendation");
  for (
    const advice of [
      "Don't leave after 7:13 PM.",
      "Do not leave any later than 7:13 PM.",
      "You must not leave after 7:13 PM.",
      "You should not leave later than 7:13 PM.",
    ]
  ) {
    if (!containsScheduledStartDepartureConfusion(advice, context, prompt)) {
      throw new Error(`negated upper bound hid departure advice: ${advice}`);
    }
  }
  const twoTasks = {
    ...context,
    tasks: [
      { title: "Task A", scheduledStart: "2026-09-23T19:13:00.000" },
      { title: "Shopping Task B", scheduledStart: "2026-09-23T19:28:00.000" },
    ],
  };
  if (
    containsScheduledStartDepartureConfusion(
      "For Shopping Task B, leave at 7:13 PM to arrive at its 7:28 PM start.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("another task's valid departure was rejected");
  if (
    !containsScheduledStartDepartureConfusion(
      "For Task A, leave at 7:13 PM to arrive at 7:28 PM.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("named task's start-as-departure error was missed");
  if (
    !containsScheduledStartDepartureConfusion(
      "Unlike Shopping Task B, Task A requires leaving at 7:13 PM.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("multi-task comparison lost local attribution");
  if (
    containsScheduledStartDepartureConfusion(
      "Unlike Task A, Shopping Task B requires leaving at 7:13 PM.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("multi-task comparison attributed the other task");
  if (
    !containsScheduledStartDepartureConfusion(
      "For Dr. appointment, leave at 7:13 PM to arrive at 7:28 PM.",
      {
        ...context,
        tasks: [
          {
            title: "Dr. appointment",
            scheduledStart: "2026-09-23T19:13:00.000",
          },
          { title: "Shopping", scheduledStart: "2026-09-23T19:28:00.000" },
        ],
      },
      "Compare both tasks.",
    )
  ) throw new Error("punctuation in task title split attribution");
  if (
    !containsScheduledStartDepartureConfusion(
      "For Task A, leave at 7:13 PM to arrive at 7:28 PM.",
      twoTasks,
      "For Shopping Task B, leave at 7:13 PM. What about Task A?",
    )
  ) throw new Error("Task B proposal exempted Task A start confusion");
  if (
    !containsScheduledStartDepartureConfusion(
      "Task A:\nDepart | 7:13 PM.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("task heading did not attribute its departure row");
  if (
    !containsScheduledStartDepartureConfusion(
      "Task A:\nScheduled start | 7:13 PM\nDepart | 7:13 PM.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("task heading was lost across a metadata row");
  if (
    !containsScheduledStartDepartureConfusion(
      "| Task | Departure |\n| --- | --- |\n| Task A | 7:13 PM |\n| Shopping Task B | 7:00 PM |",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("Markdown departure column bypassed the guard");
  for (
    const table of [
      "| Task | Departure time |\n| --- | --- |\n| Task A | 7:13 PM |",
      "| **Task** | **Departure** |\n| --- | --- |\n| Task A | 7:13 PM |",
      "| Task | Departure |\n| --- | --- |\n| Task A | **7:13 PM** |",
      "| Task | Departure |\n| --- | --- |\n| **Task A** | **7:13 PM** |",
    ]
  ) {
    if (
      !containsScheduledStartDepartureConfusion(
        table,
        twoTasks,
        "Compare Task A with Shopping Task B.",
      )
    ) throw new Error("formatted Markdown departure header bypassed guard");
  }
  if (
    containsScheduledStartDepartureConfusion(
      "| Task | Departure |\n| --- | --- |\n| Shopping Task B | 7:13 PM |",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("Markdown departure column matched the wrong task");
  if (
    containsScheduledStartDepartureConfusion(
      "Shopping Task B:\nDepart | 7:13 PM to arrive at 7:28 PM.",
      twoTasks,
      "Compare Task A with Shopping Task B.",
    )
  ) throw new Error("other task heading misattributed the departure row");
  if (
    !containsScheduledStartDepartureConfusion(
      "For Groceries, depart at 7:13 PM to arrive at 7:28 PM.",
      {
        ...context,
        tasks: [
          { title: "Groceries", scheduledStart: "2026-09-23T19:13:00.000" },
          { title: "Groceries", scheduledStart: "2026-09-23T19:28:00.000" },
        ],
      },
      "Compare both Groceries tasks.",
    )
  ) throw new Error("duplicate task titles bypassed the named-task guard");
  if (
    !containsScheduledStartDepartureConfusion(
      "For Task A groceries, leave at 7:28 PM.",
      {
        ...context,
        tasks: [
          { title: "Task A", scheduledStart: "2026-09-23T19:13:00.000" },
          {
            title: "Task A groceries",
            scheduledStart: "2026-09-23T19:28:00.000",
          },
        ],
      },
      "Compare Task A and Task A groceries.",
    )
  ) throw new Error("overlapping task title masked the specific task");
  for (const title of ["Leave feedback", "Prepare departure checklist"]) {
    if (
      !containsScheduledStartDepartureConfusion(
        "Depart at 7:13 PM to go to the store.",
        {
          ...context,
          tasks: [{ title, scheduledStart: "2026-09-23T19:13:00.000" }],
        },
        "When should I go to the store?",
      )
    ) throw new Error(`non-travel title bypassed the guard: ${title}`);
  }
  if (
    !containsScheduledStartDepartureConfusion(
      "Leave at 7:13 PM to go to the store.",
      {
        ...context,
        tasks: [{
          title: "Go to sleep",
          scheduledStart: "2026-09-23T19:13:00.000",
        }],
      },
      "When should I go to the store?",
    )
  ) throw new Error("non-travel Go to sleep title bypassed the guard");
  for (
    const title of [
      "Depart for store",
      "Drive to store",
      "Head to store",
      "Walk to store",
      "Walking to store",
    ]
  ) {
    if (
      containsScheduledStartDepartureConfusion(
        "Drive to the store at 7:13 PM.",
        {
          ...context,
          tasks: [{ title, scheduledStart: "2026-09-23T19:13:00.000" }],
        },
        "When should I go to the store?",
      )
    ) {
      throw new Error(
        `actual travel task was treated as preparation: ${title}`,
      );
    }
  }
  if (
    containsScheduledStartDepartureConfusion(
      "Sal a las 19:13 para ir a la tienda.",
      {
        ...context,
        tasks: [{
          title: "Ir a la tienda",
          scheduledStart: "2026-09-23T19:13:00.000",
        }],
      },
      "¿Cuándo debo salir?",
    )
  ) throw new Error("Spanish travel task was treated as list preparation");
  if (
    containsScheduledStartDepartureConfusion(
      "Sal a las 19:13 para ir al mercado.",
      {
        ...context,
        tasks: [{
          title: "Ir al mercado",
          scheduledStart: "2026-09-23T19:13:00.000",
        }],
      },
      "¿Cuándo debo salir?",
    )
  ) throw new Error("Spanish al travel task was treated as list preparation");
  if (
    !containsScheduledStartDepartureConfusion(
      "Leave at 7 PM to go to the store.",
      {
        ...context,
        tasks: [{
          title: "Shopping list",
          scheduledStart: "2026-09-23T19:00:00.000",
        }],
      },
      "When should I go to the store?",
    )
  ) throw new Error("minute-less on-the-hour departure was accepted");
});

Deno.test("detects a direct recommendation contradicted by its own evidence", () => {
  const captured = `Groceries first, then release evidence.
The grocery windows have already passed. Neither grocery task is actionable right now.
The release review fits in the available time.`;
  if (!containsRecommendationContradiction(captured)) {
    throw new Error("captured contradictory Planner response was accepted");
  }
  if (
    containsRecommendationContradiction(
      "Release evidence first. The grocery windows have passed, and release review fits now.",
    )
  ) {
    throw new Error("consistent recommendation was rejected");
  }
  if (
    !containsRecommendationContradiction(
      "Las compras primero. Ninguna compra es viable ahora porque la ventana ya paso.",
    )
  ) {
    throw new Error("Spanish contradiction was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "First, buy groceries. The grocery window has passed, so that task is not actionable.",
    )
  ) {
    throw new Error("English prefix contradiction was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "Primero, compra alimentos. La ventana ya paso y esa tarea no es viable ahora.",
    )
  ) {
    throw new Error("Spanish prefix contradiction was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "First, buy groceries. It is not feasible today.",
    )
  ) {
    throw new Error("English pronoun contradiction was accepted");
  }
  if (
    containsRecommendationContradiction(
      "First, call the dentist. It is not possible to know the wait time in advance.",
    )
  ) {
    throw new Error("dummy pronoun was mistaken for the recommendation");
  }
  if (
    containsRecommendationContradiction(
      "First, call the dentist. It isn't possible to know the wait time in advance.",
    )
  ) {
    throw new Error(
      "contracted dummy pronoun was mistaken for the recommendation",
    );
  }
  if (
    containsRecommendationContradiction(
      "First, call the dentist. It may not be possible to know the wait time in advance.",
    )
  ) {
    throw new Error(
      "modal dummy pronoun was mistaken for the recommendation",
    );
  }
  if (
    !containsRecommendationContradiction(
      "Primero, compra alimentos. Eso no es viable hoy.",
    )
  ) {
    throw new Error("Spanish pronoun contradiction was accepted");
  }
  if (
    containsRecommendationContradiction(
      "First, buy groceries. That said, the release is not feasible today.",
    )
  ) {
    throw new Error(
      "discourse marker was mistaken for a recommendation reference",
    );
  }
  if (
    containsRecommendationContradiction(
      "The pharmacy closed first. It is closed now.",
    ) ||
    containsRecommendationContradiction(
      "The pharmacy opened first. It is closed now.",
    )
  ) {
    throw new Error("factual chronology was mistaken for a recommendation");
  }
  if (
    !containsRecommendationContradiction(
      "Visit the pharmacy that is nearest first. It is closed.",
    )
  ) {
    throw new Error("relative-clause recommendation was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "We have to visit the pharmacy first. It is closed.",
    )
  ) {
    throw new Error("obligation recommendation was accepted");
  }
  if (
    containsRecommendationContradiction(
      "We have to avoid visiting the pharmacy first. It is closed.",
    )
  ) {
    throw new Error("negated obligation was treated as a contradiction");
  }
  if (
    containsRecommendationContradiction(
      "We need to avoid visiting the pharmacy first. It is closed.",
    ) ||
    !containsRecommendationContradiction(
      "We need to visit the pharmacy first. It is closed.",
    )
  ) {
    throw new Error("need-to obligation had the wrong contradiction verdict");
  }
  if (
    !containsRecommendationContradiction(
      "Start with groceries. Groceries are not feasible today.",
    )
  ) {
    throw new Error("imperative English contradiction was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "First, visit the pharmacy. The pharmacy is closed.",
    )
  ) {
    throw new Error("closed English recommendation was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "First, visit the pharmacy. The pharmacy has closed.",
    )
  ) {
    throw new Error("perfect-tense English closure was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "First, visit the pharmacy. The pharmacy has just closed.",
    ) ||
    !containsRecommendationContradiction(
      "First, visit the pharmacy. It has recently closed.",
    ) ||
    !containsRecommendationContradiction(
      "First, visit the pharmacy. The pharmacy is temporarily closed.",
    )
  ) {
    throw new Error("current adverbial or pronoun closure was accepted");
  }
  if (
    containsRecommendationContradiction(
      "First, visit the pharmacy. The pharmacy had closed yesterday but reopened today.",
    )
  ) {
    throw new Error("historical closure invalidated a current recommendation");
  }
  if (
    !containsRecommendationContradiction(
      "Primero, visita la farmacia. La farmacia está cerrada.",
    ) ||
    !containsRecommendationContradiction(
      "Primero, visita la farmacia. La farmacia está temporalmente cerrada.",
    )
  ) {
    throw new Error("closed Spanish recommendation was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "Primero, visita la farmacia. La farmacia ha cerrado.",
    )
  ) {
    throw new Error("perfect-tense Spanish closure was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "Primero, visita la farmacia. La farmacia acaba de cerrar.",
    )
  ) {
    throw new Error("current Spanish closure was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "Empieza con alimentos. Los alimentos no son viables hoy.",
    )
  ) {
    throw new Error("imperative Spanish contradiction was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "I recommend visiting the pharmacy. The pharmacy is closed.",
    ) ||
    !containsRecommendationContradiction(
      "My recommendation is to visit the pharmacy. The pharmacy is closed.",
    ) ||
    !containsRecommendationContradiction(
      "Our recommendation would be to visit the pharmacy. The pharmacy is closed.",
    )
  ) {
    throw new Error("direct or nominal English recommendation was accepted");
  }
  if (
    containsRecommendationContradiction(
      "I don't recommend visiting the pharmacy first. The pharmacy is closed.",
    )
  ) {
    throw new Error("first-person negated recommendation was rejected");
  }
  if (
    !containsRecommendationContradiction(
      "You should visit the pharmacy. The pharmacy is closed.",
    )
  ) {
    throw new Error("English should recommendation was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "Te recomiendo visitar la farmacia. La farmacia está cerrada.",
    ) ||
    !containsRecommendationContradiction(
      "Mi recomendación es visitar la farmacia. La farmacia está cerrada.",
    )
  ) {
    throw new Error("direct or nominal Spanish recommendation was accepted");
  }
  if (
    containsRecommendationContradiction(
      "I recommend visiting the pharmacy. The pharmacy is open.",
    )
  ) {
    throw new Error("consistent direct recommendation was rejected");
  }
  if (
    containsRecommendationContradiction(
      "You should not visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "Te recomiendo no visitar la farmacia. La farmacia está cerrada.",
    ) ||
    containsRecommendationContradiction(
      "I recommend that you not visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "I recommend you not visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "I recommend you don't visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "I recommend that she doesn't visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "First, don't visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "First, you should not visit the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "You should not visit the pharmacy first. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "Don't visit the pharmacy first. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "Start with avoiding the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "Te recomiendo que no visites la farmacia. La farmacia está cerrada.",
    ) ||
    containsRecommendationContradiction(
      "I recommend avoiding the pharmacy. The pharmacy is closed.",
    ) ||
    containsRecommendationContradiction(
      "Deberías evitar la farmacia. La farmacia está cerrada.",
    )
  ) {
    throw new Error("negated direct recommendation was rejected");
  }
});

Deno.test("rejects oversized and deeply nested context", () => {
  if (
    buildServerSystemPrompt("planner", { value: "x".repeat(12_001) }) !== null
  ) {
    throw new Error("oversized context accepted");
  }
  if (
    buildServerSystemPrompt("planner", { a: { b: { c: { d: { e: 1 } } } } }) !==
      null
  ) {
    throw new Error("deep context accepted");
  }
});

Deno.test("blocks unsupported and prompt-disclosure claims", () => {
  for (
    const text of [
      "I guarantee this result.",
      "Here is the system prompt.",
      "My hidden reasoning follows.",
      "Open ChronoSpark to review it.",
      "Axiomara has scheduled your task.",
      "Axiomara ha programado tu tarea.",
      "SI guardó tu nota.",
      "I've scheduled your task.",
      "We’ve completed it.",
      "I've now scheduled your task.",
      "Axiomara has already updated your plan.",
      "I booked your appointment for 5 PM.",
      "Done — your task has been scheduled for 5 PM.",
      "Done — your appointment is scheduled for 5 PM.",
      "Done! Your appointment is scheduled for 5 PM.",
      "Done. Your appointment is scheduled for 5 PM.",
      "Done, your appointment is scheduled for 5 PM.",
      "Done; your appointment is scheduled for 5 PM.",
      "Your tasks have been scheduled for 5 PM.",
      "Your appointment has been scheduled for 5 PM.",
      "Your meeting has been created.",
      "Your reminder has been saved.",
      "Tu tarea ha sido programada para las 5.",
      "Tu cita ha sido programada para las 5.",
      "Tus tareas han sido programadas para las 5.",
      "Te he programado tu tarea para las 5.",
      "Ya te he programado tu tarea para las 5.",
      "Axiomara ya ha programado tu tarea para las 5.",
      "Axiomara te ha programado tu tarea para las 5.",
      "Ya programé tu tarea para las 5.",
      "Te programé tu tarea para las 5.",
    ]
  ) {
    if (!containsBlockedAssistantClaim(text)) {
      throw new Error(`unsafe output accepted: ${text}`);
    }
  }
  if (containsBlockedAssistantClaim("Try one short task, then review.")) {
    throw new Error("safe output rejected");
  }
  if (containsBlockedAssistantClaim("Your account remains secure.")) {
    throw new Error("safe word containing a partial match was rejected");
  }
  if (
    containsBlockedAssistantClaim("Your appointment is scheduled for 5 PM.")
  ) {
    throw new Error("an existing scheduled record was mistaken for a mutation");
  }
  if (
    containsBlockedAssistantClaim(
      "Axiomara can explain the schedule without changing it.",
    )
  ) {
    throw new Error("safe current-product reference was rejected");
  }
  if (
    containsBlockedAssistantClaim(
      "Si ha completado la tarea, revisa el siguiente paso.",
    )
  ) {
    throw new Error("Spanish conditional was mistaken for the SI product");
  }
  for (
    const unsafe of [
      "He programado tu tarea.",
      "Revisa el plan. Hemos completado la tarea.",
    ]
  ) {
    if (!containsBlockedAssistantClaim(unsafe)) {
      throw new Error(`subjectless Spanish mutation claim escaped: ${unsafe}`);
    }
  }
});

Deno.test("does not treat an affirming feasibility idiom as a contradiction", () => {
  if (
    containsRecommendationContradiction(
      "Groceries first. This option is not only feasible but preferable.",
    )
  ) {
    throw new Error("affirming feasibility idiom was rejected");
  }
});
