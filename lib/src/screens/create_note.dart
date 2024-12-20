import 'dart:convert';
import 'dart:io';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:notes_app_flutter/src/models/note.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class CreateNote extends StatefulWidget {
  const CreateNote({super.key, required this.onNewNoteCreated});

  final Function(Note) onNewNoteCreated;
  @override
  State<CreateNote> createState() => _CreateNoteState();
}

class _CreateNoteState extends State<CreateNote> {
  final titleController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<EditorState> _editorKey = GlobalKey();
  FleatherController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    _initController();
  }

  @override
  void dispose() {
    super.dispose();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
  }

  // Future<void> _pickImage() async {
  //   final picker = ImagePicker();
  //   final image = await picker.pickImage(source: ImageSource.gallery);
  //   if (image != null && _controller != null) {
  //     final selection = _controller!.selection;
  //     _controller!.replaceText(
  //       selection.baseOffset,
  //       selection.extentOffset - selection.baseOffset,
  //       EmbeddableObject('image', inline: false, data: {
  //         'source_type': kIsWeb ? 'url' : 'file',
  //         'source': image.path,
  //       }),
  //     );
  //     _controller!.replaceText(
  //       selection.baseOffset + 1,
  //       0,
  //       '\n',
  //       selection: TextSelection.collapsed(offset: selection.baseOffset + 2),
  //     );
  //   }
  // }

  Future<void> _initController() async {
    try {
      final doc = ParchmentDocument();
      _controller = FleatherController(document: doc);
    } catch (err, st) {
      print('Error initializing the controller: $err\n$st');
      _controller = FleatherController();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Create Note')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          String jsonData =
              jsonEncode(_controller?.document.toDelta().toJson());

          final note = Note(
            id: "",
            title: titleController.text.isNotEmpty
                ? titleController.text
                : "Untitled",

            content: jsonData, // Use the JSON-encoded content
            timestamp: "", // Use the formatted date and time
          );
          widget.onNewNoteCreated(note);
          Navigator.of(context).pop();
        },
        child: const Icon(Icons.save),
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TextFormField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 28),
                  decoration: const InputDecoration(
                      border: InputBorder.none, hintText: "Title"),
                ),
                FleatherToolbar(
                  editorKey: _editorKey,
                  children: [
                    ToggleStyleButton(
                      attribute: ParchmentAttribute.bold,
                      icon: Icons.format_bold,
                      controller: _controller!,
                    ),
                    ToggleStyleButton(
                      attribute: ParchmentAttribute.italic,
                      icon: Icons.format_italic,
                      controller: _controller!,
                    ),
                    ToggleStyleButton(
                      attribute: ParchmentAttribute.underline,
                      icon: Icons.format_underline,
                      controller: _controller!,
                    ),
                    ToggleStyleButton(
                      attribute: ParchmentAttribute.block.bulletList,
                      controller: _controller!,
                      icon: Icons.format_list_bulleted,
                    ),
                    IndentationButton(controller: _controller!),
                    IndentationButton(
                        controller: _controller!, increase: false),
                    UndoRedoButton.undo(controller: _controller!),
                    UndoRedoButton.redo(controller: _controller!),
                  ],
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                Expanded(
                  child: FleatherEditor(
                    controller: _controller!,
                    focusNode: _focusNode,
                    editorKey: _editorKey,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    onLaunchUrl: _launchUrl,
                    maxContentWidth: 800,
                    embedBuilder: _embedBuilder,
                    spellCheckConfiguration: SpellCheckConfiguration(
                        spellCheckService: DefaultSpellCheckService(),
                        misspelledSelectionColor: Colors.red,
                        misspelledTextStyle:
                            DefaultTextStyle.of(context).style),
                  ),
                ),
              ],
            ),
    );
  }

  // Widget _embedBuilder(BuildContext context, EmbedNode node) {
  //   if (node.value.type == 'icon') {
  //     final data = node.value.data;
  //     return Icon(
  //       IconData(int.parse(data['codePoint']), fontFamily: data['fontFamily']),
  //       color: Color(int.parse(data['color'])),
  //       size: 18,
  //     );
  //   }

  //   if (node.value.type == 'image') {
  //     final sourceType = node.value.data['source_type'];
  //     ImageProvider? image;
  //     if (sourceType == 'assets') {
  //       image = AssetImage(node.value.data['source']);
  //     } else if (sourceType == 'file') {
  //       image = FileImage(File(node.value.data['source']));
  //     } else if (sourceType == 'url') {
  //       image = NetworkImage(node.value.data['source']);
  //     }
  //     if (image != null) {
  //       return Padding(
  //         padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
  //         child: image != null
  //             ? Expanded(
  //                 child: Image(
  //                   image: image,
  //                   fit: BoxFit.contain,
  //                 ),
  //               )
  //             : SizedBox.shrink(),
  //       );
  //     }
  //   }

  //   return defaultFleatherEmbedBuilder(context, node);
  // }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == 'image') {
      final sourceType = node.value.data['source_type'];
      ImageProvider? image;

      if (sourceType == 'base64') {
        final base64String = node.value.data['source'];
        try {
          // Ensure valid base64 string is decoded
          final imageBytes = base64Decode(base64String);
          image = MemoryImage(
              imageBytes); // Decode and load image using MemoryImage
        } catch (e) {
          print('Error decoding base64 image: $e');
          return SizedBox.shrink(); // Return empty widget if decoding fails
        }
      } else if (sourceType == 'assets') {
        image = AssetImage(node.value.data['source']);
      } else if (sourceType == 'file') {
        image = FileImage(File(node.value.data['source']));
      } else if (sourceType == 'url') {
        image = NetworkImage(node.value.data['source']);
      }

      // If image is not null, display the image
      if (image != null) {
        return Padding(
          padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
          child: Image(image: image, fit: BoxFit.contain),
        );
      }
    }
    return defaultFleatherEmbedBuilder(context, node);
  }

  void _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri);
    }
  }
}

class ForceNewlineForInsertsAroundInlineImageRule extends InsertRule {
  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();
    final cursorBeforeInlineEmbed = _isInlineImage(target.data);
    final cursorAfterInlineEmbed =
        previous != null && _isInlineImage(previous.data);

    if (cursorBeforeInlineEmbed || cursorAfterInlineEmbed) {
      final delta = Delta()..retain(index);
      if (cursorAfterInlineEmbed && !data.startsWith('\n')) {
        delta.insert('\n');
      }
      delta.insert(data);
      if (cursorBeforeInlineEmbed && !data.endsWith('\n')) {
        delta.insert('\n');
      }
      return delta;
    }
    return null;
  }

  bool _isInlineImage(Object data) {
    if (data is EmbeddableObject) {
      return data.type == 'image' && data.inline;
    }
    if (data is Map) {
      return data[EmbeddableObject.kTypeKey] == 'image' &&
          data[EmbeddableObject.kInlineKey];
    }
    return false;
  }
}
