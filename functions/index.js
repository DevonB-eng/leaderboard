const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const bcryptjs = require("bcryptjs");
const admin = require("firebase-admin");

admin.initializeApp();
const db = getFirestore();

setGlobalOptions({ maxInstances: 10 });

const SALT_ROUNDS = 10;

// Returns today's date string in PST/PDT as YYYY-MM-DD.
// en-CA locale naturally returns YYYY-MM-DD format.
// Uses America/Los_Angeles so DST is handled automatically.
function getTodayPST() {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'America/Los_Angeles' });
}

function getActiveApps(appVotes, totalMembers) {
  if (!appVotes || Object.keys(appVotes).length === 0) return null;
  const activeApps = new Set();
  for (const [appName, voters] of Object.entries(appVotes)) {
    if (voters.length > totalMembers / 2) {
      activeApps.add(appName);
    }
  }
  return activeApps;
}

// ===== aggregateLeaderboards =====
// Triggered whenever a screentime document is written.
// Rebuilds the leaderboard for the affected user's group immediately,
// eliminating the race condition that existed with the old scheduled approach.
exports.aggregateLeaderboards = onDocumentWritten(
  "screentime/{userId}",
  async (event) => {
    const userId = event.params.userId;

    const afterData = event.data.after.data();
    if (!afterData || !afterData.badAppsBreakdown || afterData.badAppsBreakdown.length === 0) return;


    // Find which group this user belongs to
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists || !userDoc.data().groupId) return;
    const groupId = userDoc.data().groupId;

    const today = getTodayPST();
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const groupData = groupDoc.data();
    const memberIds = groupData.memberIds || [];
    const appVotes = groupData.appVotes || {};
    const activeApps = getActiveApps(appVotes, memberIds.length);

    // Fetch all member screentime and user docs in parallel
    const [screentimeDocs, userDocs] = await Promise.all([
      Promise.all(memberIds.map((uid) => db.collection("screentime").doc(uid).get())),
      Promise.all(memberIds.map((uid) => db.collection("users").doc(uid).get())),
    ]);

    // Build leaderboard entries
    const entries = memberIds.map((uid, i) => {
      const username = userDocs[i].exists
        ? (userDocs[i].data().username ?? "Unknown")
        : "Unknown";

      if (!screentimeDocs[i].exists) {
        return { uid, username, totalBadMinutes: 0, badAppsBreakdown: [], lastUpdated: null };
      }

      const st = screentimeDocs[i].data();
      const rawBreakdown = st.badAppsBreakdown ?? [];
      const filteredBreakdown = activeApps === null
        ? rawBreakdown
        : rawBreakdown.filter((item) => activeApps.has(item.appName));
      const totalBadMinutes = filteredBreakdown.reduce(
        (sum, item) => sum + (item.minutes ?? 0), 0
      );

      return {
        uid,
        username,
        totalBadMinutes,
        badAppsBreakdown: filteredBreakdown,
        lastUpdated: st.lastUpdated ?? null,
      };
    });

    entries.sort((a, b) => b.totalBadMinutes - a.totalBadMinutes);

    // Write current leaderboard
    await db.collection("groups").doc(groupId)
      .collection("leaderboard").doc("current")
      .set({ lastUpdated: FieldValue.serverTimestamp(), entries });

    // Write personal daily history for the triggering user
    const st = event.data.after.data();
    if (st) {
      const rawBreakdown = st.badAppsBreakdown ?? [];
      const filteredBreakdown = activeApps === null
        ? rawBreakdown
        : rawBreakdown.filter((item) => activeApps.has(item.appName));
      const totalBadMinutes = filteredBreakdown.reduce(
        (sum, item) => sum + (item.minutes ?? 0), 0
      );
      await db.collection("screentime").doc(userId)
        .collection("history").doc(today)
        .set({ totalBadMinutes, recordedAt: FieldValue.serverTimestamp() });
    }

    // Write group average daily history
    const membersWithData = entries.filter((e) => e.lastUpdated !== null);
    if (membersWithData.length > 0) {
      const averageBadMinutes = membersWithData.reduce(
        (sum, e) => sum + e.totalBadMinutes, 0
      ) / membersWithData.length;
      await db.collection("groups").doc(groupId)
        .collection("history").doc(today)
        .set({ averageBadMinutes, recordedAt: FieldValue.serverTimestamp() });
    }
  }
);

// ===== createGroup =====
// Callable function — hashes the password server-side before writing to Firestore.
// The plaintext password never touches the database.
exports.createGroup = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to create a group.");
  }

  const { name, nameLower, password } = request.data;
  if (!name || !nameLower || !password) {
    throw new HttpsError("invalid-argument", "name, nameLower, and password are required.");
  }

  // Check for duplicate name (case-insensitive)
  const existing = await db.collection("groups")
    .where("nameLower", "==", nameLower)
    .limit(1)
    .get();
  if (!existing.empty) {
    throw new HttpsError("already-exists", "A group with that name already exists.");
  }

  const passwordHash = await bcryptjs.hash(password, SALT_ROUNDS);
  const userId = request.auth.uid;
  const groupRef = db.collection("groups").doc();

  await groupRef.set({
    name,
    nameLower,
    passwordHash,
    memberIds: [userId],
    createdAt: FieldValue.serverTimestamp(),
    createdBy: userId,
  });

  await db.collection("users").doc(userId).set(
    { groupId: groupRef.id },
    { merge: true }
  );

  return { groupId: groupRef.id };
});

// ===== joinGroup =====
// Callable function — compares the entered password against the stored hash server-side.
// The hash never leaves the server.
exports.joinGroup = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to join a group.");
  }

  const { groupId, password } = request.data;
  if (!groupId || !password) {
    throw new HttpsError("invalid-argument", "groupId and password are required.");
  }

  const groupDoc = await db.collection("groups").doc(groupId).get();
  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "Group not found.");
  }

  const groupData = groupDoc.data();
  const passwordHash = groupData.passwordHash;
  if (!passwordHash) {
    throw new HttpsError("failed-precondition", "Group has no password set.");
  }

  const match = await bcryptjs.compare(password, passwordHash);
  if (!match) {
    throw new HttpsError("permission-denied", "Incorrect password.");
  }

  const userId = request.auth.uid;
  await db.collection("groups").doc(groupId).update({
    memberIds: FieldValue.arrayUnion(userId),
  });
  await db.collection("users").doc(userId).set(
    { groupId },
    { merge: true }
  );

  // Return the group data so Flutter can populate state immediately
  // without needing a second round-trip fetch.
  return {
    groupId,
    groupName: groupData.name,
    memberIds: [...(groupData.memberIds ?? []), userId],
    appVotes: groupData.appVotes ?? {},
  };
});

// ===== leaveGroup =====
// Callable function — removes the user from the group and deletes the group
// document entirely if they were the last member.
exports.leaveGroup = onCall({ invoker: "public" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to leave a group.");
  }

  const { groupId } = request.data;
  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId is required.");
  }

  const userId = request.auth.uid;
  const groupRef = db.collection("groups").doc(groupId);
  const userRef = db.collection("users").doc(userId);

  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "Group not found.");
  }

  const memberIds = groupDoc.data().memberIds ?? [];
  const remainingMembers = memberIds.filter((id) => id !== userId);

  if (remainingMembers.length === 0) {
    // Last member leaving — delete the group document entirely
    await groupRef.delete();
  } else {
    // Others remain — just remove this user from memberIds
    await groupRef.update({
      memberIds: FieldValue.arrayRemove(userId),
    });
  }

  // Remove groupId from the user's own document either way
  await userRef.update({ groupId: FieldValue.delete() });

  return { deleted: remainingMembers.length === 0 };
});