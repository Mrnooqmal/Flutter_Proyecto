class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  Post({required this.id, required this.userId, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] is int ? json['id'] : int.parse('${json['id']}'),
      userId: json['userId'] is int ? json['userId'] : int.parse('${json['userId']}'),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
    };
  }
}
