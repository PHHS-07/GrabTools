const { GoogleGenerativeAI } = require('@google/generative-ai');
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * AI proxy cloud function
 * Accepts JSON body with fields like:
 * - prompt (string) OR messages (array) OR input/text
 * - imageUrl (optional)
 * - categories (optional array)
 *
 * Returns { text: "<assistant reply>" } on success.
 */
exports.aiProxy = async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Only POST allowed' });
    }

    let body = req.body || {};
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (_) {
        body = { prompt: body };
      }
    }

    const prompt = (
      body.prompt ||
      (body.messages &&
        Array.isArray(body.messages) &&
        body.messages.map((m) => m.content || '').join('\n')) ||
      body.input ||
      body.text ||
      ''
    )
      .toString()
      .trim();

    const categories = Array.isArray(body.categories) ? body.categories : [];
    if (!prompt) {
      return res.status(400).json({ error: 'Missing prompt' });
    }

    // Do not hardcode secrets in source code.
    const genKey =
      process.env.GENERATIVE_API_KEY ||
      process.env.GEMINI_API_KEY ||
      process.env.GEMINI_KEY;
    const modelName = process.env.GEMINI_MODEL || 'gemini-2-flash';

    if (!genKey) {
      return res.status(503).json({
        error: 'AI service misconfigured',
        code: 'AI_API_KEY_MISSING',
        message: 'Missing GENERATIVE_API_KEY on aiProxy function.',
      });
    }

    try {
      const client = new GoogleGenerativeAI(genKey);
      const model = client.getGenerativeModel({ model: modelName });
      const fullPrompt = `${prompt}\n\nAvailable categories: ${categories.join(', ')}`;

      const result = await model.generateContent(fullPrompt);
      const response = await result.response;
      return res.status(200).json({ text: response.text() });
    } catch (apiErr) {
      const message = `${apiErr?.message || apiErr || ''}`;
      const invalidKey =
        message.includes('API_KEY_INVALID') ||
        message.toLowerCase().includes('api key not valid');

      console.error('Google Generative AI error:', apiErr);
      return res.status(502).json({
        error: 'Upstream model error',
        code: invalidKey ? 'AI_API_KEY_INVALID' : 'AI_UPSTREAM_ERROR',
        message: invalidKey
          ? 'Gemini API key is invalid. Set a valid GENERATIVE_API_KEY on the function.'
          : 'AI provider request failed. Check function logs for details.',
      });
    }
  } catch (err) {
    console.error('aiProxy error:', err && err.stack ? err.stack : err);
    return res.status(500).json({
      error: 'AI request failed',
      code: 'AI_INTERNAL_ERROR',
      message: err?.message || 'Unexpected server error',
    });
  }
};

exports.updateRankingScore = functions.firestore
    .document('tools/{toolId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        
        const trustScore = newData.ownerTrustScore || 0;
        const rating = newData.ratingScore || 0;
        const activity = newData.bookingCount || 0;
        
        const newRankingScore = (trustScore * 0.4) + (rating * 0.3) + (activity * 0.2);

        if (Math.abs((newData.rankingScore || 0) - newRankingScore) < 0.01) {
            return null; // prevent infinite loops
        }

        return change.after.ref.update({ rankingScore: newRankingScore });
    });

exports.expireUnconfirmedBookings = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const expiryLimit = new Date(now.getTime() - (24 * 60 * 60 * 1000));

    const snapshot = await db.collection('bookings')
        .where('status', '==', 'approved')
        .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(expiryLimit))
        .get();

    if (snapshot.empty) return null;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
            status: 'expired',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
    });

    await batch.commit();
    return null;
});
