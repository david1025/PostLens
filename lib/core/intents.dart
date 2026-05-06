import 'package:flutter/widgets.dart';

class NewRequestIntent extends Intent {
  const NewRequestIntent();
}

class SaveRequestIntent extends Intent {
  const SaveRequestIntent();
}

class SendRequestIntent extends Intent {
  const SendRequestIntent();
}

class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

class ForceCloseTabIntent extends Intent {
  const ForceCloseTabIntent();
}

class NextTabIntent extends Intent {
  const NextTabIntent();
}

class PrevTabIntent extends Intent {
  const PrevTabIntent();
}

class SettingsIntent extends Intent {
  const SettingsIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class ImportIntent extends Intent {
  const ImportIntent();
}

class FocusRequestUrlIntent extends Intent {
  const FocusRequestUrlIntent();
}

class OpenWorkspaceOverviewIntent extends Intent {
  const OpenWorkspaceOverviewIntent();
}

class OpenBreadcrumbOverviewIntent extends Intent {
  final String? collectionId;
  final List<String> folderPath;
  final int depth;

  const OpenBreadcrumbOverviewIntent({
    required this.collectionId,
    required this.folderPath,
    required this.depth,
  });
}
