const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

setGlobalOptions({maxInstances: 10, region: "us-central1"});

exports.generateTravelPlan = onCall(async (request) => {
  try {
    const {auth, data} = request;

    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const {destination, startDate, endDate, preferences} = data;

    if (!destination || !startDate || !endDate) {
      throw new HttpsError(
          "invalid-argument",
          "Missing required fields: destination, startDate, endDate",
      );
    }

    if (destination.length > 200) {
      throw new HttpsError("invalid-argument", "Destination too long");
    }

    await checkRateLimit(auth.uid);

    logger.info("Generating travel plan", {
      userId: auth.uid,
      destination: destination,
    });

    const prompt = buildPrompt(destination, startDate, endDate, preferences);

    const plan = {
      id: admin.firestore().collection("travelPlans").doc().id,
      userId: auth.uid,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      preferences: preferences || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      plan: `Sample plan for ${destination} (OpenAI integration pending)`,
    };

    await admin.firestore()
        .collection("travelPlans")
        .doc(plan.id)
        .set(plan);

    logger.info("Travel plan created", {planId: plan.id});

    return {
      success: true,
      planId: plan.id,
      plan: plan,
    };
  } catch (error) {
    logger.error("Error generating travel plan", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", "Failed to generate travel plan");
  }
});

async function checkRateLimit(userId) {
  const rateLimitRef = admin.firestore()
      .collection("rateLimits")
      .doc(userId);

  const doc = await rateLimitRef.get();
  const now = Date.now();
  const oneHourAgo = now - (60 * 60 * 1000);

  if (doc.exists) {
    const data = doc.data();
    const recentRequests = data.requests.filter((t) => t > oneHourAgo);

    if (recentRequests.length >= 10) {
      throw new HttpsError(
          "resource-exhausted",
          "Rate limit exceeded. Max 10 requests per hour.",
      );
    }

    recentRequests.push(now);
    await rateLimitRef.update({requests: recentRequests});
  } else {
    await rateLimitRef.set({requests: [now]});
  }
}

function buildPrompt(destination, startDate, endDate, preferences) {
  return `Create a detailed travel plan for ${destination} from ${startDate} to ${endDate}. Preferences: ${JSON.stringify(preferences)}`;
}
