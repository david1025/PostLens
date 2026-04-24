class WorkspaceModel {
  final String id;
  final String name;
  final String description;

  WorkspaceModel({
    required this.id,
    required this.name,
    this.description = '',
  });

  WorkspaceModel copyWith({
    String? name,
    String? description,
  }) {
    return WorkspaceModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
    );
  }
}
