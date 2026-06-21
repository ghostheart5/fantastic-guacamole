class SIInsights {
  String analyze(List<String> data) {
    return data.isEmpty
        ? "No insights"
        : "Detected ${data.length} thought patterns";
  }
}
