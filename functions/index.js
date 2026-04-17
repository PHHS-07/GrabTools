const { GoogleGenerativeAI } = require('@google/generative-ai');
const functions = require('firebase-functions');
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

// To download image data to feed to Gemini
async function fetchImageAsBase64(url) {
    const response = await fetch(url);
    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer).toString('base64');
}

exports.onToolCreated = functions.firestore
    .document('tools/{toolId}')
    .onCreate(async (change, context) => {
        const data = change.data();
        if (!data.imageUrls || data.imageUrls.length === 0) return null;
        
        const mainImageUrl = data.imageUrls[0];
        const proofImageUrl = data.proofImageUrl;
        
        let isSuspicious = false;
        let isVerified = false;

        const genKey = process.env.GENERATIVE_API_KEY || process.env.GEMINI_API_KEY || process.env.GEMINI_KEY || functions.config().gemini?.key;
        const modelName = process.env.GEMINI_MODEL || 'gemini-1.5-flash';

        try {
            if (!genKey) {
                console.error("Missing Gemini key.");
                return null;
            }

            const client = new GoogleGenerativeAI(genKey);
            const model = client.getGenerativeModel({ model: modelName });
            
            const promptParams = [
                { text: "Analyze if the first image looks like a real user-captured photo or a stock/internet image. Check for unnatural perfection, studio lighting, watermarks, or catalog-style presentation. Also analyze the second (proof) image to see if it shows a tool and handwritten words. Return simply 'FAKE' if it looks like a stock photo, internet image, or the proof is missing/invalid. Return 'REAL' if both look like authentic legitimate listings." }
            ];

            const mainB64 = await fetchImageAsBase64(mainImageUrl);
            promptParams.push({
                inlineData: { mimeType: "image/jpeg", data: mainB64 }
            });

            if (proofImageUrl) {
                const proofB64 = await fetchImageAsBase64(proofImageUrl);
                promptParams.push({
                    inlineData: { mimeType: "image/jpeg", data: proofB64 }
                });
            } else {
                isSuspicious = true;
            }

            if (!isSuspicious) {
              const result = await model.generateContent(promptParams);
              const responseText = result.response.text().toUpperCase();
              
              if (responseText.includes("FAKE")) {
                  isSuspicious = true;
              } else if (responseText.includes("REAL")) {
                  isVerified = true;
              }
            }

            await change.ref.update({
                isSuspicious,
                isVerified
            });

            if (isVerified && data.ownerId) {
                const userRef = admin.firestore().collection('users').doc(data.ownerId);
                await userRef.update({
                    trustScore: admin.firestore.FieldValue.increment(5)
                });
            }

        } catch (e) {
            console.error("Error running AI verification", e);
        }
    });

exports.onReportCreated = functions.firestore
    .document('reports/{reportId}')
    .onCreate(async (change, context) => {
        const data = change.data();
        const toolId = data.toolId;
        if (!toolId) return null;

        const db = admin.firestore();
        const reportsSnapshot = await db.collection('reports')
            .where('toolId', '==', toolId)
            .get();

        const count = reportsSnapshot.size;
        
        if (count >= 3) {
            const toolRef = db.collection('tools').doc(toolId);
            const toolDoc = await toolRef.get();
            
            if (toolDoc.exists) {
                await toolRef.update({
                    isSuspicious: true,
                    visibility: 'hidden'
                });

                const toolData = toolDoc.data();
                if (toolData.ownerId) {
                    const userRef = db.collection('users').doc(toolData.ownerId);
                    await userRef.update({
                        trustScore: admin.firestore.FieldValue.increment(-20)
                    });
                }
            }
        }
    });
