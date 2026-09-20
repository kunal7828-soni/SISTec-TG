import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/tg.dart';
import '../tg_repository.dart';

class FirestoreTgRepository implements TgRepository {
  FirestoreTgRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tgs');

  @override
  Stream<List<Tg>> watchTgs({bool activeOnly = false}) {
    Query<Map<String, dynamic>> query = _collection.orderBy('name');
    if (activeOnly) query = query.where('active', isEqualTo: true);
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(Tg.fromFirestore).toList(),
        );
  }

  @override
  Future<Tg?> getTgById(String tgId) async {
    final doc = await _collection.doc(tgId).get();
    return doc.exists ? Tg.fromFirestore(doc) : null;
  }

  @override
  Future<void> addTg(Tg tg) async {
    await _collection.doc(tg.tgId).set({
      ...tg.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateTg(Tg tg) async {
    await _collection.doc(tg.tgId).update({
      ...tg.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setActive(String tgId, bool active) async {
    await _collection.doc(tgId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteTg(String tgId) async {
    await _collection.doc(tgId).delete();
  }
}
