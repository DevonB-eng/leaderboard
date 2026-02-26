const { setGlobalOptions } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = getFirestore();

setGlobalOptions({ maxInstances: 10 });

// ===== timezone helper =====
// PST = -8, PDT = -7 (update this when daylight saving changes)
const PST_OFFSET_HOURS = -8;

function getCurrentHourPST() {
  const utcHour = new Date().getUTCHours();
  return (utcHour + 24 + PST_OFFSET_HOURS) % 24;
}

// ===== activity helper =====
// Returns true if a screentime doc was updated within the last 35 minutes.
// 35 min gives a small buffer over the 30-min schedule to avoid edge cases.
function isRecentlyActive(screentimeData) {
  if (!screentimeData?.lastUpdated) return false;
  const lastUpdated = screentimeData.lastUpdated.toDate();
  const minutesAgo = (Date.now() - lastUpdated.getTime()) / 1000 / 60;
  return minutesAgo <= 35;
}

/**
 * Runs every 30 minutes.
 * Skips entirely during quiet hours (midnight–6am PST).
 * Skips a group if no members have uploaded screentime in the last 35 minutes.
 * Otherwise aggregates screentime into groups/{groupId}/leaderboard/current.
 */
exports.aggregateLeaderboards = onSchedule("every 30 minutes", async (event) => {

  // ===== quiet hours check =====
  const currentHour = getCurrentHourPST();
  if (currentHour >= 0 && currentHour < 6) {
    console.log(`Quiet hours active (${currentHour}:xx PST). Skipping run.`);
    return;
  }

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

    // ===== fetch all member screentime docs =====
    const screentimeDocs = await Promise.all(
      memberIds.map((uid) => db.collection("screentime").doc(uid).get())
    );

    // ===== skip if no members have been active recently =====
    const anyActive = screentimeDocs.some(
      (doc) => doc.exists && isRecentlyActive(doc.data())
    );
    if (!anyActive) {
      console.log(`Group ${groupId}: no recent activity, skipping.`);
      return;
    }

    // ===== build leaderboard entries =====
    const userDocs = await Promise.all(
      memberIds.map((uid) => db.collection("users").doc(uid).get())
    );

    const entries = memberIds.map((uid, i) => {
      const username = userDocs[i].exists
        ? (userDocs[i].data().username ?? "Unknown")
        : "Unknown";

      const screentimeDoc = screentimeDocs[i];
      if (!screentimeDoc.exists) {
        return { uid, username, totalBadMinutes: 0, badAppsBreakdown: [], lastUpdated: null };
      }

      const st = screentimeDoc.data();
      return {
        uid,
        username,
        totalBadMinutes: st.totalBadMinutes ?? 0,
        badAppsBreakdown: st.badAppsBreakdown ?? [],
        lastUpdated: st.lastUpdated ?? null,
      };
    });

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