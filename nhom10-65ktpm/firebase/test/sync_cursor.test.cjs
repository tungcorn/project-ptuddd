'use strict';
// Issue #20: the app pulls on the server write time `syncedAt` (set with
// serverTimestamp()) instead of the device clock `updatedAt`. Checks on the
// local emulator that the rules accept these writes and that the queries the
// app runs behave as the Dart code assumes. Project demo-*, no cloud traffic.
const { readFileSync } = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { before, after, beforeEach, test } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, getDoc, collection, query, where, getDocs, runTransaction, serverTimestamp, Timestamp,
} = require('firebase/firestore');

let env;
const db = uid => env.authenticatedContext(uid).firestore();
const ids = snap => snap.docs.map(d => d.id).sort();
// The app keeps the cursor in whole milliseconds.
const cursorOf = ts => Timestamp.fromMillis(Math.floor(ts.toMillis()));

before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-singlearn', firestore: {host: '127.0.0.1', port: 8080, rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8')}});
});
beforeEach(async () => env.clearFirestore());
after(async () => { if (env) await env.cleanup(); });

test('a write sent late with an old device clock is found by the server-time cursor', async () => {
  const own = db('alice');
  const events = collection(own, 'users/alice/xpEvents');
  await assertSucceeds(setDoc(doc(own, 'users/alice/xpEvents/b1'), {id: 'b1', xp: 10, updatedAt: 300, syncedAt: serverTimestamp()}));
  const first = (await getDoc(doc(own, 'users/alice/xpEvents/b1'))).get('syncedAt');
  assert.ok(first instanceof Timestamp, 'serverTimestamp resolved by the server');

  // Learnt offline earlier on another device, reaches the server now.
  await assertSucceeds(setDoc(doc(own, 'users/alice/xpEvents/c1'), {id: 'c1', xp: 10, updatedAt: 100, syncedAt: serverTimestamp()}));

  // Old cursor on the device clock skips it; the server-time cursor does not.
  assert.deepEqual(ids(await getDocs(query(events, where('updatedAt', '>', 300)))), []);
  const late = await getDocs(query(events, where('syncedAt', '>=', cursorOf(first))));
  assert.deepEqual(ids(late), ['b1', 'c1'], 'inclusive bound re-reads the cursor instant');
});

test('documents without syncedAt only appear in a whole-collection read', async () => {
  const own = db('alice');
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), 'users/alice/words/legacy'), {id: 'legacy', updatedAt: 1}));
  await setDoc(doc(own, 'users/alice/words/star'), {id: 'star', updatedAt: 2, syncedAt: serverTimestamp()});
  const words = collection(own, 'users/alice/words');
  assert.deepEqual(ids(await getDocs(words)), ['legacy', 'star']);
  assert.deepEqual(ids(await getDocs(query(words, where('syncedAt', '>=', Timestamp.fromMillis(0))))), ['star']);
});

test('the merge transaction is allowed for the owner only', async () => {
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), 'users/alice/songProgress/twinkle'), {id: 'twinkle', listens: 50, updatedAt: 1}));
  const merge = firestore => runTransaction(firestore, async tx => {
    const ref = doc(firestore, 'users/alice/songProgress/twinkle');
    const stored = (await tx.get(ref)).data();
    tx.set(ref, {id: 'twinkle', listens: Math.max(stored.listens, 1), updatedAt: 2, syncedAt: serverTimestamp()});
  });
  await assertSucceeds(merge(db('alice')));
  await assertFails(merge(db('bob')));
  const saved = (await getDoc(doc(db('alice'), 'users/alice/songProgress/twinkle'))).data();
  assert.equal(saved.listens, 50);
  assert.ok(saved.syncedAt instanceof Timestamp);
});
