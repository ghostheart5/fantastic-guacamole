import {
  buildServerSystemPrompt,
  containsBlockedAssistantClaim,
  containsRecommendationContradiction,
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
    !containsRecommendationContradiction(
      "Start with groceries. Groceries are not feasible today.",
    )
  ) {
    throw new Error("imperative English contradiction was accepted");
  }
  if (
    !containsRecommendationContradiction(
      "Empieza con alimentos. Los alimentos no son viables hoy.",
    )
  ) {
    throw new Error("imperative Spanish contradiction was accepted");
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
      "Done — your task has been scheduled for 5 PM.",
      "Your tasks have been scheduled for 5 PM.",
      "Tu tarea ha sido programada para las 5.",
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
