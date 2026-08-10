export const RETIRED_ENDPOINT_BODY = Object.freeze({
  error: "endpoint_retired",
  message: "This legacy ChronoSpark endpoint is no longer available.",
});

export function retiredEndpointResponse(): Response {
  return new Response(JSON.stringify(RETIRED_ENDPOINT_BODY), {
    status: 410,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
