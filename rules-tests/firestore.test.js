import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, beforeEach, test } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from "firebase/firestore";

let environment;

function message(overrides = {}) {
  return {
    schemaVersion: 2,
    text: "A fictional test message",
    authorUid: "alice",
    authorName: "Alice Tester",
    createdAt: serverTimestamp(),
    editedAt: null,
    ...overrides,
  };
}

before(async () => {
  const rules = await readFile(
    new URL("../firestore.rules", import.meta.url),
    "utf8",
  );

  environment = await initializeTestEnvironment({
    projectId: "demo-message-board",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules,
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();

  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, "users/alice"), {
      uid: "alice",
      firstName: "Alice",
      lastName: "Tester",
      role: "member",
      registrationDateTime: Timestamp.fromMillis(1000),
    });

    await setDoc(doc(db, "users/bob"), {
      uid: "bob",
      firstName: "Bob",
      lastName: "Tester",
      role: "member",
      registrationDateTime: Timestamp.fromMillis(1000),
    });

    await setDoc(doc(db, "messages/original"), message({
      createdAt: Timestamp.fromMillis(1000),
    }));
  });
});

after(async () => {
  if (environment) await environment.cleanup();
});

test("signed-out users cannot read messages", async () => {
  const db = environment.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(db, "messages/original")));
});

test("another user cannot update the author's message", async () => {
  const db = environment.authenticatedContext("bob").firestore();

  await assertFails(updateDoc(doc(db, "messages/original"), {
    text: "An unauthorized edit",
    editedAt: serverTimestamp(),
  }));
});

test("another user cannot delete the author's message", async () => {
  const db = environment.authenticatedContext("bob").firestore();

  await assertFails(deleteDoc(doc(db, "messages/original")));
});

test("a user cannot create a message with a forged author UID", async () => {
  const db = environment.authenticatedContext("bob").firestore();

  await assertFails(setDoc(doc(db, "messages/forged"), message()));
});

test("a user cannot create a message with another author's name", async () => {
  const db = environment.authenticatedContext("bob").firestore();

  await assertFails(setDoc(doc(db, "messages/forged-name"), message({
    authorUid: "bob",
    authorName: "Alice Tester",
  })));
});

test("the correct author can create, read, edit, and delete", async () => {
  const db = environment.authenticatedContext("alice").firestore();
  const ref = doc(db, "messages/own-message");

  await assertSucceeds(setDoc(ref, message()));

  const created = await assertSucceeds(getDoc(ref));
  assert.equal(created.data().text, "A fictional test message");
  assert.ok(created.data().createdAt instanceof Timestamp);

  await assertSucceeds(updateDoc(ref, {
    text: "An updated fictional message",
    editedAt: serverTimestamp(),
  }));

  const edited = await assertSucceeds(getDoc(ref));
  assert.equal(edited.data().text, "An updated fictional message");
  assert.ok(edited.data().editedAt instanceof Timestamp);

  await assertSucceeds(deleteDoc(ref));

  const deleted = await assertSucceeds(getDoc(ref));
  assert.equal(deleted.exists(), false);
});

test("signed-in users can read another member's board message", async () => {
  const db = environment.authenticatedContext("bob").firestore();

  await assertSucceeds(getDoc(doc(db, "messages/original")));
});

test("a user's private profile cannot be read by another user", async () => {
  const db = environment.authenticatedContext("bob").firestore();

  await assertFails(getDoc(doc(db, "users/alice")));
});

test("an author cannot transfer message ownership", async () => {
  const db = environment.authenticatedContext("alice").firestore();

  await assertFails(updateDoc(doc(db, "messages/original"), {
    authorUid: "bob",
    editedAt: serverTimestamp(),
  }));
});