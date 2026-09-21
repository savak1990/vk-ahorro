import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

String generateOperationId() {
  return _uuid.v4();
} 