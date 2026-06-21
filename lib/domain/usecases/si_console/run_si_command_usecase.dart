class RunSICommandUseCase {
  String call({
    required String command,
    required String Function(String) runner,
  }) {
    return runner(command);
  }
}
