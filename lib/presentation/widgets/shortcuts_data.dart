class ShortcutItem {
  final String title;
  final List<String> keys;

  const ShortcutItem(this.title, this.keys);
}

class ShortcutCategory {
  final String name;
  final List<ShortcutItem> items;

  const ShortcutCategory(this.name, this.items);
}

final List<ShortcutCategory> shortcutCategories = [
  const ShortcutCategory('Tabs', [
    ShortcutItem('Close Tab', ['Ctrl', 'W']),
    ShortcutItem('Force Close Tab', ['Ctrl', 'Alt', 'W']),
    ShortcutItem('Switch To Next Tab', ['Ctrl', 'Tab']),
    ShortcutItem('Switch To Previous Tab', ['Ctrl', 'Shift', 'Tab']),
    ShortcutItem(
        'Switch To Tab at Position', ['Ctrl', '1', 'through', 'Ctrl', '8']),
    ShortcutItem('Switch To Last Tab', ['Ctrl', '9']),
    ShortcutItem('Reopen Last Closed Tab', ['Ctrl', 'Shift', 'T']),
    ShortcutItem('New Runner Tab', ['Ctrl', 'Shift', 'R']),
    ShortcutItem('Search Tabs', ['Ctrl', 'Shift', 'A']),
  ]),
  const ShortcutCategory('Sidebar', [
    ShortcutItem('Search Sidebar', ['Ctrl', 'F']),
    ShortcutItem('Next Item', ['↓']),
    ShortcutItem('Previous Item', ['↑']),
    ShortcutItem('Expand Item', ['→']),
    ShortcutItem('Expand All', ['Alt', '→']),
    ShortcutItem('Collapse Item', ['←']),
    ShortcutItem('Collapse All', ['Alt', '←']),
    ShortcutItem('Select Item', ['↵']),
    ShortcutItem('Rename Item', ['Ctrl', 'E']),
    ShortcutItem('Cut Item', ['Ctrl', 'X']),
    ShortcutItem('Copy Item', ['Ctrl', 'C']),
    ShortcutItem('Paste Item', ['Ctrl', 'V']),
    ShortcutItem('Duplicate Item', ['Ctrl', 'D']),
    ShortcutItem('Delete Item', ['Del']),
  ]),
  const ShortcutCategory('Request', [
    ShortcutItem('Request URL', ['Ctrl', 'L']),
    ShortcutItem('Save Request', ['Ctrl', 'S']),
    ShortcutItem('Save Request As', ['Ctrl', 'Shift', 'S']),
    ShortcutItem('Send Request', ['Ctrl', '↵']),
    ShortcutItem('Send And Download Request', ['Ctrl', 'Alt', '↵']),
    ShortcutItem('Send Request with AI', ['Ctrl', 'Shift', '↵']),
  ]),
  const ShortcutCategory('Interface', [
    ShortcutItem('Zoom In', ['Ctrl', '+']),
    ShortcutItem('Zoom Out', ['Ctrl', '-']),
    ShortcutItem('Reset Zoom', ['Ctrl', '0']),
    ShortcutItem('Toggle Two-Pane View', ['Ctrl', 'Alt', 'V']),
    ShortcutItem('Toggle Left Sidebar', ['Ctrl', '\\']),
    ShortcutItem('Toggle Right Sidebar', ['Ctrl', 'Alt', '\\']),
    ShortcutItem('Toggle Workbench', ['Ctrl', 'Alt', 'M']),
    ShortcutItem('Swap Sidebars', ['Ctrl', 'Alt', 'S']),
    ShortcutItem('Reset Layout', ['Ctrl', 'Alt', 'R']),
    ShortcutItem('Environment Selector', ['Alt', 'E']),
  ]),
  const ShortcutCategory('Window and modals', [
    ShortcutItem('New...', ['Ctrl', 'N']),
    ShortcutItem('New PostLens Window', ['Ctrl', 'Shift', 'N']),
    ShortcutItem('New Console Window', ['Ctrl', 'Alt', 'C']),
    ShortcutItem('Find', ['Ctrl', 'Shift', 'F']),
    ShortcutItem('Import', ['Ctrl', 'O']),
    ShortcutItem('Settings', ['Ctrl', ',']),
    ShortcutItem('Open Shortcut Help', ['Ctrl', '/']),
    ShortcutItem('Search', ['Ctrl', 'K']),
    ShortcutItem('Search in Current Workspace', ['Ctrl', 'Alt', 'K']),
    ShortcutItem('Open Agent Mode', ['Ctrl', 'Alt', 'P']),
    ShortcutItem('Open Vault', ['Ctrl', 'Shift', 'V']),
    ShortcutItem('Cancel Conversation', ['Ctrl', 'C']),
    ShortcutItem('Accept All', ['Ctrl', 'Shift', 'Y']),
    ShortcutItem('Reject All', ['Ctrl', 'Esc']),
  ]),
];
