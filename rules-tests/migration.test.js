import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, test } from "node:test";

import { initializeTestEnvironment } from "@firebase/rules-unit-testing";

import {
  collection,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  setDoc,
  Timestamp,
} from "firebase/firestore";

let environment;

function migrationPatch(data) {
  if (data.schemaVersion === 2) return null;

  if (data.schemaVersion !== 1) {
    throw new Error("Unsupported message version.");
  }

  const text = data.text ?? data.body;

  if (
    typeof text !== "string" ||
    text.trim().length === 0 ||
    text.length > 1000 ||
    typeof data.authorUid !== "string" ||
    data.authorUid.length === 0 ||
    typeof data.authorName !== "string" ||
    data.authorName.trim().length === 0 ||
    !(data.createdAt instanceof Timestamp) ||
    (data.editedAt !== undefined &&
      data.editedAt !== null &&
      !(data.editedAt instanceof Timestamp))
  ) {
    throw new Error("Incomplete v1 message.");
  }

  return {
    schemaVersion: 2,
    text,
    editedAt: data.editedAt ?? null,
  };
}

async function migrateMessage(db, id) {
  const ref = doc(db, "messages", id);

  return runTransaction(db, async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists()) throw new Error("Message does not exist.");

    const patch = migrationPatch(snapshot.data());
    if (patch === null) return false;

    transaction.update(ref, patch);
    return true;
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

test("v1 messages migrate without losing original data", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const fixtures = [
      {
        id: "migration-v1-body",
        data: {
          schemaVersion: 1,
          body: "Welcome to the old message board.",
          authorUid: "migration-alice",
          authorName: "Alice Tester",
          createdAt: Timestamp.fromMillis(1000),
        },
      },
      {
        id: "migration-v1-edited",
        data: {
          schemaVersion: 1,
          text: "An older message with an edit.",
          authorUid: "migration-bob",
          authorName: "Bob Tester",
          createdAt: Timestamp.fromMillis(2000),
          editedAt: Timestamp.fromMillis(3000),
        },
      },
    ];

    for (const fixture of fixtures) {
      const ref = doc(db, "messages", fixture.id);
      await setDoc(ref, fixture.data);

      const before = (await getDoc(ref)).data();
      console.log("BEFORE", fixture.id, JSON.stringify(before));

      assert.equal(await migrateMessage(db, fixture.id), true);

      const after = (await getDoc(ref)).data();
      console.log("AFTER", fixture.id, JSON.stringify(after));

      assert.equal(after.schemaVersion, 2);
      assert.equal(after.text, before.text ?? before.body);
      assert.equal(after.authorUid, before.authorUid);
      assert.equal(after.authorName, before.authorName);
      assert.ok(after.createdAt.isEqual(before.createdAt));

      for (const [key, value] of Object.entries(before)) {
        if (key !== "schemaVersion") {
          assert.deepEqual(after[key], value);
        }
      }

      if (before.editedAt === undefined) {
        assert.equal(after.editedAt, null);
      } else {
        assert.ok(after.editedAt.isEqual(before.editedAt));
      }

      assert.equal(await migrateMessage(db, fixture.id), false);
      assert.deepEqual((await getDoc(ref)).data(), after);
    }

    const messages = await getDocs(collection(db, "messages"));
    for (const fixture of fixtures) {
      assert.equal(
        messages.docs.filter((message) => message.id === fixture.id).length,
        1,
      );
    }
  });
});

test("a malformed v1 message is preserved and reported", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const id = "migration-v1-incomplete";
    const ref = doc(db, "messages", id);

    await setDoc(ref, {
      schemaVersion: 1,
      body: "This record is missing its author.",
      createdAt: Timestamp.fromMillis(4000),
    });

    const before = (await getDoc(ref)).data();

    await assert.rejects(
      migrateMessage(db, id),
      /Incomplete v1 message/,
    );

    assert.deepEqual((await getDoc(ref)).data(), before);
    console.log("PRESERVED", id, "Incomplete v1 message.");
  });
});