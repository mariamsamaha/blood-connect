import 'package:isar_community/isar.dart';

part 'cache_entry.g.dart';

@collection
class CacheEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String key;

  late String jsonData;

  late DateTime createdAt;

  late DateTime expiresAt;

  late DateTime staleAt;
}
