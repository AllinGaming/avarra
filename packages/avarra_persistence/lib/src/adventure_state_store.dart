import 'package:avarra_core/avarra_core.dart';

/// Read-only authored adventure state exposed to progress and UI consumers.
abstract interface class AdventureStateView {
  bool? flagValue(EntityId entityId, String key);
  Set<String> inventoryFor(PlayerId playerId);
  bool hasItem(PlayerId playerId, String itemId);
}

/// Mutable authored adventure state shared by offline saves and session hosts.
abstract interface class AdventureStateStore implements AdventureStateView {
  bool setFlag(EntityId entityId, String key, bool value);
  bool addItem(PlayerId playerId, String itemId);
  bool removeItem(PlayerId playerId, String itemId);
}
