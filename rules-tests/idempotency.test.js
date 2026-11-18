import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, test } from "node:test";

import { initializeTestEnvironment } from "@firebase/rules-unit-testing";

import {
  collection,
  doc,
  getDocFromServer,
  getDocsFromServer,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
} from "firebase/firestore";

let environment;

async function postOnce(db, draft) {
  const ref = doc(db, "messages", draft.id);

  await runTransaction(db, async (transaction) => {
    const existing = await transaction.get(ref);

    if (existing.exists()) {
      const data = existing.data();

      if (
        data.schemaVersion !== 2 ||
        data.text !== draft.text ||
        data.authorUid !== draft.authorUid ||
        data.authorName !== draft.authorName
      ) {
        throw new Error("Message collision.");
      }

      return;
    }

    transaction.set(ref, {
      schemaVersion: 2,
      text: draft.text,
      authorUid: draft.authorUid,
      authorName: draft.authorName,
      createdAt: serverTimestamp(),
      editedAt: null,
    });
  });
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

after(async () => {
  if (environment) await environment.cleanup();
});

test("concurrent duplicate posts and retry leave one unchanged message", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/duplicate-author"), {
      uid: "duplicate-author",
      firstName: "Duplicate",
      lastName: "Tester",
      role: "member",
      registrationDateTime: Timestamp.fromMillis(1000),
    });
  });

  const firstClient = environment
    .authenticatedContext("duplicate-author")
    .firestore();

  const secondClient = environment
    .authenticatedContext("duplicate-author")
    .firestore();

  const ref = doc(collection(firstClient, "messages"));
  const draft = Object.freeze({
    id: ref.id,
    text: `Duplicate test ${ref.id}`,
    authorUid: "duplicate-author",
    authorName: "Duplicate Tester",
  });

  await Promise.all([
    postOnce(firstClient, draft),
    postOnce(secondClient, draft),
  ]);

  const original = await getDocFromServer(ref);
  assert.equal(original.exists(), true);
  assert.ok(original.data().createdAt instanceof Timestamp);
  assert.equal(original.data().text, draft.text);

  await postOnce(firstClient, draft);

  const afterRetry = await getDocFromServer(ref);
  assert.deepEqual(afterRetry.data(), original.data());

  const messages = await getDocsFromServer(
    collection(firstClient, "messages"),
  );

  const matchingMessages = messages.docs.filter(
    (message) => message.data().text === draft.text,
  );

  assert.equal(matchingMessages.length, 1);
  assert.equal(matchingMessages[0].id, draft.id);

  console.log("PASS: two concurrent calls and one retry.");
  console.log(`Document: messages/${draft.id}`);
  console.log(`Matching message count: ${matchingMessages.length}`);
  console.log("Original server timestamp preserved.");

  await assert.rejects(
    postOnce(secondClient, {
      ...draft,
      text: "A different payload at the same ID",
    }),
    /Message collision/,
  );

  const afterCollision = await getDocFromServer(ref);
  assert.deepEqual(afterCollision.data(), original.data());

  console.log("PASS: different payload rejected; original preserved.");
});