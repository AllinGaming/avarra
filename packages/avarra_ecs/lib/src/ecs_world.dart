import 'package:avarra_core/avarra_core.dart';

import 'ecs_error_codes.dart';

/// Fast runtime reference. It is never persisted or sent as canonical identity.
final class EntityHandle {
  const EntityHandle._({required this.index, required this.generation});

  final int index;
  final int generation;

  @override
  bool operator ==(Object other) {
    return other is EntityHandle &&
        index == other.index &&
        generation == other.generation;
  }

  @override
  int get hashCode => Object.hash(index, generation);

  @override
  String toString() => 'EntityHandle($index:$generation)';
}

/// Snapshot of one entity and one component.
final class EntityComponent<T extends Object> {
  const EntityComponent({
    required this.handle,
    required this.entityId,
    required this.component,
  });

  final EntityHandle handle;
  final EntityId entityId;
  final T component;
}

/// Snapshot of one entity and two components.
final class EntityComponents2<A extends Object, B extends Object> {
  const EntityComponents2({
    required this.handle,
    required this.entityId,
    required this.first,
    required this.second,
  });

  final EntityHandle handle;
  final EntityId entityId;
  final A first;
  final B second;
}

typedef EntityComponentVisitor<T extends Object> =
    void Function(EntityComponent<T> entry);

/// Simple, server-safe ECS world used by AVARRA's first vertical slices.
final class EcsWorld {
  EcsWorld({StableIdGenerator? stableIdGenerator})
    : _stableIdGenerator = stableIdGenerator ?? UuidV7StableIdGenerator();

  final StableIdGenerator _stableIdGenerator;
  final List<_EntitySlot> _slots = [];
  final List<int> _freeIndices = [];
  final Map<EntityId, EntityHandle> _handlesById = {};
  final Map<Type, _ComponentStore> _componentStores = {};

  int _activeIterations = 0;
  int _entityCount = 0;

  int get entityCount => _entityCount;

  EntityHandle createEntity({EntityId? entityId}) {
    _ensureStructuralMutationAllowed();
    final stableId = entityId ?? EntityId.generate(_stableIdGenerator);
    if (_handlesById.containsKey(stableId)) {
      throw AvarraException(
        code: EcsErrorCodes.duplicateEntityId,
        message: 'Entity ID already exists in this world.',
        context: {'entityId': stableId.value},
      );
    }

    final int index;
    final _EntitySlot slot;
    if (_freeIndices.isEmpty) {
      index = _slots.length;
      slot = _EntitySlot(generation: 0);
      _slots.add(slot);
    } else {
      index = _freeIndices.removeLast();
      slot = _slots[index];
    }

    slot
      ..alive = true
      ..entityId = stableId;
    final handle = EntityHandle._(index: index, generation: slot.generation);
    _handlesById[stableId] = handle;
    _entityCount += 1;
    return handle;
  }

  void destroyEntity(EntityHandle handle) {
    _ensureStructuralMutationAllowed();
    final slot = _requireAlive(handle);
    _handlesById.remove(slot.entityId);
    for (final store in _componentStores.values) {
      store.values.remove(handle);
    }
    slot
      ..alive = false
      ..entityId = null
      ..generation += 1;
    _freeIndices.add(handle.index);
    _entityCount -= 1;
  }

  bool isAlive(EntityHandle handle) {
    if (handle.index < 0 || handle.index >= _slots.length) {
      return false;
    }
    final slot = _slots[handle.index];
    return slot.alive && slot.generation == handle.generation;
  }

  EntityId entityIdOf(EntityHandle handle) {
    return _requireAlive(handle).entityId!;
  }

  EntityHandle? handleFor(EntityId entityId) => _handlesById[entityId];

  void addComponent<T extends Object>(EntityHandle handle, T component) {
    _ensureStructuralMutationAllowed();
    _requireAlive(handle);
    _addComponentOfType(handle, T, component);
  }

  void replaceComponent<T extends Object>(EntityHandle handle, T component) {
    _ensureStructuralMutationAllowed();
    _requireAlive(handle);
    final store = _componentStores[T];
    if (store == null || !store.values.containsKey(handle)) {
      _throwComponentNotFound(handle, T);
    }
    store.values[handle] = component;
  }

  void removeComponent<T extends Object>(EntityHandle handle) {
    _ensureStructuralMutationAllowed();
    _requireAlive(handle);
    final store = _componentStores[T];
    if (store == null || store.values.remove(handle) == null) {
      _throwComponentNotFound(handle, T);
    }
  }

  bool hasComponent<T extends Object>(EntityHandle handle) {
    _requireAlive(handle);
    return _componentStores[T]?.values.containsKey(handle) ?? false;
  }

  T component<T extends Object>(EntityHandle handle) {
    _requireAlive(handle);
    final value = _componentStores[T]?.values[handle];
    if (value == null) {
      _throwComponentNotFound(handle, T);
    }
    return value as T;
  }

  T? tryComponent<T extends Object>(EntityHandle handle) {
    _requireAlive(handle);
    return _componentStores[T]?.values[handle] as T?;
  }

  int componentCount<T extends Object>() {
    return _componentStores[T]?.values.length ?? 0;
  }

  Set<Type> componentTypesOf(EntityHandle handle) {
    _requireAlive(handle);
    return Set.unmodifiable({
      for (final entry in _componentStores.entries)
        if (entry.value.values.containsKey(handle)) entry.key,
    });
  }

  List<EntityComponent<T>> query<T extends Object>() {
    final store = _componentStores[T];
    if (store == null) {
      return const [];
    }

    return List.unmodifiable([
      for (final entry in store.values.entries)
        if (isAlive(entry.key))
          EntityComponent<T>(
            handle: entry.key,
            entityId: entityIdOf(entry.key),
            component: entry.value as T,
          ),
    ]);
  }

  List<EntityComponents2<A, B>> query2<A extends Object, B extends Object>() {
    final firstStore = _componentStores[A];
    final secondStore = _componentStores[B];
    if (firstStore == null || secondStore == null) {
      return const [];
    }

    return List.unmodifiable([
      for (final entry in firstStore.values.entries)
        if (isAlive(entry.key) && secondStore.values.containsKey(entry.key))
          EntityComponents2<A, B>(
            handle: entry.key,
            entityId: entityIdOf(entry.key),
            first: entry.value as A,
            second: secondStore.values[entry.key]! as B,
          ),
    ]);
  }

  /// Iterates a stable query snapshot while blocking direct structural changes.
  void forEach<T extends Object>(EntityComponentVisitor<T> visitor) {
    final entries = query<T>();
    _activeIterations += 1;
    try {
      for (final entry in entries) {
        visitor(entry);
      }
    } finally {
      _activeIterations -= 1;
    }
  }

  _EntitySlot _requireAlive(EntityHandle handle) {
    if (!isAlive(handle)) {
      throw AvarraException(
        code: EcsErrorCodes.entityNotAlive,
        message: 'Entity handle is stale or not alive.',
        context: {'index': handle.index, 'generation': handle.generation},
      );
    }
    return _slots[handle.index];
  }

  void _ensureStructuralMutationAllowed() {
    if (_activeIterations > 0) {
      throw AvarraException(
        code: EcsErrorCodes.structuralChangeDuringQuery,
        message: 'Structural ECS changes must be deferred during iteration.',
      );
    }
  }

  void _addComponentOfType(
    EntityHandle handle,
    Type componentType,
    Object component,
  ) {
    final store = _componentStores.putIfAbsent(
      componentType,
      () => _ComponentStore(componentType),
    );
    if (store.values.containsKey(handle)) {
      throw AvarraException(
        code: EcsErrorCodes.componentAlreadyExists,
        message: 'Entity already has component $componentType.',
        context: {
          'entityId': entityIdOf(handle).value,
          'componentType': componentType.toString(),
        },
      );
    }
    store.values[handle] = component;
  }

  Never _throwComponentNotFound(EntityHandle handle, Type componentType) {
    throw AvarraException(
      code: EcsErrorCodes.componentNotFound,
      message: 'Entity does not have component $componentType.',
      context: {
        'entityId': entityIdOf(handle).value,
        'componentType': componentType.toString(),
      },
    );
  }
}

/// Result produced after deferred ECS commands are applied.
final class EcsCommandPlaybackResult {
  const EcsCommandPlaybackResult({required this.createdEntities});

  final List<EntityHandle> createdEntities;
}

/// Records ECS mutations for playback at a safe synchronization point.
final class EcsCommandBuffer {
  final List<_EcsCommand> _commands = [];

  int get pendingCommandCount => _commands.length;
  bool get isEmpty => _commands.isEmpty;

  void createEntity({
    EntityId? entityId,
    Iterable<Object> components = const [],
  }) {
    final componentList = List<Object>.unmodifiable(components);
    final componentTypes = componentList.map(
      (component) => component.runtimeType,
    );
    if (componentTypes.toSet().length != componentList.length) {
      throw AvarraException(
        code: EcsErrorCodes.duplicateInitialComponent,
        message: 'A deferred entity cannot contain duplicate component types.',
      );
    }
    _commands.add(
      _CreateEntityCommand(entityId: entityId, components: componentList),
    );
  }

  void destroyEntity(EntityHandle handle) {
    _commands.add(_DestroyEntityCommand(handle));
  }

  void addComponent<T extends Object>(EntityHandle handle, T component) {
    _commands.add(_AddComponentCommand<T>(handle, component));
  }

  void replaceComponent<T extends Object>(EntityHandle handle, T component) {
    _commands.add(_ReplaceComponentCommand<T>(handle, component));
  }

  void removeComponent<T extends Object>(EntityHandle handle) {
    _commands.add(_RemoveComponentCommand<T>(handle));
  }

  EcsCommandPlaybackResult playback(EcsWorld world) {
    world._ensureStructuralMutationAllowed();
    final createdEntities = <EntityHandle>[];
    for (final command in _commands) {
      command.apply(world, createdEntities);
    }
    _commands.clear();
    return EcsCommandPlaybackResult(
      createdEntities: List.unmodifiable(createdEntities),
    );
  }
}

final class _EntitySlot {
  _EntitySlot({required this.generation});

  int generation;
  bool alive = false;
  EntityId? entityId;
}

final class _ComponentStore {
  _ComponentStore(this.componentType);

  final Type componentType;
  final Map<EntityHandle, Object> values = {};
}

sealed class _EcsCommand {
  void apply(EcsWorld world, List<EntityHandle> createdEntities);
}

final class _CreateEntityCommand extends _EcsCommand {
  _CreateEntityCommand({required this.entityId, required this.components});

  final EntityId? entityId;
  final List<Object> components;

  @override
  void apply(EcsWorld world, List<EntityHandle> createdEntities) {
    final handle = world.createEntity(entityId: entityId);
    for (final component in components) {
      world._addComponentOfType(handle, component.runtimeType, component);
    }
    createdEntities.add(handle);
  }
}

final class _DestroyEntityCommand extends _EcsCommand {
  _DestroyEntityCommand(this.handle);

  final EntityHandle handle;

  @override
  void apply(EcsWorld world, List<EntityHandle> createdEntities) {
    world.destroyEntity(handle);
  }
}

final class _AddComponentCommand<T extends Object> extends _EcsCommand {
  _AddComponentCommand(this.handle, this.component);

  final EntityHandle handle;
  final T component;

  @override
  void apply(EcsWorld world, List<EntityHandle> createdEntities) {
    world.addComponent<T>(handle, component);
  }
}

final class _ReplaceComponentCommand<T extends Object> extends _EcsCommand {
  _ReplaceComponentCommand(this.handle, this.component);

  final EntityHandle handle;
  final T component;

  @override
  void apply(EcsWorld world, List<EntityHandle> createdEntities) {
    world.replaceComponent<T>(handle, component);
  }
}

final class _RemoveComponentCommand<T extends Object> extends _EcsCommand {
  _RemoveComponentCommand(this.handle);

  final EntityHandle handle;

  @override
  void apply(EcsWorld world, List<EntityHandle> createdEntities) {
    world.removeComponent<T>(handle);
  }
}
