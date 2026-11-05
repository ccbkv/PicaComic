/// Index of the least-busy worker (fewest pending tasks). Ties resolve to the
/// lowest index. Extracted as a pure function so the pool's dispatch choice is
/// unit-testable without spawning real isolates.
int pickLeastBusyIndex(List<int> pendingCounts) {
  var best = 0;
  for (var i = 1; i < pendingCounts.length; i++) {
    if (pendingCounts[i] < pendingCounts[best]) best = i;
  }
  return best;
}
