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
    ? `- Dates: FLEXIBLE - You should determine the BEST time to visit ${destination} based on:
  * Weather patterns and seasons
  * Peak vs off-peak travel times
  * Local events and festivals
  * Tourist crowds and prices
  * Optimal conditions for activities
  Choose the best start date. The trip MUST be exactly ${duration} days long.
  IMPORTANT: Generate EXACTLY ${duration} day itineraries with proper dates.`
    : `- Start Date: ${new Date(startDate).toLocaleDateString("en-US", {month: "long", day: "numeric", year: "numeric"})}
- End Date: ${new Date(endDate).toLocaleDateString("en-US", {month: "long", day: "numeric", year: "numeric"})}
- Duration: ${days} days`;

  const prompt = `You are an expert travel planner. Create a detailed, day-by-day travel itinerary for ${destination}.

Travel Details:
- Destination: ${destination}
${dateInfo}
- Budget Level: ${budget}
${specialRequests ? `- Special Requests: ${specialRequests}` : ""}

IMPORTANT: Use real-time web browsing to get CURRENT information about:
- Current prices for attractions, restaurants, and activities
- Recent reviews and recommendations
- Current weather patterns
- Up-to-date opening hours and availability
- Latest travel tips and local insights
- Current exchange rates if applicable

Generate a comprehensive travel plan with the following structure (respond ONLY with valid JSON):

{
  "displayName": "Corrected/proper name of the destination (e.g., 'Machu Picchu, Peru' if user wrote 'machu piktu')",
  "countryCode": "ISO 3166-1 alpha-2 country code (e.g., 'PE' for Peru, 'JP' for Japan, 'FR' for France)",
  "days": [
    {
      "dayNumber": 1,
      "date": "${isFlexibleDates ? "YYYY-MM-DD (determine best date)" : startDate.toISOString()}",
      "theme": "Brief theme for the day (e.g., 'Arrival & City Exploration')",
      "activities": [
        {
          "time": "10:00 AM",
          "name": "Activity name",
          "description": "Brief description (1-2 sentences max)",
          "duration": "2 hours",
          "cost": "$25",
          "location": "Specific location/address",
          "tips": "Helpful tips for this activity"
        }
      ],
      "restaurants": [
        {
          "name": "Restaurant name",
          "cuisine": "Type of cuisine",
          "priceRange": "${budget}",
          "time": "Lunch",
          "reservation": "Recommended/Required/Not needed",
          "description": "Why this restaurant is great"
        }
      ],
      "hiddenGems": ["Local secret spot 1", "Hidden gem 2"],
      "tip": "One practical tip for the day",
      "estimatedDailyCost": "$150"
    }
  ],
  "highlights": ["Top attraction 1", "Must-see 2"],
  "localTips": ["Local insight 1", "Cultural tip 2", "Practical tip 3"],
  "totalEstimatedCost": "$$$"${isFlexibleDates ? `,
  "suggestedStartDate": "YYYY-MM-DD (the best start date you determined)",
  "suggestedEndDate": "YYYY-MM-DD (the best end date you determined)"` : ""}
}

Make sure to:
- ALWAYS include "displayName" with the corrected/proper destination name
- ALWAYS include "countryCode" with the 2-letter ISO country code
- Include 2-4 activities per day
- Include 2-3 restaurant recommendations per day
- Keep ALL descriptions SHORT (1-2 sentences max, be concise)
- Include ONLY 2 highlights maximum
- Use REAL current prices from web search
- Include specific locations and addresses
- Make it practical and actionable
- Consider the budget level (${budget})
- Include unique local experiences
- Provide helpful tips and insights
${isFlexibleDates ? `
CRITICAL for flexible dates:
- You MUST generate EXACTLY ${duration} days of itinerary (no more, no less)
- You MUST provide "suggestedStartDate" and "suggestedEndDate" in YYYY-MM-DD format
- suggestedEndDate must be exactly ${duration - 1} days after suggestedStartDate
- Each day's "date" field MUST be a valid date in YYYY-MM-DD format, starting from suggestedStartDate
- Dates should be sequential (day 1 = suggestedStartDate, day 2 = suggestedStartDate + 1 day, etc.)
- Choose dates based on best weather, events, and travel conditions for ${destination}` : ""}`;

  try {
    // Initialize OpenAI client at runtime (secrets are only available at runtime)
    const openai = getOpenAIClient();
    
    // Use Chat Completions API directly (much faster than Assistants API)
    // GPT-4o has excellent knowledge and doesn't need web browsing for most travel planning
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
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
    });

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
