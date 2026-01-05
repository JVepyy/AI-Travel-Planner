# Install Lora Font

The font you want is **Lora** - a beautiful serif font!

## Step 1: Download Lora

1. Go to: https://fonts.google.com/specimen/Lora
2. Click **"Download family"** (top right)
3. Unzip the downloaded file
4. Open the **"static"** folder (NOT variable!)
5. You need these files:
   - `Lora-Regular.ttf`
   - `Lora-Medium.ttf`
   - `Lora-Bold.ttf`

## Step 2: Add to Xcode

1. In Xcode, go to **TravelPlanner/Fonts** folder
2. **Drag** the 3 Lora font files into the Fonts folder
3. Make sure:
   - ✅ "Copy items if needed" is checked
   - ✅ "TravelPlanner" target is checked
4. Click **Add**

## Step 3: Update Info.plist

1. Open **Info.plist**
2. Find **"Fonts provided by application"**
3. Add 3 new items (in addition to Satoshi):
   - `Lora-Regular.ttf`
   - `Lora-Medium.ttf`
   - `Lora-Bold.ttf`

## Step 4: Clean & Test

1. **Clean Build** - `Cmd + Shift + K`
2. **Delete app** from iPhone
3. **Run** - `Cmd + R`

---

The font will be applied to your onboarding automatically!

