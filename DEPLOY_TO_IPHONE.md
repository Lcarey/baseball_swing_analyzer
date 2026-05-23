# Deploy to Your iPhone 15

## Current Issue
Your iPhone needs **Developer Mode** enabled before you can deploy apps to it.

## Steps to Fix

### 1. Enable Developer Mode on Your iPhone

On your iPhone 15:
1. Open **Settings**
2. Go to **Privacy & Security**
3. Scroll down to **Developer Mode**
4. Toggle it **ON**
5. Tap **Restart** when prompted
6. After restart, confirm you want to enable Developer Mode

### 2. Trust Your Mac

When you connect your iPhone to your Mac:
1. You'll see an alert on your iPhone: **"Trust This Computer?"**
2. Tap **Trust**
3. Enter your iPhone passcode if prompted

### 3. Add Your Apple ID to Xcode (if not already done)

Open Xcode and add your Apple ID:
```bash
open /Applications/Xcode.app
```

Then:
1. Go to **Xcode** → **Settings** (or **Preferences**)
2. Click **Accounts** tab
3. Click the **+** button at bottom left
4. Select **Apple ID**
5. Sign in with **lucas.carey@gmail.com** (or your Apple ID)

This creates a free personal development team for code signing.

### 4. Build and Run

#### Option A: Use Xcode (Easiest)
1. Open the project:
   ```bash
   open SwingAnalyzer/SwingAnalyzer.xcodeproj
   ```
2. At the top of Xcode, select **"Lucas's iPhone"** as the destination
3. Press **Cmd+R** (or click the Play button)
4. Xcode will handle code signing automatically
5. The first time, you may need to:
   - Trust the developer certificate on your iPhone
   - Go to **Settings** → **General** → **VPN & Device Management**
   - Tap your Apple ID and tap **Trust**

#### Option B: Command Line
After enabling Developer Mode:
```bash
cd /Users/lcarey/Develop/baseball_swing_analyzer
./build_for_iphone.sh
```

## Troubleshooting

### "Developer Mode disabled"
→ Follow Step 1 above to enable Developer Mode

### "Signing for 'SwingAnalyzer' requires a development team"
→ Follow Step 3 to add your Apple ID to Xcode

### "Untrusted Developer"
On your iPhone:
1. Go to **Settings** → **General** → **VPN & Device Management**
2. Under **Developer App**, tap your Apple ID email
3. Tap **Trust "Apple Development..."**
4. Tap **Trust** in the confirmation dialog

### Build succeeds but app won't open
This means the developer certificate isn't trusted yet. Follow the "Untrusted Developer" steps above.

## What Happens Next

Once the app is installed on your iPhone:
1. Open the **SwingAnalyzer** app
2. Grant camera permissions when prompted
3. Tap the **+** button or **"Start Recording"**
4. Position your iPhone to capture a side view of the batter
5. Tap the red record button
6. Take some swings!
7. Tap stop when done
8. Wait for the AI to process (usually 10-30 seconds)
9. View your swing analysis with scores and metrics!

## Testing Tips

### Camera Setup
- Position camera 10-15 feet away, side view
- Make sure the whole body is in frame
- Use the grid overlay for alignment
- Landscape orientation works best

### Recording
- Record continuously (can capture multiple swings)
- No need to stop between swings
- The AI will automatically detect each swing
- Minimum swing duration: 0.3 seconds
- Maximum swing duration: 1.0 second

### Best Results
- Well-lit environment
- Clear view of the batter
- Side angle (not front or back)
- Steady camera position
- Full body visible from head to feet

## Notes

- The app runs 100% on-device (no internet required)
- All AI processing happens locally
- Data never leaves your iPhone
- First analysis may take 20-30 seconds
- Subsequent analyses will be faster
- Videos are stored in the app's Documents folder

---

**After enabling Developer Mode and adding your Apple ID to Xcode, building to your iPhone should work smoothly!**
