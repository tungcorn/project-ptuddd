'use strict';
// Optional live smoke test for the explicitly configured SingLearn project.
// Creates its own synthetic accounts/documents and removes them in finally.
// Never runs as part of the emulator rules suite or prints credentials.
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { randomBytes } = require('node:crypto');
const assert = require('node:assert/strict');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut, deleteUser } = require('firebase/auth');
const { getFirestore, doc, setDoc, getDocFromServer, deleteDoc, terminate } = require('firebase/firestore');
const filename = process.argv[2];
if (!filename) throw new Error('Pass the path of the ignored firebase.env.json');
const config = JSON.parse(readFileSync(path.resolve(filename), 'utf8'));
assert.equal(config.FIREBASE_PROJECT_ID, 'singlearn-nhom10-65ktpm', 'Refusing to test an unrelated project');
const options = {apiKey: config.FIREBASE_API_KEY, appId: config.FIREBASE_APP_ID, projectId: config.FIREBASE_PROJECT_ID, messagingSenderId: config.FIREBASE_MESSAGING_SENDER_ID};
const run = randomBytes(6).toString('hex');
const password = randomBytes(20).toString('base64url');
const accounts = [];
const trackedDocs = [];
const apps = [];
async function bounded(promise, label) {
  let timer;
  try {return await Promise.race([promise, new Promise((_, reject) => {timer = setTimeout(() => reject(new Error(`Timeout: ${label}`)), 30000);})]);}
  finally {clearTimeout(timer);}
}
async function main() {
  try {
    for (const label of ['a', 'b']) {
      const app = initializeApp(options, `smoke-${label}-${run}`);
      apps.push(app);
      const auth = getAuth(app);
      const email = `singlearn-smoke-${label}-${run}@example.invalid`;
      const cred = await bounded(createUserWithEmailAndPassword(auth, email, password), 'sign up');
      accounts.push({auth, user: cred.user, email, db: getFirestore(app)});
    }
    console.log('PASS real Firebase email/password registration (two synthetic users)');
    const [a, b] = accounts;
    const wordPath = `users/${a.user.uid}/words/smoke-${run}`;
    const data = {id: `smoke-${run}`, lemma: 'peace', updatedAt: Date.now()};
    trackedDocs.push([a.db, wordPath]);
    await bounded(setDoc(doc(a.db, wordPath), data), 'write own word');
    assert.equal((await bounded(getDocFromServer(doc(a.db, wordPath)), 'read own word')).data().lemma, 'peace');
    console.log('PASS own Firestore word write/read from server');
    await assert.rejects(bounded(getDocFromServer(doc(b.db, wordPath)), 'cross-account read'), e => e.code === 'permission-denied');
    await assert.rejects(bounded(setDoc(doc(b.db, wordPath), {...data, lemma: 'tampered'}), 'cross-account write'), e => e.code === 'permission-denied');
    console.log('PASS cross-account read and write denied');
    const publicPath = `publicProfiles/${a.user.uid}`;
    trackedDocs.push([a.db, publicPath]);
    await bounded(setDoc(doc(a.db, publicPath), {uid: a.user.uid, displayName: 'Synthetic smoke user', userCode: 'SMOKE1'}), 'public profile write');
    const publicData = (await bounded(getDocFromServer(doc(b.db, publicPath)), 'public profile read')).data();
    assert.equal('email' in publicData, false);
    await assert.rejects(bounded(setDoc(doc(a.db, publicPath), {...publicData, email: a.email}), 'private email rejection'), e => e.code === 'permission-denied');
    console.log('PASS public profile excludes email; rules reject email field');
    await signOut(a.auth);
    await bounded(signInWithEmailAndPassword(a.auth, a.email, password), 'sign in again');
    assert.equal((await bounded(getDocFromServer(doc(a.db, wordPath)), 'read after sign in')).data().lemma, 'peace');
    console.log('PASS sign out/sign in retains cloud word');
  } finally {
    const failures = [];
    for (const [db, pathname] of trackedDocs.reverse()) {
      try {await bounded(deleteDoc(doc(db, pathname)), 'cleanup document');}
      catch (e) {failures.push(`document ${pathname}: ${e.code || e.message}`);}
    }
    for (const account of accounts) {
      try {
        if (!account.auth.currentUser) await bounded(signInWithEmailAndPassword(account.auth, account.email, password), 'cleanup sign in');
        await bounded(deleteUser(account.auth.currentUser), 'cleanup account');
      } catch (e) {failures.push(`synthetic account ${account.user.uid}: ${e.code || e.message}`);}
    }
    for (const app of apps) {
      try {await terminate(getFirestore(app)); await deleteApp(app);}
      catch (e) {failures.push(`app cleanup: ${e.code || e.message}`);}
    }
    if (failures.length) throw new Error(`Cleanup incomplete: ${failures.join('; ')}`);
    console.log('PASS synthetic accounts and documents cleaned up');
  }
}
main().catch(e => {console.error(e.message); process.exitCode = 1;});
