class EnvironmentVariable {
  final String key;
  final String value;
  final String type; // 'default' or 'secret'
  final bool enabled;

  EnvironmentVariable({
    required this.key,
    required this.value,
    this.type = 'default',
    this.enabled = true,
  });

  EnvironmentVariable copyWith({
    String? key,
    String? value,
    String? type,
    bool? enabled,
  }) {
    return EnvironmentVariable(
      key: key ?? this.key,
      value: value ?? this.value,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'type': type,
        'enabled': enabled,
      };

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) {
    return EnvironmentVariable(
      key: json['key'] ?? '',
      value: json['value'] ?? '',
      type: json['type'] ?? 'default',
      enabled: json['enabled'] ?? true,
    );
  }
}

class EnvironmentModel {
  final String id;
  final String name;
  final String workspaceId;
  final List<EnvironmentVariable> variables;

  EnvironmentModel({
    required this.id,
    required this.name,
    required this.workspaceId,
    this.variables = const [],
  });

  EnvironmentModel copyWith({
    String? id,
    String? name,
    String? workspaceId,
    List<EnvironmentVariable>? variables,
  }) {
    return EnvironmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      workspaceId: workspaceId ?? this.workspaceId,
      variables: variables ?? this.variables,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'workspaceId': workspaceId,
        'variables': variables.map((e) => e.toJson()).toList(),
      };

  factory EnvironmentModel.fromJson(Map<String, dynamic> json) {
    return EnvironmentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      workspaceId: json['workspaceId'] ?? '',
      variables: (json['variables'] as List?)
              ?.map((e) =>
                  EnvironmentVariable.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
