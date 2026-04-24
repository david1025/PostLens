import 'package:flutter/material.dart';
import 'environment_editor_pane.dart';

class EnvironmentCreationPane extends StatelessWidget {
  final VoidCallback onSaved;

  const EnvironmentCreationPane({super.key, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return EnvironmentEditorPane(onSaved: onSaved);
  }
}
