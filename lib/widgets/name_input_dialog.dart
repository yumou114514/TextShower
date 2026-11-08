import 'package:flutter/material.dart';

class NameInputDialog extends StatefulWidget {
  const NameInputDialog({
    super.key,
    required this.title,
    required this.validate,
    this.initial = '',
    this.label = '名称',
    this.confirmText = '确定',
  });

  final String title;
  final String initial;
  final String label;
  final String confirmText;
  final String? Function(String value) validate;

  @override
  State<NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<NameInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final message = widget.validate(value);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
