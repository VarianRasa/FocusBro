import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom Rich Text Editor with formatting toolbar
/// Provides basic rich text editing capabilities using Flutter native widgets
class RichTextEditor extends StatefulWidget {
  final String initialText;
  final Function(String) onTextChanged;
  final String? hintText;
  final bool readOnly;
  final int? maxLines;
  final bool expands;

  const RichTextEditor({
    super.key,
    this.initialText = '',
    required this.onTextChanged,
    this.hintText,
    this.readOnly = false,
    this.maxLines,
    this.expands = false,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  // Formatting state
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  double _fontSize = 16.0;
  TextAlign _textAlign = TextAlign.left;

  // Selection state
  TextSelection _currentSelection = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();

    _controller.addListener(() {
      widget.onTextChanged(_controller.text);
      _updateSelectionState();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateSelectionState() {
    setState(() {
      _currentSelection = _controller.selection;
    });
  }

  void _insertText(String text) {
    final selection = _controller.selection;
    final newText = _controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );

    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + text.length,
    );
  }

  void _formatSelection(String prefix, String suffix) {
    final selection = _controller.selection;
    if (selection.isCollapsed) return;

    final selectedText = _controller.text.substring(
      selection.start,
      selection.end,
    );

    final formattedText = '$prefix$selectedText$suffix';
    final newText = _controller.text.replaceRange(
      selection.start,
      selection.end,
      formattedText,
    );

    _controller.text = newText;
    _controller.selection = TextSelection(
      baseOffset: selection.start,
      extentOffset: selection.start + formattedText.length,
    );
  }

  void _insertList(String listType) {
    final selection = _controller.selection;
    final lines = _controller.text.split('\n');
    final currentLineIndex =
        _controller.text.substring(0, selection.start).split('\n').length - 1;

    if (currentLineIndex < lines.length) {
      final currentLine = lines[currentLineIndex];
      final prefix = listType == 'bullet' ? '• ' : '1. ';

      if (!currentLine.trim().startsWith(prefix.trim())) {
        lines[currentLineIndex] = '$prefix$currentLine';
        _controller.text = lines.join('\n');
        _controller.selection = TextSelection.collapsed(
          offset: selection.start + prefix.length,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Formatting Toolbar
        if (!widget.readOnly) _buildFormattingToolbar(theme),

        // Text Editor
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Start writing...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontSize: _fontSize,
                color: theme.colorScheme.onSurface,
                fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                decoration: TextDecoration.combine([
                  if (_isUnderline) TextDecoration.underline,
                  if (_isStrikethrough) TextDecoration.lineThrough,
                ]),
              ),
              textAlign: _textAlign,
              maxLines: widget.maxLines,
              expands: widget.expands,
              readOnly: widget.readOnly,
              onChanged: (text) {
                // Text change is already handled by controller listener
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormattingToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Text formatting
            _buildToolbarButton(
              icon: Icons.format_bold,
              isActive: _isBold,
              onPressed: () {
                setState(() => _isBold = !_isBold);
                _formatSelection('**', '**');
              },
              tooltip: 'Bold',
            ),
            _buildToolbarButton(
              icon: Icons.format_italic,
              isActive: _isItalic,
              onPressed: () {
                setState(() => _isItalic = !_isItalic);
                _formatSelection('*', '*');
              },
              tooltip: 'Italic',
            ),
            _buildToolbarButton(
              icon: Icons.format_underlined,
              isActive: _isUnderline,
              onPressed: () {
                setState(() => _isUnderline = !_isUnderline);
                _formatSelection('<u>', '</u>');
              },
              tooltip: 'Underline',
            ),
            _buildToolbarButton(
              icon: Icons.format_strikethrough,
              isActive: _isStrikethrough,
              onPressed: () {
                setState(() => _isStrikethrough = !_isStrikethrough);
                _formatSelection('~~', '~~');
              },
              tooltip: 'Strikethrough',
            ),

            const VerticalDivider(width: 16),

            // Text alignment
            _buildToolbarButton(
              icon: Icons.format_align_left,
              isActive: _textAlign == TextAlign.left,
              onPressed: () => setState(() => _textAlign = TextAlign.left),
              tooltip: 'Align Left',
            ),
            _buildToolbarButton(
              icon: Icons.format_align_center,
              isActive: _textAlign == TextAlign.center,
              onPressed: () => setState(() => _textAlign = TextAlign.center),
              tooltip: 'Align Center',
            ),
            _buildToolbarButton(
              icon: Icons.format_align_right,
              isActive: _textAlign == TextAlign.right,
              onPressed: () => setState(() => _textAlign = TextAlign.right),
              tooltip: 'Align Right',
            ),

            const VerticalDivider(width: 16),

            // Lists
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              onPressed: () => _insertList('bullet'),
              tooltip: 'Bullet List',
            ),
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              onPressed: () => _insertList('numbered'),
              tooltip: 'Numbered List',
            ),

            const VerticalDivider(width: 16),

            // Font size
            _buildFontSizeSelector(theme),

            const VerticalDivider(width: 16),

            // Insert options
            _buildToolbarButton(
              icon: Icons.link,
              onPressed: () => _showInsertLinkDialog(),
              tooltip: 'Insert Link',
            ),
            _buildToolbarButton(
              icon: Icons.image,
              onPressed: () => _showInsertImageDialog(),
              tooltip: 'Insert Image',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          foregroundColor: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildFontSizeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<double>(
        value: _fontSize,
        underline: Container(),
        items: [12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0]
            .map((size) => DropdownMenuItem(
                  value: size,
                  child: Text('${size.toInt()}'),
                ))
            .toList(),
        onChanged: (size) {
          if (size != null) {
            setState(() => _fontSize = size);
          }
        },
      ),
    );
  }

  Future<void> _showInsertLinkDialog() async {
    final selectedText = _controller.selection.isCollapsed
        ? ''
        : _controller.text.substring(
            _controller.selection.start,
            _controller.selection.end,
          );
    final formKey = GlobalKey<FormState>();
    var enteredUrl = '';
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert link'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
            onChanged: (value) => enteredUrl = value,
            validator: (value) {
              final uri = Uri.tryParse(value?.trim() ?? '');
              if (uri == null ||
                  !uri.hasAuthority ||
                  !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
                return 'Enter a valid http or https URL';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(enteredUrl.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(enteredUrl.trim());
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    if (url == null || !mounted) return;
    final label = selectedText.isEmpty ? url : selectedText;
    _insertMarkdown('[${label.replaceAll(']', r'\]')}]($url)');
  }

  Future<void> _showInsertImageDialog() async {
    final formKey = GlobalKey<FormState>();
    var imageUrl = '';
    var altText = '';
    final image = await showDialog<({String url, String alt})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert image'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/image.png',
                ),
                onChanged: (value) => imageUrl = value,
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  if (uri == null ||
                      !uri.hasAuthority ||
                      !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
                    return 'Enter a valid http or https URL';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Alt text'),
                onChanged: (value) => altText = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop((
                  url: imageUrl.trim(),
                  alt: altText.trim(),
                ));
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    if (image == null || !mounted) return;
    _insertMarkdown('![${image.alt.replaceAll(']', r'\]')}](${image.url})');
  }

  void _insertMarkdown(String markdown) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final text = _controller.text.replaceRange(start, end, markdown);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + markdown.length),
    );
    _focusNode.requestFocus();
  }
}
