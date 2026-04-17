/**
 * One-time migration: backfill toolRating for existing ratings missing it.
 *
 * Old ratings submitted before toolRating was added have toolRating=null.
 * This sets toolRating = behavior for those ratings so they show in
 * "Tool Ratings by Category" in My Ratings screen.
 *
 * Only updates ratings where:
 *   - toolRating is null/missing
 *   - recipientRole == 'lender' (seeker rated a lender — tool rating applies)
 *
 * Setup:
 *   1. Place in GrabTools/scripts/
 *   2. Ensure serviceAccountKey.json is present
 *   3. node migrate_tool_rating.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrate() {
    console.log('Fetching ratings where recipientRole == lender and toolRating is missing...');
    const snap = await db.collection('ratings')
        .where('recipientRole', '==', 'lender')
        .get();

    if (snap.empty) {
        console.log('No lender ratings found.');
        return;
    }

    console.log(`Found ${snap.size} lender rating(s). Processing...`);

    const batch = db.batch();
    let updateCount = 0;
    let skipCount = 0;

    for (const doc of snap.docs) {
        const data = doc.data();

        if (data.toolRating != null) {
            console.log(`  OK   [${doc.id}] — toolRating already set: ${data.toolRating}`);
            skipCount++;
            continue;
        }

        const behavior = data.behavior ?? 5;
        console.log(`  FIX  [${doc.id}] — toolRating = ${behavior} (from behavior)`);
        batch.update(doc.ref, { toolRating: behavior });
        updateCount++;
    }

    if (updateCount === 0) {
        console.log('\nAll ratings already have toolRating. Nothing to update.');
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