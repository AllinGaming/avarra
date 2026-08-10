import 'package:avarra_core/avarra_core.dart';

import 'persistence_error_codes.dart';
import 'save_models.dart';
import 'save_store.dart';
import 'world_save_codec.dart';

final class SaveRepository {
  SaveRepository({required this.store, WorldSaveCodec? codec})
    : codec = codec ?? WorldSaveCodec();

  final SaveStore store;
  final WorldSaveCodec codec;

  Future<WorldSave?> load(SaveId saveId) async {
    final source = await store.read(saveId);
    if (source == null) {
      return null;
    }
    final save = codec.decode(source);
    if (save.saveId != saveId) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Stored save identity does not match its slot.',
        context: {
          'requestedSaveId': saveId.value,
          'storedSaveId': save.saveId.value,
        },
      );
    }
    return save;
  }

  Future<void> save(WorldSave save) {
    return store.writeAtomic(save.saveId, codec.encodeCanonical(save));
  }
}
