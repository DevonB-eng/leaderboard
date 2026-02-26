const { setGlobalOptions } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = getFirestore();

// Limit concurrent function instances for cost control
setGlobalOptions({ maxInstances: 10 });

/**
 * Runs every 30 minutes.
 * For each group, reads screentime/{uid} for each member,
 * embeds usernames, sorts by totalBadMinutes desc,
 * and writes a single leaderboard doc to groups/{groupId}/leaderboard/current.
 */
exports.aggregateLeaderboards = onSchedule("every 30 minutes", async (event) => {
  const groupsSnapshot = await db.collection("groups").get();

  if (groupsSnapshot.empty) {
    console.log("No groups found.");
    return;
  }

  const tasks = groupsSnapshot.docs.map(async (groupDoc) => {
    const groupId = groupDoc.id;
    const groupData = groupDoc.data();
    const memberIds = groupData.memberIds || [];

    if (memberIds.length === 0) {
      console.log(`Group ${groupId} has no members, skipping.`);
      return;
    }

    const entries = [];

    for (const uid of memberIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      const username = userDoc.exists ? (userDoc.data().username ?? "Unknown") : "Unknown";

      const screentimeDoc = await db.collection("screentime").doc(uid).get();

      if (!screentimeDoc.exists) {
        entries.push({
          uid,
          username,
          totalBadMinutes: 0,
          badAppsBreakdown: [],
          lastUpdated: null,
        });
        continue;
      }

      const st = screentimeDoc.data();
      entries.push({
        uid,
        username,
        totalBadMinutes: st.totalBadMinutes ?? 0,
        badAppsBreakdown: st.badAppsBreakdown ?? [],
        lastUpdated: st.lastUpdated ?? null,
      });
    }

    entries.sort((a, b) => b.totalBadMinutes - a.totalBadMinutes);

    await db
      .collection("groups")
      .doc(groupId)
      .collection("leaderboard")
      .doc("current")
      .set({
        lastUpdated: FieldValue.serverTimestamp(),
        entries,
      });

    console.log(`Updated leaderboard for group ${groupId} (${entries.length} members)`);
  });

  await Promise.all(tasks);
});