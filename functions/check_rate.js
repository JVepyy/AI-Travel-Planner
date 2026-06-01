const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "travel-planner-15cb7",
});

const db = admin.firestore();

async function main() {
  const userId = process.argv[2];
  console.log(`Checking rate limit for user: ${userId}`);
  const doc = await db.collection("rateLimits").doc(userId).get();
  if (!doc.exists) {
    console.log("No rate limit document exists for this user.");
    return;
  }
  const data = doc.data();
  const now = Date.now();
  const oneHourAgo = now - (60 * 60 * 1000);
  const recent = (data.requests || []).filter(t => t > oneHourAgo);
  console.log(`Total stored requests: ${(data.requests || []).length}`);
  console.log(`Requests in last hour: ${recent.length}`);
  if (recent.length > 0) {
    console.log(`Oldest in window: ${new Date(Math.min(...recent)).toISOString()}`);
    console.log(`Newest: ${new Date(Math.max(...recent)).toISOString()}`);
  }
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
