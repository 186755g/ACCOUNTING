import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class BackupTransport {
  Future<void> exportBackup(File backup, {required String subject});

  Future<File?> importBackup();

  Future<void> releaseImport(File backup);
}

class LocalBackupTransport implements BackupTransport {
  LocalBackupTransport();

  @override
  Future<void> exportBackup(File backup, {required String subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(backup.path)], subject: subject),
    );
  }

  @override
  Future<File?> importBackup() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['hdb'],
    );
    if (files.isEmpty) return null;
    final filePath = files.single.path;
    if (filePath != null && filePath.isNotEmpty) return File(filePath);

    final temporaryDirectory = await getTemporaryDirectory();
    final imported = File(
      path.join(
        temporaryDirectory.path,
        'hesabati-import-${DateTime.now().microsecondsSinceEpoch}.hdb',
      ),
    );
    final sink = imported.openWrite();
    try {
      await sink.addStream(files.single.xFile.openRead());
      await sink.close();
      _temporaryImports.add(imported.path);
      return imported;
    } catch (_) {
      await sink.close();
      if (await imported.exists()) await imported.delete();
      rethrow;
    }
  }

  final Set<String> _temporaryImports = {};

  @override
  Future<void> releaseImport(File backup) async {
    if (!_temporaryImports.remove(backup.path)) return;
    if (await backup.exists()) await backup.delete();
  }
}
