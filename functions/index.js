const { setGlobalOptions } = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = getFirestore();

setGlobalOptions({ maxInstances: 10 });

const PST_OFFSET_HOURS = -8;

function getCurrentHourPST() {
  const utcHour = new Date().getUTCHours();
  return (utcHour + 24 + PST_OFFSET_HOURS) % 24;
}

function isRecentlyActive(screentimeData) {
  if (!screentimeData?.lastUpdated) return false;
  const lastUpdated = screentimeData.lastUpdated.toDate();
  const minutesAgo = (Date.now() - lastUpdated.getTime()) / 1000 / 60;
  return minutesAgo <= 35;
}

// Returns the set of app display names that have >= 50% of member votes.
// If appVotes is missing entirely, all apps are considered active (default on).
// If a specific app has no entry in appVotes, it is also considered active.
function getActiveApps(appVotes, totalMembers) {
  // No vote data at all — everything is active
  if (!appVotes || Object.keys(appVotes).length === 0) return null;

  const activeApps = new Set();
  for (const [appName, voters] of Object.entries(appVotes)) {
    if (voters.length > totalMembers / 2) {
      activeApps.add(appName);
    }
  }
  return activeApps;
}

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
    const appVotes = groupData.appVotes || {};

    if (memberIds.length === 0) {
      console.log(`Group ${groupId} has no members, skipping.`);
      return;
    }

    // ===== compute active apps from votes =====
    // null means "no vote data — treat all apps as active"
    const activeApps = getActiveApps(appVotes, memberIds.length);

    // ===== fetch all member screentime and user docs in parallel =====
    const [screentimeDocs, userDocs] = await Promise.all([
      Promise.all(memberIds.map((uid) => db.collection("screentime").doc(uid).get())),
      Promise.all(memberIds.map((uid) => db.collection("users").doc(uid).get())),
    ]);

    // ===== skip if no members have been active recently =====
    const anyActive = screentimeDocs.some(
      (doc) => doc.exists && isRecentlyActive(doc.data())
    );
    if (!anyActive) {
      console.log(`Group ${groupId}: no recent activity, skipping.`);
      return;
    }

    // ===== build leaderboard entries =====
    const entries = memberIds.map((uid, i) => {
      const username = userDocs[i].exists
        ? (userDocs[i].data().username ?? "Unknown")
        : "Unknown";

      if (!screentimeDocs[i].exists) {
        return { uid, username, totalBadMinutes: 0, badAppsBreakdown: [], lastUpdated: null };
      }

      const st = screentimeDocs[i].data();
      const rawBreakdown = st.badAppsBreakdown ?? [];

      // Filter breakdown to only apps that passed the vote threshold.
      // If activeApps is null, no filtering — all apps are shown.
      const filteredBreakdown = activeApps === null
        ? rawBreakdown
        : rawBreakdown.filter((item) => activeApps.has(item.appName));

      // Recompute total from the filtered breakdown so the leaderboard
      // score reflects only the apps the group agreed to track.
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

    await db
      .collection("groups")
      .doc(groupId)
      .collection("leaderboard")
      .doc("current")
      .set({
        lastUpdated: FieldValue.serverTimestamp(),
        entries,
      });

    console.log(`Updated leaderboard for group ${groupId} (${entries.length} members, ${activeApps?.size ?? 'all'} active apps)`);
  });

  await Promise.all(tasks);
});