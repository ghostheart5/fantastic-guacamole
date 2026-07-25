enum CreatorWorkspaceMode { tasks, goals, milestones, plan }

extension CreatorWorkspaceModeLabel on CreatorWorkspaceMode {
  String get label {
    switch (this) {
      case CreatorWorkspaceMode.tasks:
        return 'Tasks';
      case CreatorWorkspaceMode.goals:
        return 'Goals';
      case CreatorWorkspaceMode.milestones:
        return 'Milestones';
      case CreatorWorkspaceMode.plan:
        return 'Plan';
    }
  }

  String get subtitle {
    switch (this) {
      case CreatorWorkspaceMode.tasks:
        return 'Forge actionable task entries.';
      case CreatorWorkspaceMode.goals:
        return 'Shape measurable goal outcomes.';
      case CreatorWorkspaceMode.milestones:
        return 'Define checkpoint progress.';
      case CreatorWorkspaceMode.plan:
        return 'Arrange the day into motion.';
    }
  }
}
