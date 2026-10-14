import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/models/model_utils.dart';

class InstallationIdentityStore {
  InstallationIdentityStore({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationSupportDirectory;

  static const fileName = 'hesabati-installation-id';
  static final _identityPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final Future<Directory> Function() _directoryProvider;
  String? _installationId;
  Future<String>? _identityFuture;

  bool get hasValidIdentity => _installationId != null;

  Future<String> getOrCreate() {
    final current = _installationId;
    if (current != null) return Future.value(current);

    return _identityFuture ??= _loadOrCreate().then(
      (identity) {
        _installationId = identity;
        _identityFuture = null;
        return identity;
      },
      onError: (Object error, StackTrace stackTrace) {
        _identityFuture = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<String?> getOrCreateSafe() async {
    final current = _installationId;
    if (current != null) return current;

    try {
      return await getOrCreate();
    } on Object catch (error, stackTrace) {
      stderr.writeln(
        'Installation identity unavailable; continuing in local-only mode. '
        '$error\n$stackTrace',
      );
      return null;
    }
  }

  Future<String> _loadOrCreate() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final file = File(path.join(directory.path, fileName));
    if (await file.exists()) return _readIdentity(file);

    final identity = newModelId();
    try {
      await file.create(exclusive: true);
    } on FileSystemException {
      if (await file.exists()) return _readIdentity(file);
      rethrow;
    }
    await file.writeAsString(identity, flush: true);
    return identity;
  }

  Future<String> _readIdentity(File file) async {
    final identity = (await file.readAsString()).trim();
    if (!_identityPattern.hasMatch(identity)) {
      throw FormatException(
        'The installation identity file is invalid: ${file.path}',
      );
    }
    return identity;
  }
}
