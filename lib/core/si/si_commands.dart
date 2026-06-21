class SICommands {
  String execute(String cmd) {
    switch (cmd) {
      case "scan":
        return "Scanning...";
      case "optimize":
        return "Optimizing...";
      default:
        return "Unknown command";
    }
  }
}
