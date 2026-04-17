/**
 * One-time migration: backfill toolName in existing ratings documents.
 *
 * Logic:
 *   - For each rating missing toolName, look up its toolId in the tools collection
 *   - Set toolName = tool.title
 *
 * Setup:
 *   1. Place this file in GrabTools/scripts/
 *   2. Ensure serviceAccountKey.json is in the same folder
 *   3. cd scripts && node migrate_tool_name.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrate() {
    console.log('Fetching ratings missing toolName...');
    const ratingsSnap = await db.collection('ratings').get();

    if (ratingsSnap.empty) {
        console.log('No ratings found.');
        return;
    }

    // Cache tool titles to avoid redundant fetches
    const toolCache = {};

    async function getToolTitle(toolId) {
        if (!toolId) return null;
        if (toolCache[toolId] !== undefined) return toolCache[toolId];
        const snap = await db.collection('tools').doc(toolId).get();
        const title = snap.exists ? (snap.data().title ?? null) : null;
        toolCache[toolId] = title;
        return title;
    }

    const batch = db.batch();
    let updateCount = 0;
    let skipCount = 0;

    for (const doc of ratingsSnap.docs) {
        const rating = doc.data();

        // Skip if toolName already set
        if (rating.toolName) {
            skipCount++;
            continue;
        }

        if (!rating.toolId) {
            console.warn(`  SKIP [${doc.id}] — no toolId`);
            skipCount++;
            continue;
        }

        const title = await getToolTitle(rating.toolId);
        if (!title) {
            console.warn(`  SKIP [${doc.id}] — tool "${rating.toolId}" not found`);
            skipCount++;
            continue;
        }

        console.log(`  FIX  [${doc.id}] — toolName = "${title}"`);
        batch.update(doc.ref, { toolName: title });
        updateCount++;
    }

    if (updateCount === 0) {
        console.log('\nAll ratings already have toolName. Nothing to update.');
        return;
    }

    console.log(`\nCommitting ${updateCount} update(s)...`);
    await batch.commit();
    console.log(`Done. Updated: ${updateCount}, Skipped: ${skipCount}`);
}

migrate().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
});