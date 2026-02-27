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

// Returns today's date string in PST as YYYY-MM-DD.
// Important to use PST here so the history doc date matches
// what the user would expect to see on their phone.
function getTodayPST() {
  const now = new Date();
  const pstOffset = PST_OFFSET_HOURS * 60 * 60 * 1000;
  const pstDate = new Date(now.getTime() + pstOffset);
  return pstDate.toISOString().split('T')[0];
}

function isRecentlyActive(screentimeData) {
  if (!screentimeData?.lastUpdated) return false;
  const lastUpdated = screentimeData.lastUpdated.toDate();
  const minutesAgo = (Date.now() - lastUpdated.getTime()) / 1000 / 60;
  return minutesAgo <= 35;
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

exports.aggregateLeaderboards = onSchedule("every 30 minutes", async (event) => {

  // ===== quiet hours check =====
  const currentHour = getCurrentHourPST();
  if (currentHour >= 0 && currentHour < 6) {
    console.log(`Quiet hours active (${currentHour}:xx PST). Skipping run.`);
    return;
  }

  const today = getTodayPST();

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

    // ===== write current leaderboard (unchanged) =====
    await db
      .collection("groups")
      .doc(groupId)
      .collection("leaderboard")
      .doc("current")
      .set({
        lastUpdated: FieldValue.serverTimestamp(),
        entries,
      });

    // ===== write personal daily history for each member =====
    // Uses set() so repeated runs just overwrite the same day's doc.
    // This means today's snapshot always reflects the latest upload.
    await Promise.all(
      memberIds.map((uid, i) => {
        if (!screentimeDocs[i].exists) return Promise.resolve();
        const st = screentimeDocs[i].data();

        // Apply the same vote filtering as the leaderboard so
        // personal history is consistent with what the group sees.
        const rawBreakdown = st.badAppsBreakdown ?? [];
        const filteredBreakdown = activeApps === null
          ? rawBreakdown
          : rawBreakdown.filter((item) => activeApps.has(item.appName));
        const totalBadMinutes = filteredBreakdown.reduce(
          (sum, item) => sum + (item.minutes ?? 0), 0
        );

        return db
          .collection("screentime")
          .doc(uid)
          .collection("history")
          .doc(today)
          .set({
            totalBadMinutes,
            recordedAt: FieldValue.serverTimestamp(),
          });
      })
    );

    // ===== write group average daily history =====
    // Compute average across members who have screentime data.
    const membersWithData = entries.filter((e) => e.lastUpdated !== null);
    if (membersWithData.length > 0) {
      const averageBadMinutes = membersWithData.reduce(
        (sum, e) => sum + e.totalBadMinutes, 0
      ) / membersWithData.length;

      await db
        .collection("groups")
        .doc(groupId)
        .collection("history")
        .doc(today)
        .set({
          averageBadMinutes,
          recordedAt: FieldValue.serverTimestamp(),
        });
    }

    console.log(`Updated leaderboard and history for group ${groupId} (${entries.length} members)`);
  });

  await Promise.all(tasks);
});