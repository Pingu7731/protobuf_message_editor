import 'package:flutter/material.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protobuf_message_editor/src/protobuf_json_editor/protobuf_json_controller.dart';
import 'package:protobuf_message_editor/src/protobuf_json_editor/yaml_layout_components.dart';
import 'package:protobuf_message_editor/src/utils/proto_field_type_extensions.dart';

class ProtobufJsonFieldEditor extends StatefulWidget {
  final ProtobufJsonEditingController controller;
  final String jsonKey;
  final int depth;

  const ProtobufJsonFieldEditor({
    super.key,
    required this.controller,
    required this.jsonKey,
    this.depth = 0,
  });

  @override
  State<ProtobufJsonFieldEditor> createState() =>
      _ProtobufJsonFieldEditorState();
}

class _ProtobufJsonFieldEditorState extends State<ProtobufJsonFieldEditor> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.jsonKey.isEmpty) {
      // Special case: Render all fields of the controller's map (naked message)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.controller.jsonMap.keys
            .map(
              (key) => ProtobufJsonFieldEditor(
                controller: widget.controller,
                jsonKey: key,
                depth: widget.depth,
              ),
            )
            .toList(),
      );
    }

    final fieldInfo = widget.controller.getFieldInfo(widget.jsonKey);
    final value = widget.controller.jsonMap[widget.jsonKey];

    if (fieldInfo == null) {
      // Fallback for keys that don't match FieldInfo (e.g., @type in Any)
      return YamlIndent(
        depth: widget.depth,
        child: YamlFieldRow(
          label: widget.jsonKey,
          value: Text(value?.toString() ?? 'null'),
        ),
      );
    }

    final oneofIndex =
        widget.controller.builderInfo.oneofs[fieldInfo.tagNumber];
    final label = oneofIndex != null
        ? '${widget.jsonKey} (oneof)'
        : widget.jsonKey;

    if (fieldInfo.isRepeated) {
      return _buildRepeatedField(context, fieldInfo, value as List, label);
    }

    if (fieldInfo.isBoolField) {
      return _buildBooleanEditor(
        context,
        fieldInfo,
        value as bool? ?? false,
        label,
      );
    }

    if (fieldInfo.isMessageField && !fieldInfo.isScalarMessage) {
      return _buildMessageField(
        context,
        fieldInfo,
        value as Map<String, dynamic>,
        label,
      );
    }

    if (fieldInfo.isEnumField) {
      return _buildEnumEditor(context, fieldInfo, value, label);
    }

    return _buildScalarField(context, fieldInfo, value, label);
  }

  Widget _buildBooleanEditor(
    BuildContext context,
    FieldInfo fieldInfo,
    bool value,
    String label,
  ) {
    return YamlIndent(
      depth: widget.depth,
      child: YamlFieldRow(
        label: label,
        value: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: (newValue) =>
                  widget.controller.updateField(widget.jsonKey, newValue),
              activeColor: Theme.of(context).primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnumEditor(
    BuildContext context,
    FieldInfo fieldInfo,
    dynamic value,
    String label,
  ) {
    // Proto3 JSON Enums can be Strings (names) or Ints (values)
    final currentName = fieldInfo.getEnumName(value);

    return YamlIndent(
      depth: widget.depth,
      child: YamlFieldRow(
        label: label,
        value: SizedBox(
          height: 24,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentName,
              isDense: true,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.blue,
              ),
              items: fieldInfo.enumValues!
                  .map(
                    (e) => DropdownMenuItem(value: e.name, child: Text(e.name)),
                  )
                  .toList(),
              onChanged: (newName) {
                if (newName != null) {
                  widget.controller.updateField(widget.jsonKey, newName);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScalarField(
    BuildContext context,
    FieldInfo fieldInfo,
    dynamic value,
    String label,
  ) {
    return YamlIndent(
      depth: widget.depth,
      child: YamlFieldRow(
        label: label,
        value: SizedBox(
          height: 24,
          child: TextField(
            controller: TextEditingController(text: value?.toString() ?? '')
              ..selection = TextSelection.collapsed(
                offset: value?.toString().length ?? 0,
              ),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'null',
            ),
            onChanged: (newValue) {
              final typedValue = fieldInfo.castString(newValue);
              widget.controller.updateField(widget.jsonKey, typedValue);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageField(
    BuildContext context,
    FieldInfo fieldInfo,
    Map<String, dynamic> value,
    String label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YamlIndent(
          depth: widget.depth,
          child: YamlFieldRow(
            label: label,
            leading: YamlCollapseToggle(
              isCollapsed: _isCollapsed,
              onToggle: () => setState(() => _isCollapsed = !_isCollapsed),
            ),
            onTapLabel: () => setState(() => _isCollapsed = !_isCollapsed),
          ),
        ),
        if (!_isCollapsed)
          ...value.keys.map(
            (key) => ProtobufJsonFieldEditor(
              controller: ProtobufJsonEditingController.submessage(
                initialValue: value,
                builderInfo: fieldInfo.subBuilder!().info_,
                typeRegistry: widget.controller.typeRegistry,
                onChanged: (newMap) =>
                    widget.controller.updateField(widget.jsonKey, newMap),
              ),
              jsonKey: key,
              depth: widget.depth + 1,
            ),
          ),
      ],
    );
  }

  Widget _buildRepeatedField(
    BuildContext context,
    FieldInfo fieldInfo,
    List value,
    String label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        YamlIndent(
          depth: widget.depth,
          child: YamlFieldRow(
            label: label,
            leading: YamlCollapseToggle(
              isCollapsed: _isCollapsed,
              onToggle: () => setState(() => _isCollapsed = !_isCollapsed),
            ),
            onTapLabel: () => setState(() => _isCollapsed = !_isCollapsed),
          ),
        ),
        if (!_isCollapsed)
          ...value.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            if (fieldInfo.isGroupOrMessage && !fieldInfo.isScalarMessage) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YamlIndent(
                    depth: widget.depth + 1,
                    child: YamlFieldRow(label: '[$index]'),
                  ),
                  ProtobufJsonFieldEditor(
                    controller: ProtobufJsonEditingController.submessage(
                      initialValue: item as Map<String, dynamic>,
                      builderInfo: fieldInfo.subBuilder!().info_,
                      typeRegistry: widget.controller.typeRegistry,
                      onChanged: (newItem) {
                        final newList = List.from(value);
                        newList[index] = newItem;
                        widget.controller.updateField(widget.jsonKey, newList);
                      },
                    ),
                    jsonKey: '', // Empty key triggers "naked message" rendering
                    depth: widget.depth + 2,
                  ),
                ],
              );
            }

            return YamlIndent(
              depth: widget.depth + 1,
              child: YamlFieldRow(
                label: '[$index]',
                value: SizedBox(
                  height: 24,
                  child: TextField(
                    controller: TextEditingController(
                      text: item?.toString() ?? '',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onChanged: (newValue) {
                      final newList = List.from(value);
                      newList[index] = fieldInfo.castString(newValue);
                      widget.controller.updateField(widget.jsonKey, newList);
                    },
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
