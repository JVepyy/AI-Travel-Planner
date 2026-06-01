const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const OpenAI = require("openai");

admin.initializeApp();

setGlobalOptions({maxInstances: 10, region: "us-central1"});

// Define OpenAI API key as a Firebase Secret
// Set it via: firebase functions:secrets:set OPENAI_API_KEY
// Or via Google Cloud Console > Secret Manager
const openaiApiKey = defineSecret("OPENAI_API_KEY");

// Initialize OpenAI client function (called at runtime, not deployment)
// SECURITY: API key is stored securely in Firebase Secrets (Secret Manager)
// It is NEVER exposed to the iOS app or client-side code
function getOpenAIClient() {
  return new OpenAI({
    apiKey: openaiApiKey.value(),
  });
}

exports.generateTravelPlan = onCall(
    {
      secrets: [openaiApiKey], // Grant access to the secret
      timeoutSeconds: 300, // 5 minutes timeout (max is 540 for gen2)
    },
    async (request) => {
  try {
    const {auth, data} = request;

    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    let {
      destination,
      startDate,
      endDate,
      budget,
      specialRequests,
      isFlexibleDates = false,
      duration = 7,
    } = data;

    // Parse ISO date strings (only if not flexible)
    if (!isFlexibleDates) {
      startDate = new Date(startDate);
      endDate = new Date(endDate);
    }

    if (!destination || !budget) {
      throw new HttpsError(
          "invalid-argument",
          "Missing required fields: destination, budget",
      );
    }

    // For flexible dates, dates are optional (AI will determine)
    if (!isFlexibleDates && (!startDate || !endDate)) {
      throw new HttpsError(
          "invalid-argument",
          "Missing required fields: startDate, endDate",
      );
    }

    if (destination.length > 200) {
      throw new HttpsError("invalid-argument", "Destination too long");
    }

    await checkRateLimit(auth.uid);

    logger.info("=== GENERATE PLAN START ===");
    logger.info(`User ID from auth: ${auth.uid}`);
    logger.info(`Request data - destination: ${destination}, budget: ${budget}, isFlexibleDates: ${isFlexibleDates}, duration: ${duration}`);

    // Generate plan using OpenAI with web browsing
    const travelPlan = await generatePlanWithOpenAI({
      destination,
      startDate,
      endDate,
      budget,
      specialRequests,
      isFlexibleDates,
      duration,
    });

    // Save to Firestore
    const planId = admin.firestore().collection("travelPlans").doc().id;
    
    // Prepare plan data with proper date formatting
    const planData = {
      ...travelPlan,
      id: planId,
      userId: auth.uid,
      // Keep dates as ISO strings for the response
      startDate: travelPlan.startDate,
      endDate: travelPlan.endDate,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // For Firestore, convert dates to Timestamps
    const firestoreData = {
      ...planData,
      startDate: admin.firestore.Timestamp.fromDate(new Date(travelPlan.startDate)),
      endDate: admin.firestore.Timestamp.fromDate(new Date(travelPlan.endDate)),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Convert day dates to Timestamps
      days: travelPlan.days.map((day) => ({
        ...day,
        date: admin.firestore.Timestamp.fromDate(new Date(day.date)),
      })),
    };

    logger.info("=== SAVING TO FIRESTORE ===");
    logger.info(`Plan ID: ${planId}`);
    logger.info(`User ID in firestoreData: ${firestoreData.userId}`);
    logger.info(`Destination: ${firestoreData.destination}`);

    await admin.firestore()
        .collection("travelPlans")
        .doc(planId)
        .set(firestoreData);

    logger.info("=== PLAN SAVED SUCCESSFULLY ===");
    logger.info("Verifying save...");
    
    // Verify the plan was saved
    const savedDoc = await admin.firestore().collection("travelPlans").doc(planId).get();
    if (savedDoc.exists) {
      const savedData = savedDoc.data();
      logger.info(`Verification: Plan exists in Firestore`);
      logger.info(`  - Saved userId: ${savedData.userId}`);
      logger.info(`  - Saved destination: ${savedData.destination}`);
      logger.info(`  - Saved id: ${savedData.id}`);
    } else {
      logger.error("Verification FAILED: Plan not found after save!");
    }

    // Return plan data with ISO date strings (not Firestore Timestamps)
    return {
      success: true,
      plan: planData,
    };
  } catch (error) {
    logger.error("Error generating travel plan", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", "Failed to generate travel plan");
  }
  },
);

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

    if (recentRequests.length >= 50) {
      throw new HttpsError(
          "resource-exhausted",
          "Rate limit exceeded. Max 50 requests per hour.",
      );
    }

    recentRequests.push(now);
    await rateLimitRef.update({requests: recentRequests});
  } else {
    await rateLimitRef.set({requests: [now]});
  }
}

async function generatePlanWithOpenAI({destination, startDate, endDate, budget, specialRequests, isFlexibleDates, duration}) {
  let start, end, days;
  
  if (isFlexibleDates) {
    // For flexible dates, AI will determine the best dates but we know the duration
    start = null;
    end = null;
    days = duration; // Use the duration provided by the user
  } else {
    start = new Date(startDate);
    end = new Date(endDate);
    days = Math.ceil((end - start) / (1000 * 60 * 60 * 24));
  }

  const dateInfo = isFlexibleDates 
    ? `Dates: FLEXIBLE - determine best time to visit. Trip must be exactly ${duration} days.`
    : `Start: ${new Date(startDate).toLocaleDateString("en-US", {month: "short", day: "numeric"})}, End: ${new Date(endDate).toLocaleDateString("en-US", {month: "short", day: "numeric"})} (${days} days)`;

  const prompt = `Create a ${duration}-day travel itinerary for ${destination}. Budget: ${budget}.${specialRequests ? ` Notes: ${specialRequests}` : ""} ${dateInfo}

Respond with JSON only:
{
  "displayName": "Proper destination name",
  "countryCode": "2-letter ISO code",${isFlexibleDates ? `
  "suggestedStartDate": "YYYY-MM-DD",
  "suggestedEndDate": "YYYY-MM-DD",` : ""}
  "days": [
    {
      "dayNumber": 1,
      "date": "YYYY-MM-DD",
      "theme": "Day theme",
      "activities": [
        {"time": "10:00 AM", "name": "Activity", "description": "Brief desc", "duration": "2h", "cost": "$25", "location": "Address"}
      ],
      "restaurants": [
        {"name": "Restaurant", "cuisine": "Type", "time": "Lunch", "priceRange": "${budget}", "location": "Address"}
      ],
      "hiddenGems": ["Hidden gem"],
      "tip": "Daily tip",
      "estimatedDailyCost": "$150"
    }
  ],
  "highlights": ["Highlight 1", "Highlight 2"],
  "localTips": ["Tip 1", "Tip 2"],
  "totalEstimatedCost": "$$$"
}

Rules:
- 2 activities per day, 2 restaurants per day (lunch + dinner)
- Keep descriptions under 15 words
- 2 highlights max, 2 local tips max
- Sequential dates starting from ${isFlexibleDates ? "best travel date you determine" : "start date"}`;

  try {
    // Initialize OpenAI client at runtime (secrets are only available at runtime)
    const openai = getOpenAIClient();
    
    // Use Chat Completions API directly (much faster than Assistants API)
    // GPT-4o-mini is faster (~3-5x) and more cost-effective (~10x cheaper) than GPT-4o
    // while maintaining excellent quality for structured outputs like travel plans
    // Add timeout to prevent hanging (4 minutes max for API call)
    const completion = await Promise.race([
      openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "You are an expert travel planner with extensive knowledge of destinations worldwide. Always respond with valid JSON only. Provide current, practical travel advice based on your knowledge.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        response_format: {type: "json_object"},
        temperature: 0.7,
      }),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error("OpenAI API timeout after 4 minutes")), 240000)
      ),
    ]);

    const content = completion.choices[0].message.content;
    const planData = JSON.parse(content);

    // Determine final start and end dates
    let finalStartDate, finalEndDate;
    if (isFlexibleDates) {
      // Use dates from AI response or calculate from days
      if (planData.suggestedStartDate && planData.suggestedEndDate) {
        try {
          finalStartDate = new Date(planData.suggestedStartDate);
          finalEndDate = new Date(planData.suggestedEndDate);
          // Validate dates
          if (isNaN(finalStartDate.getTime()) || isNaN(finalEndDate.getTime())) {
            throw new Error("Invalid date format");
          }
        } catch (e) {
          // If parsing fails, calculate from days
          logger.warn("Failed to parse suggested dates, calculating from days", e);
          if (planData.days && planData.days.length > 0) {
            const firstDay = planData.days[0];
            const lastDay = planData.days[planData.days.length - 1];
            try {
              finalStartDate = firstDay.date ? new Date(firstDay.date) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
              finalEndDate = lastDay.date ? new Date(lastDay.date) : new Date(finalStartDate.getTime() + (planData.days.length - 1) * 24 * 60 * 60 * 1000);
            } catch (e2) {
              finalStartDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
              finalEndDate = new Date(finalStartDate.getTime() + (planData.days.length - 1) * 24 * 60 * 60 * 1000);
            }
          } else {
            finalStartDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
            finalEndDate = new Date(finalStartDate.getTime() + 6 * 24 * 60 * 60 * 1000);
          }
        }
      } else if (planData.days && planData.days.length > 0) {
        // Calculate from first and last day
        const firstDay = planData.days[0];
        const lastDay = planData.days[planData.days.length - 1];
        try {
          finalStartDate = firstDay.date && !firstDay.date.includes("determine") ? new Date(firstDay.date) : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
          finalEndDate = lastDay.date && !lastDay.date.includes("determine") ? new Date(lastDay.date) : new Date(finalStartDate.getTime() + (planData.days.length - 1) * 24 * 60 * 60 * 1000);
        } catch (e) {
          finalStartDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
          finalEndDate = new Date(finalStartDate.getTime() + (planData.days.length - 1) * 24 * 60 * 60 * 1000);
        }
      } else {
        // Fallback: 30 days from now, 7 day trip
        finalStartDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
        finalEndDate = new Date(finalStartDate.getTime() + 6 * 24 * 60 * 60 * 1000);
      }
    } else {
      finalStartDate = start;
      finalEndDate = end;
    }

    // Convert to our TravelPlan format
    return {
      destination: destination,
      displayName: planData.displayName || destination,
      countryCode: planData.countryCode || null,
      startDate: finalStartDate.toISOString(),
      endDate: finalEndDate.toISOString(),
      budget: budget,
      specialRequests: specialRequests || null,
      days: planData.days.map((day, index) => {
        // Handle date assignment
        let dayDate;
        if (isFlexibleDates) {
          // For flexible dates, use the date from AI response or calculate from suggested start
          if (day.date && day.date !== "YYYY-MM-DD (determine best date)" && !day.date.includes("determine")) {
            try {
              dayDate = new Date(day.date).toISOString();
            } catch (e) {
              // If parsing fails, calculate from suggested start
              const suggestedStart = planData.suggestedStartDate 
                ? new Date(planData.suggestedStartDate)
                : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
              dayDate = new Date(suggestedStart.getTime() + index * 24 * 60 * 60 * 1000).toISOString();
            }
          } else {
            // Use suggested start date from AI or default to reasonable future date
            const suggestedStart = planData.suggestedStartDate 
              ? new Date(planData.suggestedStartDate)
              : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days from now
            dayDate = new Date(suggestedStart.getTime() + index * 24 * 60 * 60 * 1000).toISOString();
          }
        } else {
          dayDate = day.date || new Date(new Date(startDate).getTime() + index * 24 * 60 * 60 * 1000).toISOString();
        }
        
        return {
          dayNumber: day.dayNumber || index + 1,
          date: dayDate,
          theme: day.theme || null,
          activities: day.activities || [],
          restaurants: day.restaurants || [],
          hiddenGems: day.hiddenGems || [],
          tip: day.tip || null,
          estimatedDailyCost: day.estimatedDailyCost || null,
        };
      }),
      totalEstimatedCost: planData.totalEstimatedCost || null,
      highlights: (planData.highlights || []).slice(0, 2), // Limit to 2 highlights max
      localTips: planData.localTips || [],
    };
  } catch (error) {
    logger.error("OpenAI API error", error);
    throw new Error(`Failed to generate plan: ${error.message}`);
  }
}
