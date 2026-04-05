import 'package:flutter/material.dart';

/// A component that provides consistent indentation for nested message structures.
class YamlIndent extends StatelessWidget {
  final int depth;
  final Widget child;
  final double indentWidth;

  const YamlIndent({
    super.key,
    required this.depth,
    required this.child,
    this.indentWidth = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (depth <= 0) return child;

    return Padding(
      padding: EdgeInsets.only(left: depth * indentWidth),
      child: child,
    );
  }
}

/// A compact row representing a single field in the YAML-like layout.
class YamlFieldRow extends StatelessWidget {
  final String label;
  final Widget? value;
  final Widget? leading;
  final VoidCallback? onTapLabel;

  const YamlFieldRow({
    super.key,
    required this.label,
    this.value,
    this.leading,
    this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          GestureDetector(
            onTap: onTapLabel,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (value != null) Expanded(child: value!),
        ],
      ),
    );
  }
}

/// A minimalist toggle for expanding/collapsing sections.
class YamlCollapseToggle extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const YamlCollapseToggle({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Icon(
        isCollapsed ? Icons.chevron_right : Icons.expand_more,
        size: 16,
        color: Colors.grey[600],
      ),
    );
  }
}
