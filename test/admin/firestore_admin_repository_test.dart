import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/admin/data/admin_repository.dart';
import 'package:snackup/features/admin/domain/admin_models.dart';

class _Session extends Fake implements FirebaseAuth {
  _Session(this.user);
  User? user;

  @override
  User? get currentUser => user;
}

class _AdminUser extends Fake implements User {
  @override
  String get uid => 'administrator-1';
}

// Keep Firestore's real in-memory query implementation while observing the
// requested source and injecting a failed read at the repository boundary.
class _ObservedFirestore extends Fake implements FirebaseFirestore {
  _ObservedFirestore(this.delegate);
  final FakeFirebaseFirestore delegate;
  final reads = <MapEntry<String, Source>>[];
  String? failingCollection;
  bool failCommit = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _ObservedCollection(delegate.collection(path), path, this);

  @override
  WriteBatch batch() => failCommit
      ? _RejectedBatch(delegate.batch())
      : delegate.batch();
}

class _RejectedBatch extends Fake implements WriteBatch {
  _RejectedBatch(this.delegate);
  final WriteBatch delegate;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      delegate.set(document, data, options);

  @override
  Future<void> commit() async {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
  }
}

class _ObservedCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _ObservedCollection(this.delegate, this.path, this.database);
  final CollectionReference<Map<String, dynamic>> delegate;
  @override
  final String path;
  final _ObservedFirestore database;

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => _ObservedQuery(
    delegate.orderBy(field, descending: descending),
    path,
    database,
  );

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      delegate.doc(path);
}

class _ObservedQuery extends Fake implements Query<Map<String, dynamic>> {
  _ObservedQuery(this.delegate, this.path, this.database);
  final Query<Map<String, dynamic>> delegate;
  final String path;
  final _ObservedFirestore database;

  @override
  Query<Map<String, dynamic>> limit(int limit) =>
      _ObservedQuery(delegate.limit(limit), path, database);

  @override
  Query<Map<String, dynamic>> startAfterDocument(
    DocumentSnapshot<Object?> documentSnapshot,
  ) => _ObservedQuery(
    delegate.startAfterDocument(documentSnapshot),
    path,
    database,
  );

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    database.reads.add(
      MapEntry(path, options?.source ?? Source.serverAndCache),
    );
    if (database.failingCollection == path) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return delegate.get(options);
  }
}

void main() {
  late FakeFirebaseFirestore database;
  late _Session session;
  late FirebaseAdminRepository repository;
  final recordedAt = DateTime.utc(2026, 10, 7, 15, 30);

  setUp(() {
    database = FakeFirebaseFirestore();
    session = _Session(_AdminUser());
    repository = FirebaseAdminRepository(firestore: database, auth: session);
  });

  Future<void> seedRows(String collection, int count) async {
    final batch = database.batch();
    for (var i = 0; i < count; i++) {
      final id = 'row-${i.toString().padLeft(3, '0')}';
      batch.set(database.collection(collection).doc(id), {
        'name': 'Cafetería $i',
        'businessId': 'business-$i',
        'rating': 4,
        'status': 'in_review',
      });
    }
    await batch.commit();
  }

  group('server report pagination', () {
    test('empty report stays empty until an explicit reset', () async {
      expect(repository.isDemo, isFalse);
      final empty = await repository.loadNextPage();
      expect(empty.businesses, isEmpty);
      expect(empty.reviews, isEmpty);
      expect(empty.followups, isEmpty);
      expect(empty.hasMore, isFalse);

      await database.collection('businesses').doc('new').set({'name': 'Nueva'});
      expect((await repository.loadNextPage()).businesses, isEmpty);
      final refreshed = await repository.loadNextPage(reset: true);
      expect(refreshed.businesses.single.id, 'new');
      expect(refreshed.hasMore, isFalse);
    });

    test('maps current and legacy documents without inventing values', () async {
      await database.collection('businesses').doc('a').set({
        'name': '  Cafetería Central  ',
        'isOpen': true,
      });
      await database.collection('businesses').doc('b').set({
        'businessName': 'Terraza',
        'isOpen': 'yes',
      });
      await database.collection('businesses').doc('c').set({'name': 12});
      await database.collection('reviews').doc('valid').set({
        'businessId': 'a',
        'rating': 2,
        'serviceRating': 3,
        'foodRating': 4,
        'career': ' TI ',
        'group': ' DS02 ',
        'comment': 'Comida fría',
        'createdAt': Timestamp.fromDate(recordedAt),
      });
      await database.collection('reviews').doc('legacy').set({
        'businessId': 10,
        'rating': '5',
        'serviceRating': 7,
        'foodRating': null,
        'comment': 20,
        'createdAt': 'yesterday',
      });
      await database.collection('admin_followups').doc('valid').set({
        'businessId': 'a',
        'status': 'resolved',
        'assignee': 'Coordinación',
        'note': 'Acuerdo registrado',
        'updatedAt': Timestamp.fromDate(recordedAt),
      });
      await database.collection('admin_followups').doc('legacy').set({
        'businessId': 1,
        'status': 'unknown',
        'assignee': false,
        'note': 3,
      });

      final page = await repository.loadNextPage();
      expect(page.businesses.map((business) => business.name), [
        'Cafetería Central',
        'Terraza',
        unknownAcademicValue,
      ]);
      expect(page.businesses.map((business) => business.isOpen), [true, null, null]);
      final current = page.reviews.singleWhere((review) => review.id == 'valid');
      expect(current.businessId, 'a');
      expect(current.rating, 2);
      expect(current.serviceRating, 3);
      expect(current.foodRating, 4);
      expect(current.career, 'TI');
      expect(current.group, 'DS02');
      expect(current.comment, 'Comida fría');
      expect(current.createdAt, recordedAt);
      final legacy = page.reviews.singleWhere((review) => review.id == 'legacy');
      expect(legacy.businessId, isEmpty);
      expect(legacy.rating, isNull);
      expect(legacy.serviceRating, isNull);
      expect(legacy.foodRating, isNull);
      expect(legacy.career, unknownAcademicValue);
      expect(legacy.comment, isEmpty);
      expect(legacy.createdAt, isNull);
      final resolved = page.followups.singleWhere((row) => row.reviewId == 'valid');
      expect(resolved.status, FollowupStatus.resolved);
      expect(resolved.assignee, 'Coordinación');
      expect(resolved.note, 'Acuerdo registrado');
      expect(resolved.updatedAt, recordedAt);
      final pending = page.followups.singleWhere((row) => row.reviewId == 'legacy');
      expect(pending.businessId, isEmpty);
      expect(pending.status, FollowupStatus.pending);
      expect(pending.assignee, isEmpty);
      expect(pending.note, isEmpty);
      expect(pending.updatedAt, isNull);
      expect(page.hasMore, isFalse);
    });

    test('all collections paginate without duplicate or skipped rows', () async {
      for (final name in ['businesses', 'reviews', 'admin_followups']) {
        await seedRows(name, 203);
      }
      final first = await repository.loadNextPage();
      final second = await repository.loadNextPage();
      final exhausted = await repository.loadNextPage();
      expect(first.hasMore, isTrue);
      expect(first.businesses.length, 200);
      expect(first.reviews.length, 200);
      expect(first.followups.length, 200);
      expect(second.hasMore, isFalse);
      expect(second.businesses.length, 3);
      expect(second.reviews.length, 3);
      expect(second.followups.length, 3);
      expect(exhausted.businesses, isEmpty);
      expect(exhausted.reviews, isEmpty);
      expect(exhausted.followups, isEmpty);
      expect(exhausted.hasMore, isFalse);
      expect([...first.businesses, ...second.businesses].map((row) => row.id), [
        for (var i = 0; i < 203; i++) 'row-${i.toString().padLeft(3, '0')}',
      ]);
      expect([...first.reviews, ...second.reviews].map((row) => row.id).toSet().length, 203);
      expect([...first.followups, ...second.followups].map((row) => row.reviewId).toSet().length, 203);
      expect((await repository.loadNextPage(reset: true)).reviews.first.id, 'row-000');
    });

    test('finished collections are not re-read while another has more', () async {
      await seedRows('businesses', 1);
      await seedRows('reviews', 200);
      final observed = _ObservedFirestore(database);
      repository = FirebaseAdminRepository(firestore: observed, auth: session);
      expect((await repository.loadNextPage()).hasMore, isTrue);
      await database.collection('businesses').doc('new').set({'name': 'Nueva'});
      observed.reads.clear();
      final finalPage = await repository.loadNextPage();
      expect(finalPage.businesses, isEmpty);
      expect(finalPage.reviews, isEmpty);
      expect(finalPage.hasMore, isFalse);
      expect(observed.reads.map((read) => read.key), ['reviews']);
      expect(observed.reads.single.value, Source.server);
      expect((await repository.loadNextPage(reset: true)).businesses.length, 2);
    });

    test('a failed read preserves every cursor and never substitutes demo data', () async {
      await seedRows('businesses', 203);
      await seedRows('reviews', 203);
      final observed = _ObservedFirestore(database)..failingCollection = 'reviews';
      repository = FirebaseAdminRepository(firestore: observed, auth: session);
      await expectLater(
        repository.loadNextPage(),
        throwsA(isA<FirebaseException>().having((error) => error.code, 'code', 'unavailable')),
      );
      expect(repository.isDemo, isFalse);
      expect(observed.reads, hasLength(3));
      expect(observed.reads.every((read) => read.value == Source.server), isTrue);
      observed.failingCollection = null;
      final retry = await repository.loadNextPage();
      expect(retry.businesses.first.id, 'row-000');
      expect(retry.reviews.first.id, 'row-000');
      expect(retry.businesses.length, 200);
      expect(retry.reviews.length, 200);
      final tail = await repository.loadNextPage();
      expect(tail.businesses.first.id, 'row-200');
      expect(tail.reviews.first.id, 'row-200');
    });
  });

  group('followup and audit history', () {
    const review = AdminReview(id: 'review-1', businessId: 'cafeteria-1');

    test('missing followup returns the review identity with pending status', () async {
      final followup = await repository.getFollowup(review);
      expect(followup.reviewId, review.id);
      expect(followup.businessId, review.businessId);
      expect(followup.status, FollowupStatus.pending);
      expect(followup.assignee, isEmpty);
      expect(followup.note, isEmpty);
      expect(followup.updatedAt, isNull);
      expect((await repository.getHistory(review.id)).events, isEmpty);
      expect((await repository.getHistory(review.id)).hasMore, isFalse);
    });

    test('saved transitions preserve actor, trimmed text and immutable events', () async {
      for (final status in FollowupStatus.values) {
        await repository.saveFollowup(AdminFollowup(
          reviewId: review.id,
          businessId: review.businessId,
          status: status,
          assignee: '  Coordinación  ',
          note: '  Seguimiento ${status.code}  ',
        ));
        final current = await repository.getFollowup(review);
        expect(current.status, status);
        expect(current.assignee, 'Coordinación');
        expect(current.note, 'Seguimiento ${status.code}');
        expect(current.updatedAt, isNotNull);
        final snapshot = await database.collection('admin_followups').doc(review.id).get();
        expect(snapshot.get('updatedBy'), 'administrator-1');
        expect(snapshot.get('reviewId'), review.id);
        expect(snapshot.get('businessId'), review.businessId);
        final event = await snapshot.reference.collection('history').doc(snapshot.get('eventId') as String).get();
        expect(event.exists, isTrue);
        expect(event.data(), snapshot.data());
      }
      final history = await repository.getHistory(review.id);
      expect(history.events, hasLength(3));
      expect(history.events.map((event) => event.status).toSet(), FollowupStatus.values.toSet());
      expect(history.events.every((event) => event.reviewId == review.id), isTrue);
      expect(history.hasMore, isFalse);
    });

    test('history returns the newest fifty events and signals truncation', () async {
      final ref = database.collection('admin_followups').doc(review.id).collection('history');
      final batch = database.batch();
      for (var i = 0; i < 55; i++) {
        batch.set(ref.doc('event-$i'), {
          'businessId': review.businessId,
          'status': 'in_review',
          'assignee': 'Coordinación',
          'note': 'Evento $i',
          'updatedAt': Timestamp.fromDate(recordedAt.add(Duration(minutes: i))),
        });
      }
      await batch.commit();
      final history = await repository.getHistory(review.id);
      expect(history.events, hasLength(50));
      expect(history.hasMore, isTrue);
      expect(history.events.first.note, 'Evento 54');
      expect(history.events.last.note, 'Evento 5');
      expect(history.events.first.reviewId, review.id);
      expect(history.events.first.status, FollowupStatus.inReview);
      expect(history.events.first.updatedAt, recordedAt.add(const Duration(minutes: 54)));
    });

    test('exactly fifty events are a complete, ordered history', () async {
      final ref = database.collection('admin_followups').doc(review.id).collection('history');
      final batch = database.batch();
      for (var i = 0; i < 50; i++) {
        batch.set(ref.doc('event-$i'), {
          'note': 'Evento $i',
          'updatedAt': Timestamp.fromDate(recordedAt.add(Duration(minutes: i))),
        });
      }
      await batch.commit();
      final history = await repository.getHistory(review.id);
      expect(history.events.length, 50);
      expect(history.hasMore, isFalse);
      expect(history.events.first.note, 'Evento 49');
      expect(history.events.last.note, 'Evento 0');
    });

    test('expired session rejects writes instead of creating unaudited changes', () async {
      session.user = null;
      await expectLater(repository.saveFollowup(const AdminFollowup(
        reviewId: 'review-1', businessId: 'cafeteria-1', assignee: 'QA', note: 'Revisar',
      )), throwsA(isA<StateError>()));
      expect((await database.collection('admin_followups').get()).docs, isEmpty);
    });

    test('a rejected batch propagates failure with no current or history write', () async {
      final observed = _ObservedFirestore(database)..failCommit = true;
      repository = FirebaseAdminRepository(firestore: observed, auth: session);
      await expectLater(
        repository.saveFollowup(const AdminFollowup(
          reviewId: 'review-1',
          businessId: 'cafeteria-1',
          assignee: 'Coordinación',
          note: 'Revisar tiempos',
        )),
        throwsA(isA<FirebaseException>().having(
          (error) => error.code, 'code', 'permission-denied',
        )),
      );
      expect((await database.collection('admin_followups').get()).docs, isEmpty);
      expect((await repository.getHistory(review.id)).events, isEmpty);
      expect(repository.isDemo, isFalse);
    });

    test('empty and excessive text is rejected without any write', () async {
      final invalidText = [
        const ['   ', 'Nota'],
        const ['Responsable', '   '],
        ['a' * 121, 'Nota'],
        ['Responsable', 'n' * 2001],
      ];
      for (final values in invalidText) {
        await expectLater(repository.saveFollowup(AdminFollowup(
          reviewId: review.id,
          businessId: review.businessId,
          assignee: values[0],
          note: values[1],
        )), throwsA(isA<ArgumentError>()));
      }
      expect((await database.collection('admin_followups').get()).docs, isEmpty);
      expect((await repository.getHistory(review.id)).events, isEmpty);
    });

    test('text exactly at the limit is accepted after trimming', () async {
      await repository.saveFollowup(AdminFollowup(
        reviewId: review.id,
        businessId: review.businessId,
        assignee: '  ${'a' * 120}  ',
        note: '  ${'n' * 2000}  ',
      ));
      final saved = await repository.getFollowup(review);
      expect(saved.assignee.length, 120);
      expect(saved.note.length, 2000);
      expect((await repository.getHistory(review.id)).events.length, 1);
    });
  });
}
