const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'grabtools-07' });

async function makeAdmin(email) {
  try {
    // Get user from authentication to find UID
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;
    console.log(`Found UID for ${email}: ${uid}`);

    // Update role in Firestore database
    const userRef = admin.firestore().collection('users').doc(uid);
    await userRef.update({ role: 'admin' });
    
    console.log(`Successfully upgraded ${email} to Admin!`);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log(`Error: User with email ${email} not found in Firebase Auth.`);
    } else {
      console.error('Error making user admin:', error);
    }
  } finally {
    process.exit();
  }
}

makeAdmin('phariharasudhan2004@gmail.com');
