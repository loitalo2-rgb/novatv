import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'local_file_models.dart';

export 'local_file_models.dart';

bool get supportsNativeFilePicker => true;

Future<LocalPickedFile?> pickLocalPlaylistFile() async {
  final completer = Completer<LocalPickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.m3u,.m3u8,text/plain'
    ..style.display = 'none';

  void finish(LocalPickedFile? file) {
    input.remove();
    if (!completer.isCompleted) completer.complete(file);
  }

  input.onChange.listen((_) {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    final reader = web.FileReader();
    reader.onLoadEnd.listen((_) {
      final text = (reader.result as JSString?)?.toDart ?? '';
      finish(LocalPickedFile(name: file.name, content: text));
    });
    reader.addEventListener('error', ((web.Event _) => finish(null)).toJS);
    reader.readAsText(file);
  });

  input.addEventListener(
    'cancel',
    ((web.Event _) => finish(null)).toJS,
  );

  web.document.body?.append(input);
  input.click();

  Timer(const Duration(minutes: 2), () => finish(null));
  return completer.future;
}

Future<LocalPickedFile?> readLocalPlaylistFileAt(String path) async {
  throw const FormatException('No navegador, use o botão "Escolher arquivo".');
}
