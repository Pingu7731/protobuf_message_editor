import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/well_known_types/google/protobuf/any.pb.dart';
import 'package:protobuf_message_editor/protobuf_message_editor.dart';

import '../example/lib/generated/example_message.pb.dart';

void main() {
  final registry = AnyEditorRegistry([
    ExampleSubmessage.getDefault(),
    AnotherExampleSubmessage.getDefault(),
  ]);

  group('AnyEditingController', () {
    test('initializes with unpacked message if data is not empty', () {
      final submessage = ExampleSubmessage(someString: 'hello');
      final any = Any.pack(submessage);
      final controller = AnyEditingController(data: any, registry: registry);

      expect(
        controller.selectedType,
        'protobuf_message_editor_example.ExampleSubmessage',
      );
      expect(controller.unpackedMessage, isA<ExampleSubmessage>());
      expect(
        (controller.unpackedMessage as ExampleSubmessage).someString,
        'hello',
      );
      expect(controller.hasUnsavedChanges, isFalse);
    });

    test('onTypeChanged updates selectedType and unpackedMessage', () {
      final any = Any();
      final controller = AnyEditingController(data: any, registry: registry);

      controller.onTypeChanged(
        'protobuf_message_editor_example.ExampleSubmessage',
      );

      expect(
        controller.selectedType,
        'protobuf_message_editor_example.ExampleSubmessage',
      );
      expect(controller.unpackedMessage, isA<ExampleSubmessage>());
      expect(controller.hasUnsavedChanges, isTrue);
    });

    test('save updates underlying data', () {
      final any = Any();
      final controller = AnyEditingController(data: any, registry: registry);

      controller.onTypeChanged(
        'protobuf_message_editor_example.ExampleSubmessage',
      );
      (controller.unpackedMessage as ExampleSubmessage).someString = 'saved';
      controller.save();

      expect(controller.hasUnsavedChanges, isFalse);

      final unpacked = ExampleSubmessage.create();
      unpacked.mergeFromBuffer(any.value);
      expect(unpacked.someString, 'saved');
      expect(
        any.typeUrl.endsWith(
          'protobuf_message_editor_example.ExampleSubmessage',
        ),
        isTrue,
      );
    });
  });

  testWidgets('AnyEditorWidget uses provided controller', (
    WidgetTester tester,
  ) async {
    final any = Any();
    final controller = AnyEditingController(data: any, registry: registry);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnyEditorWidget(
            registry: registry,
            data: any,
            controller: controller,
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButton<String>), findsOneWidget);

    // Change type via controller
    controller.onTypeChanged(
      'protobuf_message_editor_example.ExampleSubmessage',
    );
    await tester.pump();

    // Verify the dropdown shows the selected type
    expect(
      find.text('protobuf_message_editor_example.ExampleSubmessage'),
      findsWidgets,
    );
    expect(controller.hasUnsavedChanges, isTrue);

    // Verify save button state
    final saveButton = find.byType(ElevatedButton);
    expect(saveButton, findsOneWidget);

    // Find the save icon which should be orange
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, Colors.orange);
    expect(icon.icon, Icons.save_as);
  });
}
