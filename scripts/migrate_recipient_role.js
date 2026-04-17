/**
 * One-time migration: fix recipientRole in existing ratings documents.
 *
 * Logic:
 *   - For each rating, look up its booking via bookingId
 *   - If rating.ownerId == booking.lenderId  → recipient was the lender → recipientRole = 'lender'
 *   - If rating.ownerId == booking.renterId  → recipient was the seeker → recipientRole = 'seeker'
 *
 * Setup:
 *   1. npm install firebase-admin
 *   2. Download your Firebase service account key from:
 *      Firebase Console → Project Settings → Service Accounts → Generate new private key
 *   3. Save it as serviceAccountKey.json in the same folder as this script
 *   4. node migrate_recipient_role.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrate() {
    console.log('Fetching all ratings...');
    const ratingsSnap = await db.collection('ratings').get();

    if (ratingsSnap.empty) {
        console.log('No ratings found. Nothing to migrate.');
        return;
    }

    console.log(`Found ${ratingsSnap.size} rating(s). Processing...`);

    // Cache bookings to avoid redundant fetches
    const bookingCache = {};

    async function getBooking(bookingId) {
        if (bookingCache[bookingId]) return bookingCache[bookingId];
        const snap = await db.collection('bookings').doc(bookingId).get();
        if (!snap.exists) return null;
        bookingCache[bookingId] = snap.data();
        return bookingCache[bookingId];
    }

    const batch = db.batch();
    let updateCount = 0;
    let skipCount = 0;
    let errorCount = 0;

    for (const doc of ratingsSnap.docs) {
        const rating = doc.data();
        const { bookingId, ownerId, recipientRole } = rating;

        if (!bookingId || !ownerId) {
            console.warn(`  SKIP [${doc.id}] — missing bookingId or ownerId`);
            skipCount++;
            continue;
        }

        const booking = await getBooking(bookingId);
        if (!booking) {
            console.warn(`  SKIP [${doc.id}] — booking "${bookingId}" not found`);
            skipCount++;
            continue;
        }

        let correctRole;
        if (ownerId === booking.lenderId) {
            correctRole = 'lender';
        } else if (ownerId === booking.renterId) {
            correctRole = 'seeker';
        } else {
            console.warn(`  SKIP [${doc.id}] — ownerId "${ownerId}" matches neither lenderId nor renterId in booking`);
            errorCount++;
            continue;
        }

        if (recipientRole === correctRole) {
            console.log(`  OK   [${doc.id}] — recipientRole already correct: "${correctRole}"`);
            skipCount++;
            continue;
        }

        console.log(`  FIX  [${doc.id}] — "${recipientRole}" → "${correctRole}"`);
        batch.update(doc.ref, { recipientRole: correctRole });
        updateCount++;
    }

    if (updateCount === 0) {
        console.log('\nAll ratings already have correct recipientRole. Nothing to update.');
        return;
    }

    console.log(`\nCommitting ${updateCount} update(s)...`);
    await batch.commit();
    console.log(`Done. Updated: ${updateCount}, Skipped: ${skipCount}, Errors: ${errorCount}`);
}

migrate().catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
});