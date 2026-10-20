import type { SiTimingResult } from "./si_timing_plan.ts";

export interface SiTimingReplyContext {
  language: "en" | "es";
  timeZoneId: string;
  travelMinutes: number;
  activityMinutes: number;
  recordedTaskStart?: string;
}

function clock(iso: string, timeZoneId: string, spanish: boolean): string {
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: timeZoneId,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const values = Object.fromEntries(
    formatter.formatToParts(new Date(iso))
      .map((part) => [part.type, part.value]),
  );
  const hour = Number(values.hour);
  const minute = values.minute;
  const hour12 = hour % 12 || 12;
  const marker = hour < 12
    ? (spanish ? "a. m." : "AM")
    : (spanish ? "p. m." : "PM");
  return `${hour12}:${minute} ${marker}`;
}

export function recordedTaskClock(
  localDateTime: string | null,
  language: "en" | "es",
): string | undefined {
  const match = localDateTime && /T(\d{2}):(\d{2})/.exec(localDateTime);
  if (!match) return undefined;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return undefined;
  const marker = hour < 12
    ? language === "es" ? "a. m." : "AM"
    : language === "es"
    ? "p. m."
    : "PM";
  return `${hour % 12 || 12}:${String(minute).padStart(2, "0")} ${marker}`;
}

export function renderSiTimingReply(
  result: SiTimingResult,
  context: SiTimingReplyContext,
): string {
  const spanish = context.language === "es";
  let zoneValid = false;
  try {
    new Intl.DateTimeFormat("en-GB", { timeZone: context.timeZoneId });
    zoneValid = true;
  } catch { /* fail closed */ }
  if (
    !zoneValid ||
    !Number.isSafeInteger(context.travelMinutes) ||
    !Number.isSafeInteger(context.activityMinutes)
  ) {
    return spanish
      ? "No puedo verificar estas horas todavía. Confirma la hora de cierre y la duración del viaje y la compra."
      : "I can't verify these times yet. Please confirm the closing time, travel time, and shopping duration.";
  }
  if (result.status === "invalid" || result.status === "missing") {
    return spanish
      ? "No voy a suponer que la hora de la tarea es tu salida. Confirma la hora de cierre y cuánto duran el viaje y la compra."
      : "I won't treat the task's start as your departure. Please confirm the closing time, travel time, and shopping duration.";
  }
  const at = (value: string) => clock(value, context.timeZoneId, spanish);
  const taskStart = context.recordedTaskStart;
  const taskCaveat = taskStart
    ? spanish
      ? `La tarea guardada empieza a las ${taskStart}, pero eso no indica cuándo sales ni cuándo empieza la compra.`
      : `The saved task starts at ${taskStart}, but that does not establish when you leave or start shopping.`
    : spanish
    ? "No hay una hora de salida guardada."
    : "No departure time is recorded.";
  if (result.status === "window") {
    const closing = at(result.closing);
    const latest = at(result.latestDeparture);
    const optional = at(result.optionalDeparture);
    if (!result.latestDepartureStillPossible) {
      return spanish
        ? `${taskCaveat} Si ese cierre es el mismo día de la tarea guardada, con ${context.travelMinutes} minutos de viaje y ${context.activityMinutes} de compra antes de las ${closing}, la última salida sin margen era a las ${latest}; ya pasó. No puedo recomendar esa salida como si aún estuviera disponible.`
        : `${taskCaveat} If that closing is on the saved task's date, with ${context.travelMinutes} minutes of travel and ${context.activityMinutes} of shopping before ${closing}, the latest departure with no buffer was ${latest}; it has passed. I can't recommend it as though it is still available.`;
    }
    const option = result.optionalDepartureStillPossible
      ? spanish
        ? `Si quieres un margen opcional de ${result.optionalBufferMinutes} minutos, apunta a salir a las ${optional}.`
        : `For an optional ${result.optionalBufferMinutes}-minute cushion, aim to leave at ${optional}.`
      : spanish
      ? `La opción de salir a las ${optional} con ${result.optionalBufferMinutes} minutos de margen ya pasó.`
      : `The ${optional} option with a ${result.optionalBufferMinutes}-minute cushion has already passed.`;
    return spanish
      ? `${taskCaveat} Si ese cierre es el mismo día de la tarea guardada, con ${context.travelMinutes} minutos de viaje y ${context.activityMinutes} de compra antes de las ${closing}, la última salida sin margen es a las ${latest}. ${option} ¿Las ${
        taskStart ?? "hora de la tarea"
      } son el inicio de la compra o solo de preparar la lista?`
      : `${taskCaveat} If that closing is on the saved task's date, with ${context.travelMinutes} minutes of travel and ${context.activityMinutes} of shopping before ${closing}, the latest departure with no buffer is ${latest}. ${option} Is ${
        taskStart ?? "the task's start"
      } when shopping begins, or just when you start preparing the list?`;
  }
  const departure = at(result.departure);
  const arrival = at(result.arrival);
  const finish = at(result.finish);
  const closing = at(result.closing);
  const conclusion = result.viable
    ? spanish
      ? `Quedan ${result.bufferMinutes} minutos antes del cierre a las ${closing}.`
      : `That leaves ${result.bufferMinutes} minutes before the ${closing} closing.`
    : spanish
    ? `Terminarías después del cierre a las ${closing}; ese plan no cabe con estas duraciones.`
    : `That finishes after the ${closing} closing, so this plan does not fit those durations.`;
  const status = result.departureStillPossible
    ? ""
    : spanish
    ? " Esa salida ya pasó; no la recomiendo como una opción actual."
    : " That departure time has passed; I am not recommending it as a current option.";
  return spanish
    ? `Con la salida que marcaste a las ${departure}, llegarías a las ${arrival} y terminarías a las ${finish}. ${conclusion}${status}`
    : `With your selected ${departure} departure, you would arrive at ${arrival} and finish at ${finish}. ${conclusion}${status}`;
}
