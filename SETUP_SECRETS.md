# 🔐 Setting Up Firebase Secrets (Secret Manager)

## Step 1: Enable Secret Manager API

The quota error you saw means Secret Manager API needs to be enabled first.

### Option A: Enable via Google Cloud Console (Recommended)

1. Go to: https://console.cloud.google.com/apis/library/secretmanager.googleapis.com
2. Select your project: **travel-planner-15cb7**
3. Click **"Enable"** button
4. Wait 1-2 minutes for it to activate

### Option B: Enable via Command Line

```bash
# Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com --project=travel-planner-15cb7
```

If you don't have `gcloud` CLI installed, use Option A (Google Cloud Console).

## Step 2: Wait for Quota Reset

After enabling, wait **2-3 minutes** for:
- API to fully activate
- Quota limits to reset

## Step 3: Set the Secret

Once the API is enabled and you've waited, run:

```bash
cd /Users/juraj/Desktop/TravelPlanner
npx firebase functions:secrets:set OPENAI_API_KEY
```

When prompted:
```
Enter a value for OPENAI_API_KEY: sk-your-api-key-here
```

Press Enter.

## Step 4: Grant Secret Access to Functions

The secret needs to be accessible by your function. This is already configured in the code, but you need to deploy:

```bash
cd functions
npm install
cd ..
npx firebase deploy --only functions
```

## Step 5: Verify Secret is Set

You can verify the secret exists:

```bash
npx firebase functions:secrets:access OPENAI_API_KEY
```

Or check in Google Cloud Console:
- Go to: https://console.cloud.google.com/security/secret-manager?project=travel-planner-15cb7

## Troubleshooting

### Still Getting Quota Error?

1. **Wait longer** (5-10 minutes) - Google Cloud APIs can take time to activate
2. **Check API is enabled**: Go to https://console.cloud.google.com/apis/dashboard?project=travel-planner-15cb7
   - Look for "Secret Manager API" - should show "Enabled"
3. **Try again**: Run `npx firebase functions:secrets:set OPENAI_API_KEY` again

### Alternative: Use Google Cloud Console Directly

If command line still doesn't work:

1. Go to: https://console.cloud.google.com/security/secret-manager/create?project=travel-planner-15cb7
2. Click **"Create Secret"**
3. Name: `OPENAI_API_KEY`
4. Secret value: Paste your API key
5. Click **"Create Secret"**
6. Then deploy functions: `npx firebase deploy --only functions`

The function code is already configured to use this secret name.

---

**Once the secret is set, your functions will automatically use it!** ✅
