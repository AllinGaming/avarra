import 'package:avarra_network/avarra_network.dart';

final class ReplicationCell implements Comparable<ReplicationCell> {
  const ReplicationCell(this.x, this.z);

  final int x;
  final int z;

  @override
  int compareTo(ReplicationCell other) {
    final xComparison = x.compareTo(other.x);
    return xComparison != 0 ? xComparison : z.compareTo(other.z);
  }

  @override
  bool operator ==(Object other) {
    return other is ReplicationCell && x == other.x && z == other.z;
  }

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => '$x,$z';
}

final class NetworkReplicatedComponent {
  const NetworkReplicatedComponent(this.networkEntityId);

  final NetworkEntityId networkEntityId;
}
