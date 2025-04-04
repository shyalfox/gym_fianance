import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).add(data);
    } catch (e) {
      print("Error adding document: $e");
    }
  }

  Future<QuerySnapshot> getDocuments(String collection) async {
    try {
      return await _firestore.collection(collection).get();
    } catch (e) {
      print("Error fetching documents: $e");
      rethrow;
    }
  }
}
