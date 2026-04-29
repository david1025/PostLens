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
    } else if (json['type'] == 'case') {
      return CollectionRequestCase.fromJson(json);
    }
    throw Exception('Unknown collection node type: ${json['type']}');
  }
}

class CollectionFolder extends CollectionNode {
  final List<CollectionNode> children;
  final String description;

  CollectionFolder({
    required super.id,
    required super.name,
    this.children = const [],
    this.description = '',
  });

  CollectionFolder copyWith({
    String? id,
    String? name,
    List<CollectionNode>? children,
    String? description,
  }) {
    return CollectionFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      children: children ?? this.children,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'folder',
      'id': id,
      'name': name,
      'children': children.map((e) => e.toJson()).toList(),
      'description': description,
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
      description: json['description'] as String? ?? '',
    );
  }
}

class CollectionRequest extends CollectionNode {
  final HttpRequestModel request;
  final List<CollectionRequestCase> cases;

  CollectionRequest({
    required super.id,
    required super.name,
    required this.request,
    this.cases = const [],
  });

  CollectionRequest copyWith({
    String? id,
    String? name,
    HttpRequestModel? request,
    List<CollectionRequestCase>? cases,
  }) {
    return CollectionRequest(
      id: id ?? this.id,
      name: name ?? this.name,
      request: request ?? this.request,
      cases: cases ?? this.cases,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'request',
      'id': id,
      'name': name,
      'request': request.toJson(),
      'cases': cases.map((e) => e.toJson()).toList(),
    };
  }

  factory CollectionRequest.fromJson(Map<String, dynamic> json) {
    return CollectionRequest(
      id: json['id'] as String,
      name: json['name'] as String,
      request:
          HttpRequestModel.fromJson(json['request'] as Map<String, dynamic>),
      cases: (json['cases'] as List?)
              ?.map((e) =>
                  CollectionRequestCase.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class CollectionRequestCase extends CollectionNode {
  final HttpRequestModel request;

  CollectionRequestCase({
    required super.id,
    required super.name,
    required this.request,
  });

  CollectionRequestCase copyWith({
    String? id,
    String? name,
    HttpRequestModel? request,
  }) {
    return CollectionRequestCase(
      id: id ?? this.id,
      name: name ?? this.name,
      request: request ?? this.request,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'case',
      'id': id,
      'name': name,
      'request': request.toJson(),
    };
  }

  factory CollectionRequestCase.fromJson(Map<String, dynamic> json) {
    return CollectionRequestCase(
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
  final String description;

  CollectionModel({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.children = const [],
    this.description = '',
  });

  CollectionModel copyWith({
    String? id,
    String? workspaceId,
    String? name,
    List<CollectionNode>? children,
    String? description,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      children: children ?? this.children,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'name': name,
      'children': children.map((e) => e.toJson()).toList(),
      'description': description,
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
      description: json['description'] as String? ?? '',
    );
  }
}
