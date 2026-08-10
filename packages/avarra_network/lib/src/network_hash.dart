import 'dart:convert';

import 'package:crypto/crypto.dart';

String networkPackageHashFromBytes(List<int> bytes) =>
    sha256.convert(bytes).toString();

String networkPackageHashFromText(String text) {
  return networkPackageHashFromBytes(utf8.encode(text));
}
