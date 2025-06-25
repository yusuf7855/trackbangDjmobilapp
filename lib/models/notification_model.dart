// lib/models/notification_model.dart
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final String? imageUrl;
  final String? deepLink;
  final List<NotificationAction>? actions;
  final DateTime createdAt;
  final DateTime? sentAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.imageUrl,
    this.deepLink,
    this.actions,
    required this.createdAt,
    this.sentAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'general',
      data: json['data'] as Map<String, dynamic>?,
      imageUrl: json['imageUrl'],
      deepLink: json['deepLink'],
      actions: json['actions'] != null
          ? (json['actions'] as List)
          .map((action) => NotificationAction.fromJson(action))
          .toList()
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['notificationId'] ?? map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      data: map,
      imageUrl: map['imageUrl'],
      deepLink: map['deepLink'],
      actions: map['actions'] != null
          ? (map['actions'] as List)
          .map((action) => NotificationAction.fromJson(action))
          .toList()
          : null,
      createdAt: DateTime.now(),
      sentAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'actions': actions?.map((action) => action.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
    };
  }
}

class NotificationAction {
  final String action;
  final String title;
  final String? url;

  NotificationAction({
    required this.action,
    required this.title,
    this.url,
  });

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      action: json['action'] ?? '',
      title: json['title'] ?? '',
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'title': title,
      'url': url,
    };
  }
}