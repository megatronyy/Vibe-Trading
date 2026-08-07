import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Write [content] to a temporary file named [fileName] and share it as a
/// real file (not plain text) via the system share sheet.
Future<void> shareFile(String content, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: fileName,
  );
}
