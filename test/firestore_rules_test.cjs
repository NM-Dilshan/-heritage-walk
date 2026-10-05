// Runs only against local emulators, with Node's built-in fetch/assert.
const assert = require('node:assert/strict');
const project = 'demo-heritagewalk';
const root = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents`;
let assertions = 0;
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, encode(value)]));
}
function encode(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  return { mapValue: { fields: fields(value) } };
}
async function account(email) {
  const response = await fetch(`http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'LocalTest123!', returnSecureToken: true })
  });
  assert.equal(response.status, 200);
  const result = await response.json();
  return { uid: result.localId, token: result.idToken };
}
async function request(method, path, token, body) {
  const response = await fetch(root + path, { method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: response.status, body: await response.text() };
}
async function check(method, path, token, body, expected, label) {
  const result = await request(method, path, token, body);
  assert.equal(result.status, expected, `${label}: ${result.body}`);
  assertions++;
  return result;
}
function document(path, data) { return { name: `projects/${project}/databases/(default)/documents/${path}`, fields: fields(data) }; }
async function main() {
  const a = await account('a@heritagewalk.test'), b = await account('b@heritagewalk.test');
  const profile = { id: a.uid, uid: a.uid, role: 'user', fullName: 'User A', email: 'a@heritagewalk.test', phone: '', bio: '', photoPath: null, createdAt: '2026-10-05', updatedAt: '2026-10-05' };
  await check('PATCH', `/users/${a.uid}`, a.token, { fields: fields(profile) }, 200, 'Own profile create');
  await check('GET', `/users/${a.uid}`, null, null, 403, 'Unauthenticated profile denied');
  await check('GET', `/users/${a.uid}`, b.token, null, 403, 'Foreign profile read denied');
  await check('PATCH', `/users/${a.uid}`, b.token, { fields: fields(profile) }, 403, 'Foreign profile edit denied');
  await check('PATCH', `/users/${a.uid}`, a.token, { fields: fields({ ...profile, fullName: 'Updated A' }) }, 200, 'Own profile update');
  for (const collection of ['favorites', 'itineraries', 'guideNotes', 'supportRequests', 'preferences']) {
    const id = collection === 'preferences' ? 'settings' : 'record';
    const data = collection === 'preferences' ? { selectedLanguageCode: 'ta' } : { id, subject: 'Request', status: 'open' };
    const path = `/users/${a.uid}/${collection}/${id}`;
    await check('PATCH', path, a.token, { fields: fields(data) }, 200, `${collection} create`);
    await check('GET', path, a.token, null, 200, `${collection} restore`);
    await check('GET', path, b.token, null, 403, `${collection} isolation read`);
    await check('PATCH', path, b.token, { fields: fields(data) }, 403, `${collection} isolation write`);
    await check('PATCH', path, a.token, { fields: fields({ ...data, ...(collection === 'preferences' ? { selectedLanguageCode: 'si' } : { status: 'resolved' }) }) }, 200, `${collection} update`);
    await check('DELETE', path, b.token, null, 403, `${collection} foreign delete denied`);
    await check('DELETE', path, a.token, null, 200, `${collection} own delete`);
  }
  await check('PATCH', `/users/${a.uid}/preferences/settings`, a.token, { fields: fields({ selectedLanguageCode: 'invalid' }) }, 403, 'Invalid language rejected');
  const code = 'HW-ABCDEF1234567890';
  const leader = { id: a.uid, name: 'User A', avatarPath: null, isLeader: true, isSharingLocation: false };
  const member = { id: b.uid, name: 'User B', avatarPath: null, isLeader: false, isSharingLocation: false };
  const group = { id: 'testgroup', name: 'Heritage Friends', leaderId: a.uid, leaderName: 'User A', inviteCode: code,
    members: { [a.uid]: leader }, memberIds: [a.uid], createdAt: '2026-10-05', updatedAt: '2026-10-05', destinationPlaceId: 'sigiriya', destinationName: 'Sigiriya', trackingEnabled: true };
  await check('POST', ':commit', a.token, { writes: [
    { update: document('groups/testgroup', group) },
    { update: document(`groupInvites/${code}`, { groupId: 'testgroup', leaderId: a.uid }) }
  ] }, 200, 'Atomic group and invite creation');
  await check('GET', '/groups/testgroup', b.token, null, 403, 'Nonmember group read denied');
  await check('POST', ':runQuery', b.token, { structuredQuery: { from: [{ collectionId: 'groupInvites' }] } }, 403, 'Invite enumeration denied');
  await check('GET', `/groupInvites/${code}`, b.token, null, 200, 'Code lookup allowed');
  const joined = { ...group, members: { [a.uid]: leader, [b.uid]: member }, memberIds: [a.uid, b.uid], joinCode: code };
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields({ ...joined, joinCode: 'HW-WRONG12345678901' }) }, 403, 'Wrong invite rejected');
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields(joined) }, 200, 'Self join with code');
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields(joined) }, 200, 'Duplicate join idempotent');
  await check('GET', '/groups/testgroup', b.token, null, 200, 'Joined member reads group');
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields({ ...joined, name: 'Hijacked' }) }, 403, 'Nonleader rename denied');
  await check('DELETE', '/groups/testgroup', b.token, null, 403, 'Nonleader delete denied');
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields({ ...joined, members: { [b.uid]: member }, memberIds: [b.uid] }) }, 403, 'Leader removal denied');
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields({ ...joined, members: { [a.uid]: { ...leader, isSharingLocation: true }, [b.uid]: member } }) }, 403, 'Another member sharing update denied');
  const shared = { ...joined, members: { [a.uid]: leader, [b.uid]: { ...member, isSharingLocation: true } } };
  await check('PATCH', '/groups/testgroup', b.token, { fields: fields(shared) }, 200, 'Own sharing update');
  await check('PATCH', '/groups/testgroup', a.token, { fields: fields({ ...shared, leaderId: b.uid }) }, 403, 'Leader reassignment denied');
  await check('PATCH', '/groups/testgroup', a.token, { fields: fields({ ...shared, members: { [a.uid]: leader, [b.uid]: { ...member, isSharingLocation: false } } }) }, 403, 'Leader cannot alter another real member sharing');
  await check('PATCH', '/groups/testgroup', a.token, { fields: fields({ ...group, joinCode: code, memberOperationId: b.uid }) }, 200, 'Leader removes nonleader');
  await check('GET', '/groups/testgroup', b.token, null, 403, 'Removed member loses access');
  await check('POST', ':commit', a.token, { writes: [
    { delete: document('groups/testgroup', {}).name }, { delete: document(`groupInvites/${code}`, {}).name }
  ] }, 200, 'Leader deletes group and invite');
  // Part 8: keep the complete original 59 checks, then verify catalog/admin rules.
  assert.equal(assertions, 59, 'Original Part 7 security assertions retained');
  await check('PATCH', `/users/${a.uid}`, a.token, { fields: fields({ ...profile, role: 'admin' }) }, 403, 'Self promotion denied');
  await check('PATCH', `/users/${a.uid}`, a.token, { fields: fields({ ...profile, role: null }) }, 403, 'Role removal denied');
  const c = await account('admin@heritagewalk.test');
  const adminProfile = { ...profile, id: c.uid, uid: c.uid, fullName: 'Admin', role: 'admin' };
  await check('PATCH', `/users/${c.uid}`, c.token, { fields: fields(adminProfile) }, 403, 'Registration cannot claim admin');
  await check('PATCH', `/users/${c.uid}`, c.token, { fields: fields({ ...adminProfile, role: 'user' }) }, 200, 'Registration starts as user');
  // The emulator-only owner token simulates trusted Console bootstrap. Never used in Flutter.
  await check('PATCH', `/users/${c.uid}`, 'owner', { fields: fields(adminProfile) }, 200, 'Trusted admin bootstrap');
  await check('PATCH', `/users/${c.uid}`, c.token, { fields: fields({ ...adminProfile, fullName: 'Edited Admin' }) }, 200, 'Admin profile edit preserves role');
  await check('PATCH', `/users/${c.uid}`, c.token, { fields: fields({ ...adminProfile, role: 'user' }) }, 403, 'Client cannot change protected admin role');
  await check('GET', `/users/${a.uid}`, c.token, null, 403, 'Admin does not bypass private user isolation');
  const place = { id: 'admin-place', name: 'Test Fortress', category: 'Forts', city: 'Kandy', district: 'Kandy', description: 'Historic place',
    isActive: true, latitude: 7.2, longitude: 80.6, createdBy: c.uid, updatedBy: c.uid };
  const placeCommit = (data, create = false) => ({ writes: [{ update: document('places/admin-place', data),
    updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
      ...(create ? [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }] : [])] }] });
  await check('POST', ':commit', a.token, placeCommit(place, true), 403, 'User place creation denied');
  await check('POST', ':commit', null, placeCommit(place, true), 403, 'Anonymous place creation denied');
  await check('POST', ':commit', c.token, placeCommit(place, true), 200, 'Admin creates place with server audit');
  const read = await check('GET', '/places/admin-place', c.token, null, 200, 'Admin reads place');
  const createdAt = JSON.parse(read.body).fields.createdAt;
  const updateCommit = data => { const body = placeCommit(data); body.writes[0].update.fields.createdAt = createdAt; return body; };
  await check('GET', '/places/admin-place', a.token, null, 200, 'Normal user reads active place');
  await check('GET', '/places/admin-place', null, null, 403, 'Anonymous active read denied');
  const query = active => ({ structuredQuery: { from: [{ collectionId: 'places' }], ...(active ? { where: { fieldFilter: {
    field: { fieldPath: 'isActive' }, op: 'EQUAL', value: { booleanValue: true } } } } : {}) } });
  await check('POST', ':runQuery', a.token, query(true), 200, 'User active catalog query');
  await check('POST', ':runQuery', a.token, query(false), 403, 'Unfiltered user catalog query denied');
  await check('POST', ':runQuery', c.token, query(false), 200, 'Admin full catalog query');
  await check('POST', ':commit', a.token, updateCommit({ ...place, name: 'Hijacked' }), 403, 'User place edit denied');
  await check('POST', ':commit', null, updateCommit({ ...place, name: 'Hijacked' }), 403, 'Anonymous place edit denied');
  await check('POST', ':commit', c.token, updateCommit({ ...place, latitude: 91 }), 403, 'Invalid latitude rejected');
  await check('POST', ':commit', c.token, updateCommit({ ...place, longitude: -181 }), 403, 'Invalid longitude rejected');
  await check('POST', ':commit', c.token, updateCommit({ ...place, createdBy: a.uid }), 403, 'Original creator immutable');
  await check('POST', ':commit', c.token, updateCommit({ ...place, updatedBy: a.uid }), 403, 'Updater must be current admin');
  await check('POST', ':commit', c.token, updateCommit({ ...place, name: 'Updated Fortress', isActive: false }), 200, 'Admin edit and deactivate');
  await check('GET', '/places/admin-place', a.token, null, 403, 'User inactive read denied');
  await check('GET', '/places/admin-place', c.token, null, 200, 'Admin inactive read allowed');
  await check('DELETE', '/places/admin-place', a.token, null, 403, 'User delete denied');
  await check('DELETE', '/places/admin-place', null, null, 403, 'Anonymous delete denied');
  await check('POST', ':commit', c.token, updateCommit(place), 200, 'Admin reactivates place');
  await check('DELETE', '/places/admin-place', c.token, null, 200, 'Admin deletes place');
  await check('PATCH', `/users/${c.uid}`, 'owner', { fields: fields({ ...adminProfile, role: 'user' }) }, 200, 'Trusted revocation');
  await check('POST', ':commit', c.token, placeCommit(place, true), 403, 'Revoked admin writes denied');
  assert.equal(assertions, 91, 'Original Part 7–8 assertions retained');
  await check('PATCH', `/users/${c.uid}`, 'owner', { fields: fields(adminProfile) }, 200, 'Restore trusted admin for Part 8.1 fixtures');
  // Synthetic test phone; never seeded into the application or presented as a real service.
  const contact = { id: 'test-contact', name: 'Emulator Test Contact', category: 'other', phoneNumber: '+12025550123',
    description: 'Synthetic test only', priority: 10, isActive: true, isVerified: true, createdBy: c.uid, updatedBy: c.uid };
  const contactCommit = (data, create = false) => ({ writes: [{ update: document('emergencyContacts/test-contact', data),
    updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
      ...(create ? [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }] : [])] }] });
  await check('POST', ':commit', a.token, contactCommit(contact, true), 403, 'Normal contact create denied');
  await check('POST', ':commit', null, contactCommit(contact, true), 403, 'Anonymous contact create denied');
  await check('POST', ':commit', c.token, contactCommit(contact, true), 200, 'Admin contact create');
  const contactRead = await check('GET', '/emergencyContacts/test-contact', c.token, null, 200, 'Admin contact read');
  const contactCreatedAt = JSON.parse(contactRead.body).fields.createdAt;
  const contactUpdate = data => { const body = contactCommit(data); body.writes[0].update.fields.createdAt = contactCreatedAt; return body; };
  await check('GET', '/emergencyContacts/test-contact', a.token, null, 200, 'User active verified contact read');
  await check('GET', '/emergencyContacts/test-contact', null, null, 403, 'Anonymous contact read denied');
  const contactsQuery = (active, verified) => ({ structuredQuery: { from: [{ collectionId: 'emergencyContacts' }],
    ...((active || verified) ? { where: { compositeFilter: { op: 'AND', filters: [
      ...(active ? [{ fieldFilter: { field: { fieldPath: 'isActive' }, op: 'EQUAL', value: { booleanValue: true } } }] : []),
      ...(verified ? [{ fieldFilter: { field: { fieldPath: 'isVerified' }, op: 'EQUAL', value: { booleanValue: true } } }] : [])] } } } : {}) } });
  await check('POST', ':runQuery', a.token, contactsQuery(true, true), 200, 'User active verified query');
  await check('POST', ':runQuery', a.token, contactsQuery(true, false), 403, 'Query missing verification constraint denied');
  await check('POST', ':runQuery', a.token, contactsQuery(false, false), 403, 'User full contact enumeration denied');
  await check('POST', ':runQuery', c.token, contactsQuery(false, false), 200, 'Admin full contact catalog');
  await check('POST', ':commit', a.token, contactUpdate({ ...contact, name: 'Hijacked' }), 403, 'User contact update denied');
  await check('POST', ':commit', null, contactUpdate(contact), 403, 'Anonymous contact update denied');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, phoneNumber: 'tel:123;evil' }), 403, 'Unsafe phone rejected');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, priority: 1.5 }), 403, 'Fractional priority rejected');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, priority: 1000 }), 403, 'Out of range priority rejected');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, createdBy: a.uid }), 403, 'Contact creator immutable');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, updatedBy: a.uid }), 403, 'Contact updater must be admin UID');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, isVerified: false }), 200, 'Admin unverifies contact');
  await check('GET', '/emergencyContacts/test-contact', a.token, null, 403, 'Unverified contact hidden from normal user');
  await check('GET', '/emergencyContacts/test-contact', c.token, null, 200, 'Admin reads unverified contact');
  await check('POST', ':commit', c.token, contactUpdate({ ...contact, isActive: false }), 200, 'Admin deactivates verified contact');
  await check('GET', '/emergencyContacts/test-contact', a.token, null, 403, 'Inactive contact hidden from normal user');
  await check('GET', '/emergencyContacts/test-contact', c.token, null, 200, 'Admin reads inactive contact');
  await check('POST', ':commit', c.token, contactUpdate(contact), 200, 'Admin reactivates contact');
  await check('DELETE', '/emergencyContacts/test-contact', a.token, null, 403, 'User contact delete denied');
  await check('DELETE', '/emergencyContacts/test-contact', null, null, 403, 'Anonymous contact delete denied');
  await check('DELETE', '/emergencyContacts/test-contact', c.token, null, 200, 'Admin contact delete');
  await check('POST', ':commit', c.token, contactCommit({ ...contact, id: 'wrong' }, true), 403, 'Contact identity mismatch rejected');
  await check('POST', ':commit', c.token, contactCommit({ ...contact, category: 'wrong' }, true), 403, 'Contact category rejected');

  assert.equal(assertions, 121, 'All Part 7?8.1 assertions retained');
  // Part 8.2: reviews; parent setup uses the emulator-only trusted owner fixture.
  await check('PATCH', '/places/review-place', 'owner', { fields: fields({ ...place, id: 'review-place', isActive: true }) }, 200, 'Review parent fixture');
  const review = { id: a.uid, placeId: 'review-place', userId: a.uid, userDisplayName: 'Traveler A', rating: 4, comment: 'A thoughtful historical visit.' };
  const reviewPath = `/places/review-place/reviews/${a.uid}`;
  const reviewCommit = (data, create = true, path = reviewPath) => ({ writes: [{ update: document(path.slice(1), data),
    updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }, ...(create ? [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }] : [])] }] });
  await check('POST', ':commit', null, reviewCommit(review), 403, 'Anonymous review creation denied');
  await check('POST', ':commit', b.token, reviewCommit(review), 403, 'Impersonated review creation denied');
  await check('POST', ':commit', a.token, reviewCommit({ ...review, userId: b.uid }), 403, 'Spoofed userId denied');
  await check('POST', ':commit', a.token, reviewCommit({ ...review, id: b.uid }), 403, 'Spoofed review id denied');
  await check('POST', ':commit', a.token, reviewCommit({ ...review, placeId: 'other' }), 403, 'Spoofed place id denied');
  for (const rating of [0, 6, 2.5, '5']) await check('POST', ':commit', a.token, reviewCommit({ ...review, rating }), 403, 'Invalid rating denied');
  for (const comment of ['', ' \n ', 'x'.repeat(1001)]) await check('POST', ':commit', a.token, reviewCommit({ ...review, comment }), 403, 'Invalid comment denied');
  await check('POST', ':commit', a.token, reviewCommit({ ...review, userDisplayName: 'email@example.com' }), 403, 'Email display name denied');
  await check('POST', ':commit', a.token, reviewCommit({ ...review, averageRating: 5 }), 403, 'Spoofed aggregate denied');
  await check('POST', ':commit', a.token, reviewCommit(review), 200, 'User A creates own UID review');
  const ownReview = await check('GET', reviewPath, a.token, null, 200, 'User reads own review');
  const originalReviewCreated = JSON.parse(ownReview.body).fields.createdAt;
  const editReview = (data, path = reviewPath) => { const body = reviewCommit(data, false, path); body.writes[0].update.fields.createdAt = originalReviewCreated; return body; };
  await check('GET', reviewPath, b.token, null, 200, 'Other signed-in user reads public review');
  await check('GET', reviewPath, null, null, 403, 'Anonymous review read denied');
  await check('POST', '/places/review-place:runQuery', a.token, { structuredQuery: { from: [{ collectionId: 'reviews' }] } }, 200, 'Signed-in per-place review query');
  await check('POST', ':runQuery', a.token, { structuredQuery: { from: [{ collectionId: 'reviews', allDescendants: true }] } }, 403, 'Normal user global moderation query denied');
  await check('POST', ':runQuery', c.token, { structuredQuery: { from: [{ collectionId: 'reviews', allDescendants: true }] } }, 200, 'Admin collection-group moderation query');
  await check('POST', ':commit', b.token, editReview({ ...review, rating: 1 }), 403, 'Other user cannot edit A review');
  await check('DELETE', reviewPath, b.token, null, 403, 'Other user cannot delete A review');
  await check('POST', ':commit', c.token, editReview({ ...review, comment: 'Admin edit' }), 403, 'Admin cannot edit user review');
  await check('POST', ':commit', a.token, editReview({ ...review, userId: b.uid }), 403, 'Review ownership immutable');
  await check('POST', ':commit', a.token, editReview({ ...review, placeId: 'other' }), 403, 'Review parent immutable');
  await check('POST', ':commit', a.token, reviewCommit({ ...review, rating: 2 }), 403, 'Creation timestamp cannot be replaced on duplicate create');
  await check('POST', ':commit', a.token, editReview({ ...review, rating: 2, comment: 'Updated\nexperience' }), 200, 'Owner edits rating/comment with creation audit preserved');
  await check('GET', reviewPath, a.token, null, 200, 'Edited review readable');
  await check('DELETE', reviewPath, null, null, 403, 'Anonymous delete denied');
  await check('DELETE', reviewPath, a.token, null, 200, 'Owner deletes review');
  await check('POST', ':commit', a.token, reviewCommit(review), 200, 'Owner can recreate after delete');
  await check('DELETE', reviewPath, c.token, null, 200, 'Trusted admin moderates review');
  await check('POST', ':commit', a.token, reviewCommit(review), 200, 'Review recreated for parent lifecycle');
  await check('PATCH', '/places/review-place', 'owner', { fields: fields({ ...place, id: 'review-place', isActive: false }) }, 200, 'Parent deactivation fixture');
  await check('POST', ':commit', b.token, reviewCommit({ ...review, id: b.uid, userId: b.uid }, true, `/places/review-place/reviews/${b.uid}`), 403, 'Inactive parent cannot receive new review');
  const savedReview = await request('GET', reviewPath, a.token);
  const inactiveEdit = editReview(review); inactiveEdit.writes[0].update.fields.createdAt = JSON.parse(savedReview.body).fields.createdAt;
  await check('POST', ':commit', a.token, inactiveEdit, 403, 'Inactive parent review cannot be edited');
  await check('DELETE', '/places/review-place', 'owner', null, 200, 'Deleted parent fixture');
  await check('GET', reviewPath, a.token, null, 200, 'Missing parent review reads safely');
  await check('POST', ':runQuery', c.token, { structuredQuery: { from: [{ collectionId: 'reviews', allDescendants: true }] } }, 200, 'Admin can find orphan reviews');
  await check('POST', ':commit', b.token, reviewCommit({ ...review, id: b.uid, userId: b.uid }, true, `/places/review-place/reviews/${b.uid}`), 403, 'Deleted parent cannot receive review');
  await check('DELETE', reviewPath, a.token, null, 200, 'Owner can delete orphan review');
  console.log(`Firestore emulator: ${assertions} authorization/persistence assertions passed; no production data touched.`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
