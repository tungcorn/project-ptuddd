'use strict';
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { before, after, beforeEach, test } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, collection, query, where, getDocs, deleteDoc } = require('firebase/firestore');
let env;
const profile = uid => ({uid, displayName: 'Learner', userCode: 'ABC123', xp: 0, weekXp: 0, weekKey: '', level: 1, streak: 0});
const friendship = () => ({members: ['alice', 'bob'], requestedBy: 'alice', status: 'pending', updatedAt: 1});
const challenge = () => ({id: 'c1', fromUid: 'alice', fromName: 'Alice', toUid: 'bob', toName: 'Bob', members: ['alice', 'bob'], questions: [{type: 'lyric', songId: 'silent-night', options: ['a', 'b'], answerIndex: 0, startMs: 0, prompt: 'test'}], fromScore: 1, toScore: null, status: 'waiting', createdAt: 1, updatedAt: 1});
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
async function seed(pathname, data) {
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), pathname), data));
}
before(async () => {
  // demo-* and an explicit emulator host ensure no production traffic.
  env = await initializeTestEnvironment({projectId: 'demo-singlearn', firestore: {host: '127.0.0.1', port: 8080, rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8')}});
});
beforeEach(async () => env.clearFirestore());
after(async () => { if (env) await env.cleanup(); });

test('anonymous users cannot read or write learning data or profiles', async () => {
  await seed('users/alice/words/peace', {updatedAt: 1});
  await seed('publicProfiles/alice', profile('alice'));
  await assertFails(getDoc(doc(db(), 'users/alice/words/peace')));
  await assertFails(getDoc(doc(db(), 'publicProfiles/alice')));
  await assertFails(setDoc(doc(db(), 'publicProfiles/alice'), profile('alice')));
});
test('learners can sync their own words and query updates', async () => {
  const own = db('alice');
  await assertSucceeds(setDoc(doc(own, 'users/alice/words/peace'), {id: 'peace', updatedAt: 1}));
  await assertSucceeds(getDocs(query(collection(own, 'users/alice/words'), where('updatedAt', '>', 0))));
});
test('a different account cannot read or overwrite private data', async () => {
  await seed('users/alice/words/peace', {updatedAt: 1});
  await assertFails(getDoc(doc(db('bob'), 'users/alice/words/peace')));
  await assertFails(setDoc(doc(db('bob'), 'users/alice/words/peace'), {updatedAt: 2}));
  await assertFails(getDoc(doc(db('bob'), 'users/alice')));
});
test('only content admins may publish song documents', async () => {
  await assertFails(setDoc(doc(db('alice'), 'songs/song1'), {updatedAt: 1}));
  const admin = env.authenticatedContext('admin', {admin: true}).firestore();
  await assertSucceeds(setDoc(doc(admin, 'songs/song1'), {updatedAt: 1}));
  await assertSucceeds(getDoc(doc(db('alice'), 'songs/song1')));
});
test('public profile works for bootstrap and progress updates without email', async () => {
  const own = db('alice');
  await assertSucceeds(setDoc(doc(own, 'publicProfiles/alice'), {uid: 'alice', displayName: 'Alice', userCode: 'ABC123'}));
  await assertSucceeds(setDoc(doc(own, 'publicProfiles/alice'), profile('alice'), {merge: true}));
  await assertSucceeds(getDocs(query(collection(db('bob'), 'publicProfiles'), where('userCode', '==', 'ABC123'))));
});
test('email and unknown fields cannot be exposed in a public profile', async () => {
  await assertFails(setDoc(doc(db('alice'), 'publicProfiles/alice'), {...profile('alice'), email: 'private@example.invalid'}));
  await assertFails(setDoc(doc(db('alice'), 'publicProfiles/alice'), {...profile('alice'), secret: 'private'}));
});
test('a user cannot impersonate another public profile or set invalid XP', async () => {
  await assertFails(setDoc(doc(db('bob'), 'publicProfiles/alice'), profile('alice')));
  await assertFails(setDoc(doc(db('alice'), 'publicProfiles/alice'), {...profile('alice'), uid: 'bob'}));
  await assertFails(setDoc(doc(db('alice'), 'publicProfiles/alice'), {...profile('alice'), xp: -1}));
});
test('friend request is accepted only by the invited member', async () => {
  await assertSucceeds(setDoc(doc(db('alice'), 'friendships/alice_bob'), friendship()));
  await assertFails(updateDoc(doc(db('alice'), 'friendships/alice_bob'), {status: 'accepted', updatedAt: 2}));
  await assertSucceeds(updateDoc(doc(db('bob'), 'friendships/alice_bob'), {status: 'accepted', updatedAt: 2}));
  await assertFails(updateDoc(doc(db('bob'), 'friendships/alice_bob'), {status: 'accepted', updatedAt: 3}));
});
test('friend request participants and requester cannot be changed', async () => {
  await seed('friendships/alice_bob', friendship());
  await assertFails(updateDoc(doc(db('bob'), 'friendships/alice_bob'), {status: 'accepted', requestedBy: 'bob', updatedAt: 2}));
  await assertFails(updateDoc(doc(db('bob'), 'friendships/alice_bob'), {status: 'accepted', members: ['bob', 'mallory'], updatedAt: 2}));
  await assertFails(setDoc(doc(db('alice'), 'friendships/alice_alice'), {...friendship(), members: ['alice', 'alice']}));
});
test('outsiders cannot read or delete friendships; participants may delete', async () => {
  await seed('friendships/alice_bob', friendship());
  await assertFails(getDoc(doc(db('mallory'), 'friendships/alice_bob')));
  await assertFails(deleteDoc(doc(db('mallory'), 'friendships/alice_bob')));
  await assertSucceeds(deleteDoc(doc(db('bob'), 'friendships/alice_bob')));
});
test('challenge can be created only by sender for accepted friends', async () => {
  await assertFails(setDoc(doc(db('alice'), 'challenges/c1'), challenge()));
  await seed('friendships/alice_bob', {...friendship(), status: 'accepted'});
  await assertFails(setDoc(doc(db('mallory'), 'challenges/c1'), challenge()));
  await assertSucceeds(setDoc(doc(db('alice'), 'challenges/c1'), challenge()));
});
test('challenge members must agree with sender and receiver', async () => {
  await seed('friendships/alice_bob', {...friendship(), status: 'accepted'});
  await assertFails(setDoc(doc(db('alice'), 'challenges/c1'), {...challenge(), members: ['alice', 'mallory']}));
});
test('only receiver may complete challenge once with bounded score', async () => {
  await seed('challenges/c1', challenge());
  await assertFails(updateDoc(doc(db('alice'), 'challenges/c1'), {status: 'completed', toScore: 1, updatedAt: 2}));
  await assertFails(updateDoc(doc(db('bob'), 'challenges/c1'), {status: 'completed', toScore: 99, updatedAt: 2}));
  await assertSucceeds(updateDoc(doc(db('bob'), 'challenges/c1'), {status: 'completed', toScore: 1, updatedAt: 2}));
  await assertFails(updateDoc(doc(db('bob'), 'challenges/c1'), {status: 'completed', toScore: 0, updatedAt: 3}));
});
test('receiver cannot tamper with sender, questions, members or sender score', async () => {
  await seed('challenges/c1', challenge());
  for (const mutation of [{fromUid: 'bob'}, {questions: []}, {members: ['bob', 'mallory']}, {fromScore: 0}]) {
    await assertFails(updateDoc(doc(db('bob'), 'challenges/c1'), {...mutation, status: 'completed', toScore: 1, updatedAt: 2}));
  }
});
test('outsiders cannot read challenges and receiver can decline', async () => {
  await seed('challenges/c1', challenge());
  await assertFails(getDoc(doc(db('mallory'), 'challenges/c1')));
  await assertSucceeds(updateDoc(doc(db('bob'), 'challenges/c1'), {status: 'declined', toScore: null, updatedAt: 2}));
});
