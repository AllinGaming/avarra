import 'package:avarra_streaming/avarra_streaming.dart';
import 'package:test/test.dart';

void main() {
  test('streaming package remains server safe', () {
    expect(ChunkStreamingState.values, hasLength(8));
  });
}
