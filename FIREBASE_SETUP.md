# 🔥 Firebase Setup Guide

## ⚠️ IMPORTANT: GoogleService-Info.plist

The `GoogleService-Info.plist` file is **NOT** included in this repository for security reasons. You must create your own Firebase project and add your own configuration file.

## 📋 Setup Steps

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Enter project name: `TravelPlanner` (or your choice)
4. Follow the setup wizard

### 2. Register Your iOS App

1. In your Firebase project, click the **iOS** icon
2. Enter your **Bundle ID**: `com.yourname.TravelPlanner` (match your Xcode project)
3. Enter **App nickname**: `TravelPlanner`
4. Click **"Register app"**

### 3. Download GoogleService-Info.plist

1. Download the `GoogleService-Info.plist` file
2. **DO NOT** rename it
3. Drag it into Xcode:
   - Drop it in the `TravelPlanner` folder (yellow folder icon)
   - ✅ Check **"Copy items if needed"**
   - ✅ Check **"TravelPlanner" target**
4. Verify it appears in Xcode's project navigator

### 4. Enable Authentication

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable:
   - ✅ **Google** (configure OAuth consent screen)
   - ✅ **Apple** (add your Team ID and Key ID)

### 5. Create Firestore Database

1. Go to **Firestore Database** → **Create database**
2. Select **"Start in production mode"**
3. Choose a location (e.g., `us-central1`)

### 6. Set Up Firebase Functions

```bash
cd /Users/juraj/Desktop/TravelPlanner
firebase login
firebase init functions
npm install
```

### 7. Add OpenAI API Key (Backend Only)

```bash
cd functions
firebase functions:config:set openai.key="your-openai-api-key-here"
firebase deploy --only functions
```

## 🔒 Security Checklist

- ✅ `GoogleService-Info.plist` is in `.gitignore`
- ✅ Never commit API keys to GitHub
- ✅ Keep OpenAI key in Firebase Functions config (server-side only)
- ✅ Set up Firebase Security Rules
- ✅ Enable App Check (recommended for production)

## ❌ What NOT to Do

- ❌ Never commit `GoogleService-Info.plist`
- ❌ Never hardcode API keys in code
- ❌ Never push `.env` files to GitHub
- ❌ Never expose Firebase credentials in public repos

## ✅ Repository is Clean

The exposed API key has been removed from all git history. If you received a security alert:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Project Settings** → **Service accounts**
3. **Regenerate** your API keys
4. Download a fresh `GoogleService-Info.plist`
5. Replace the local file (it's already gitignored)

---

## 🆘 Need Help?

If you encounter issues:
1. Check Firebase Console for error messages
2. Verify `GoogleService-Info.plist` is properly added to Xcode
3. Ensure Bundle ID matches in Xcode and Firebase
4. Check that authentication providers are enabled

**Never share your `GoogleService-Info.plist` publicly!**

