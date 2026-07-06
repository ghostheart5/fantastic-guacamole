class MomentumState {
  const MomentumState({this.active = false, this.chainCount = 0});
  final bool active;
  final int chainCount;

  int get tier {
    if (chainCount >= 6) return 3;
    if (chainCount >= 3) return 2;
    if (chainCount >= 1) return 1;
    return 0;
  }

  MomentumState copyWith({bool? active, int? chainCount}) => MomentumState(
    active: active ?? this.active,
    chainCount: chainCount ?? this.chainCount,
  );
}
