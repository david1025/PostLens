enum FilterField {
  all,
  application,
  domain,
  method,
  statusCode,
  resourceType,
}

enum FilterOperator {
  contains,
  equals,
  notEquals,
  notContains,
}

class CaptureFilterCondition {
  final FilterField field;
  final FilterOperator operator;
  final String value;

  const CaptureFilterCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  CaptureFilterCondition copyWith({
    FilterField? field,
    FilterOperator? operator,
    String? value,
  }) {
    return CaptureFilterCondition(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }
}
