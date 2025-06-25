// lib/models/notification_model.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? imageUrl;
  final String? deepLink;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final String status;
  final List<NotificationAction> actions;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.imageUrl,
    this.deepLink,
    required this.data,
    required this.createdAt,
    this.readAt,
    this.isRead = false,
    this.status = 'sent',
    this.actions = const [],
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      imageUrl: json['imageUrl']?.toString(),
      deepLink: json['deepLink']?.toString(),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      isRead: json['isRead'] ?? false,
      status: json['status']?.toString() ?? 'sent',
      actions: (json['actions'] as List<dynamic>?)
          ?.map((action) => NotificationAction.fromJson(action))
          .toList() ?? [],
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['notificationId']?.toString() ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      imageUrl: map['imageUrl']?.toString(),
      deepLink: map['deepLink']?.toString(),
      data: Map<String, dynamic>.from(map['data'] ?? map),
      createdAt: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      readAt: map['readAt'] != null
          ? DateTime.tryParse(map['readAt'].toString())
          : null,
      isRead: map['isRead'] ?? false,
      status: map['status']?.toString() ?? 'sent',
      actions: (map['actions'] != null)
          ? (map['actions'] is String)
          ? _parseActionsFromString(map['actions'])
          : (map['actions'] as List<dynamic>)
          .map((action) => NotificationAction.fromJson(action))
          .toList()
          : [],
    );
  }

  static List<NotificationAction> _parseActionsFromString(String actionsString) {
    try {
      final List<dynamic> actionsList =
      (actionsString.isNotEmpty) ?
      (actionsString.startsWith('[') ?
      (actionsString as dynamic) : []) : [];
      return actionsList
          .map((action) => NotificationAction.fromJson(action))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'body': body,
      'type': type,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isRead': isRead,
      'status': status,
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? imageUrl,
    String? deepLink,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isRead,
    String? status,
    List<NotificationAction>? actions,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      actions: actions ?? this.actions,
    );
  }

  // Bildirim türüne göre ikon al
  IconData get typeIcon {
    switch (type) {
      case 'music':
        return Icons.music_note;
      case 'playlist':
        return Icons.playlist_play;
      case 'user':
        return Icons.person;
      case 'promotion':
        return Icons.local_offer;
      case 'general':
      default:
        return Icons.notifications;
    }
  }

  // Bildirim türüne göre renk al
  Color get typeColor {
    switch (type) {
      case 'music':
        return Colors.purple;
      case 'playlist':
        return Colors.green;
      case 'user':
        return Colors.blue;
      case 'promotion':
        return Colors.orange;
      case 'general':
      default:
        return Colors.grey;
    }
  }

  // Zaman dilimi formatı
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} hafta önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
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
      action: json['action']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString(),
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