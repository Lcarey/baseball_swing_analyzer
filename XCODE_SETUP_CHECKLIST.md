# Xcode Setup Checklist

## Step-by-Step Instructions

### STEP 1: Open Xcode Project
```bash
open /Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer/SwingAnalyzer.xcodeproj
```

Or double-click the file in Finder.

---

### STEP 2: Clean Up Duplicate Files (if any)

In Xcode's **Project Navigator** (left sidebar):
1. Look for **duplicate** `SwingAnalyzerApp.swift` at the root level
2. Look for **duplicate** `ContentView.swift` at the root level
3. If found: **RIGHT-CLICK** → **Delete** → **Move to Trash**
4. Keep the `SwingAnalyzer.xcdatamodeld` file (we'll configure it later)

---

### STEP 3: Add Source Files to Project

1. In Xcode, **RIGHT-CLICK** on the **'SwingAnalyzer'** folder (blue icon in navigator)
2. Select **'Add Files to "SwingAnalyzer"...'**
3. Navigate to: `/Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer/SwingAnalyzer`
4. Hold **CMD** and select these folders:
   - ✅ **App**
   - ✅ **Models**
   - ✅ **ViewModels**
   - ✅ **Views**
   - ✅ **Utilities**
5. Make sure these options are **CHECKED**:
   - ☑️ **Copy items if needed**
   - ☑️ **Create groups** (not references)
   - ☑️ **SwingAnalyzer** target
6. Click **'Add'**

---

### STEP 4: Add Info.plist

1. In Xcode, **RIGHT-CLICK** on the **'SwingAnalyzer'** folder again
2. Select **'Add Files to "SwingAnalyzer"...'**
3. Select: `/Users/lcarey/Develop/baseball_swing_analyzer/SwingAnalyzer/SwingAnalyzer/Info.plist`
4. Make sure **'Copy items if needed'** is **CHECKED**
5. Click **'Add'**

---

### STEP 5: Configure Build Settings for Info.plist

1. Click on the **blue 'SwingAnalyzer' project icon** (very top of navigator)
2. Under **TARGETS**, select **'SwingAnalyzer'**
3. Go to **'Build Settings'** tab
4. Search for: `Info.plist`
5. Find **'Info.plist File'** and set it to: `SwingAnalyzer/Info.plist`

---

### STEP 6: Set iOS Version and Device Settings

1. Still in the **SwingAnalyzer target**
2. Go to **'General'** tab
3. Under **'Deployment Info'**:
   - Set **'Minimum Deployments'** to: **iOS 15.0**
   - Uncheck **iPad** and **Mac** (iPhone only)
   - Set **'Device Orientation'** to: **Portrait** only (uncheck others)

---

### STEP 7: First Build Test

1. Select a simulator: **iPhone 14** or later (top toolbar)
2. Press **CMD+B** to build
3. You may see some errors - that's okay, we'll fix them

**Common errors at this stage:**
- Missing Core Data model configuration (we'll do that next)
- Some import warnings (normal)

---

### STEP 8: Configure Core Data Model

1. In Xcode navigator, find and click: **'SwingAnalyzer.xcdatamodeld'**
2. You should see the **Core Data Model Editor**

Now create 4 entities:

---

#### Entity 1: Session

1. Click **"Add Entity"** button (bottom left)
2. Name it: **Session**
3. Click **'+'** in **Attributes** section to add:

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| date | Date | No |
| location | String | Yes ✓ |
| averageScore | Double | No |
| swingCount | Integer 16 | No |

4. Click **'+'** in **Relationships** section:

| Name | Destination | Type | Delete Rule |
|------|-------------|------|-------------|
| swings | Swing | To Many | Cascade |

---

#### Entity 2: Swing

1. Click **"Add Entity"**
2. Name it: **Swing**
3. Add **Attributes**:

| Attribute | Type | Optional |
|-----------|------|----------|
| id | UUID | No |
| timestamp | Date | No |
| score | Double | No |
| videoURL | String | No |
| duration | Double | No |
| thumbnailData | Binary Data | Yes ✓ |

4. Add **Relationships**:

| Name | Destination | Type | Delete Rule |
|------|-------------|------|-------------|
| session | Session | To One | Nullify |
| metrics | SwingMetrics | To One | Cascade |
| jointData | JointData | To Many | Cascade |

---

#### Entity 3: SwingMetrics

1. Click **"Add Entity"**
2. Name it: **SwingMetrics**
3. Add **Attributes**:

| Attribute | Type |
|-----------|------|
| id | UUID |
| kneeBend | Double |
| hipRotation | Double |
| hipHorizontalMovement | Double |
| hipVerticalMovement | Double |
| hipShoulderAlignment | Double |
| timeToContact | Double |

4. Add **Relationship**:

| Name | Destination | Type | Delete Rule |
|------|-------------|------|-------------|
| swing | Swing | To One | Nullify |

---

#### Entity 4: JointData

1. Click **"Add Entity"**
2. Name it: **JointData**
3. Add **Attributes**:

| Attribute | Type |
|-----------|------|
| id | UUID |
| frameNumber | Integer 32 |
| timestamp | Double |
| jointPositionsJSON | String |

4. Add **Relationship**:

| Name | Destination | Type | Delete Rule |
|------|-------------|------|-------------|
| swing | Swing | To One | Nullify |

---

#### Verify Inverse Relationships

Click on each relationship and verify the **Inverse** is set:
- ✅ Session.swings ↔ Swing.session
- ✅ Swing.metrics ↔ SwingMetrics.swing  
- ✅ Swing.jointData ↔ JointData.swing

(Xcode usually sets these automatically)

**Save**: Press **CMD+S**

---

### STEP 9: Final Build and Run

1. Press **CMD+B** to build
2. Fix any remaining errors (check the Issue Navigator: **CMD+4**)
3. If successful, press **CMD+R** to run
4. You should see:
   - ✅ Empty Sessions list
   - ✅ "No Sessions Yet" message
   - ✅ A **'+'** button in top right
   - ✅ "Start Recording" button

---

## Troubleshooting

### Build Errors

**"Cannot find type 'Session' in scope"**
- Make sure you added all folders with correct target membership
- Check that SwingAnalyzer target is selected for all .swift files

**Core Data errors**
- Double-check entity names match exactly (case-sensitive)
- Verify all relationships have inverses set

**Info.plist errors**
- Make sure the path is set correctly in Build Settings
- Path should be: `SwingAnalyzer/Info.plist`

### Missing Files

If files don't appear in Xcode:
1. Right-click the SwingAnalyzer folder
2. Select "Add Files to SwingAnalyzer..."
3. Re-add the missing folder
4. Make sure target is checked

---

## Success! ✅

When you see the app running with the Sessions list, you're ready for **Phase 2: Camera & Video Recording**!

Let me know when you get here or if you hit any issues.
