import 'package:flutter/material.dart';
import 'package:protobuf/protobuf.dart';
import 'package:protobuf_message_editor/src/default_editors/well_known/any/any_editor_registry.dart';
import 'package:protobuf_message_editor/src/protobuf_json_editor/protobuf_json_add_field_button.dart';
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
        children: [
          ...widget.controller.jsonMap.keys.map(
            (key) => ProtobufJsonFieldEditor(
              controller: widget.controller,
              jsonKey: key,
              depth: widget.depth,
            ),
          ),
          ProtobufJsonAddFieldButton(
            controller: widget.controller,
            depth: widget.depth,
          ),
        ],
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
          trailing: widget.jsonKey == '@type'
              ? null
              : _buildRemoveButton(widget.jsonKey),
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
              activeThumbColor: Theme.of(context).primaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        trailing: _buildRemoveButton(widget.jsonKey),
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
        trailing: _buildRemoveButton(widget.jsonKey),
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
        trailing: _buildRemoveButton(widget.jsonKey),
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
            trailing: _buildRemoveButton(widget.jsonKey),
          ),
        ),
        if (!_isCollapsed) ...[
          ...value.keys.map((key) {
            final subController = ProtobufJsonEditingController.submessage(
              initialValue: value,
              builderInfo: fieldInfo.subBuilder!().info_,
              typeRegistry: widget.controller.typeRegistry,
              onChanged: (newMap) =>
                  widget.controller.updateField(widget.jsonKey, newMap),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProtobufJsonFieldEditor(
                  controller: subController,
                  jsonKey: key,
                  depth: widget.depth + 1,
                ),
              ],
            );
          }),
          ProtobufJsonAddFieldButton(
            controller: ProtobufJsonEditingController.submessage(
              initialValue: value,
              builderInfo: fieldInfo.subBuilder!().info_,
              typeRegistry: widget.controller.typeRegistry,
              onChanged: (newMap) =>
                  widget.controller.updateField(widget.jsonKey, newMap),
            ),
            depth: widget.depth + 1,
          ),
        ],
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
            trailing: _buildRemoveButton(widget.jsonKey),
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
        if (!_isCollapsed)
          YamlIndent(
            depth: widget.depth + 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                onTap: () async {
                  final newList = List.from(value);
                  dynamic defaultValue = fieldInfo.getDefaultValue(
                    forElement: true,
                  );

                  if (fieldInfo.isAnyField) {
                    final registry = widget.controller.typeRegistry;
                    if (registry is AnyEditorRegistry) {
                      final typeNames = registry.availableMessageNames.toList();
                      final selectedType = await showMenu<String>(
                        context: context,
                        position: _getMenuPosition(context),
                        items: typeNames.map((name) {
                          return PopupMenuItem(
                            value: name,
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                      if (selectedType == null) return;

                      defaultValue = <String, dynamic>{
                        '@type': 'type.googleapis.com/$selectedType',
                      };
                    }
                  }

                  newList.add(defaultValue);
                  widget.controller.updateField(widget.jsonKey, newList);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add element',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRemoveButton(String key) {
    return InkWell(
      onTap: () => widget.controller.removeField(key),
      child: const Icon(Icons.close, size: 14, color: Colors.grey),
    );
  }

  RelativeRect _getMenuPosition(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }
}
