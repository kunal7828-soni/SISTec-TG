import '../models/tg.dart';

abstract interface class TgRepository {
  Stream<List<Tg>> watchTgs({bool activeOnly = false});
  Future<Tg?> getTgById(String tgId);
  Future<void> addTg(Tg tg);
  Future<void> updateTg(Tg tg);
  Future<void> setActive(String tgId, bool active);
  Future<void> deleteTg(String tgId);
}
