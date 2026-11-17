class BoardMessage {
  const BoardMessage({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    required this.editedAt,
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;
}

class MessageDraft {
  const MessageDraft({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;
}

class MessageCollision implements Exception {
  const MessageCollision();
}
