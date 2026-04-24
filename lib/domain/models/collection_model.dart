import 'http_request_model.dart';

abstract class CollectionNode {
  final String id;
  final String name;

  CollectionNode({required this.id, required this.name});

  Map<String, dynamic> toJson();

  static CollectionNode fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'folder') {
      return CollectionFolder.fromJson(json);
    } else if (json['type'] == 'request') {
      return CollectionRequest.fromJson(json);
    }
    throw Exception('Unknown collection node type: ${json['type']}');
  }
}

class CollectionFolder extends CollectionNode {
  final List<CollectionNode> children;

  CollectionFolder({
    required super.id,
    required super.name,
    this.children = const [],
  });

  CollectionFolder copyWith({
    String? id,
    String? name,
    List<CollectionNode>? children,
  }) {
    return CollectionFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      children: children ?? this.children,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'folder',
      'id': id,
      'name': name,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }

  factory CollectionFolder.fromJson(Map<String, dynamic> json) {
    return CollectionFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      children: (json['children'] as List?)
              ?.map((e) => CollectionNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CollectionRequest extends CollectionNode {
  final HttpRequestModel request;

  CollectionRequest({
    required super.id,
    required super.name,
    required this.request,
  });

  CollectionRequest copyWith({
    String? id,
    String? name,
    HttpRequestModel? request,
  }) {
    return CollectionRequest(
      id: id ?? this.id,
      name: name ?? this.name,
      request: request ?? this.request,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'request',
      'id': id,
      'name': name,
      'request': request.toJson(),
    };
  }

  factory CollectionRequest.fromJson(Map<String, dynamic> json) {
    return CollectionRequest(
      id: json['id'] as String,
      name: json['name'] as String,
      request:
          HttpRequestModel.fromJson(json['request'] as Map<String, dynamic>),
    );
  }
}

class CollectionModel {
  final String id;
  final String workspaceId;
  final String name;
  final List<CollectionNode> children;

  CollectionModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.children = const [],
  });

  CollectionModel copyWith({
    String? id,
    String? workspaceId,
    String? name,
    List<CollectionNode>? children,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      children: children ?? this.children,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'name': name,
      'children': children.map((e) => e.toJson()).toList(),
    };
  }

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      name: json['name'] as String,
      children: (json['children'] as List?)
              ?.map((e) => CollectionNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
