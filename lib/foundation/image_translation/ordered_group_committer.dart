/// One group's contribution to a chapter's counters, produced by processing a
/// contiguous page range. Applied to the chapter only via [OrderedGroupCommitter]
/// so counts land in strict group order.
class GroupResult {
  GroupResult(this.done, this.failed, this.failedPages);

  final int done;
  final int failed;
  final Set<int> failedPages;
}

/// Lets pre-translation run groups concurrently (out of order) while committing
/// their counts in strict group order. This preserves the pre-translation
/// invariant that `chapter.done + chapter.failed` is always a CONTIGUOUS
/// processed prefix — the resume cursor (`startIndex = done + failed`) relies
/// on it. A group whose predecessors have not finished is buffered; when the
/// contiguous prefix becomes available it is returned for atomic application.
class OrderedGroupCommitter {
  OrderedGroupCommitter(this._nextCommitIndex);

  int _nextCommitIndex;
  final _buffer = <int, GroupResult>{};

  int get nextCommitIndex => _nextCommitIndex;

  bool get hasPending => _buffer.isNotEmpty;

  /// Records group [index]'s [result] and returns the now-committable results
  /// in ascending group order (the contiguous prefix starting at the next
  /// uncommitted index), advancing the cursor past them. Returns empty when
  /// [index] is ahead of the next expected group.
  List<GroupResult> record(int index, GroupResult result) {
    _buffer[index] = result;
    var ready = <GroupResult>[];
    while (_buffer.containsKey(_nextCommitIndex)) {
      ready.add(_buffer.remove(_nextCommitIndex)!);
      _nextCommitIndex++;
    }
    return ready;
  }
}
