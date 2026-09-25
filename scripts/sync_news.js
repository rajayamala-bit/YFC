const admin = require('firebase-admin');
const Parser = require('rss-parser');
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}
const db = admin.firestore();

const parser = new Parser({
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/rss+xml, application/xml, text/xml; q=0.9, */*; q=0.8',
  },
  timeout: 10000,
  customFields: {
    item: [
      ['media:content', 'mediaContent'],
      ['enclosure', 'enclosure'],
      ['content:encoded', 'contentEncoded'],
    ],
  },
});

// Category Slots with primary and backup feed endpoints
const CATEGORY_SLOTS = [
  {
    category: 'BIBLICAL & PROPHECY',
    feeds: [
      { url: 'https://www2.cbn.com/rss-cbn-news-israel.xml', source: 'CBN News Israel' },
      { url: 'https://api.rss2json.com/v1/api.json?rss_url=https%3A%2F%2Fisrael365news.com%2Ffeed%2F', isJson: true, source: 'Israel365 News' }
    ]
  },
  {
    category: 'ARCHAEOLOGY & HISTORY',
    feeds: [
      { url: 'https://www.biblicalarchaeology.org/feed/', source: 'Biblical Archaeology' }
    ]
  },
  {
    category: 'WAR & REGION UPDATES',
    feeds: [
      { url: 'https://www.jpost.com/rss/rssfeedsisraelnews.aspx', source: 'Jerusalem Post' }
    ]
  },
  {
    category: 'CHRISTIAN WORLD & FAITH',
    feeds: [
      { url: 'https://www.jpost.com/rss/rssfeedschristiannews.aspx', source: 'Christian World News' }
    ]
  },
  {
    category: 'ISRAEL & NATION',
    feeds: [
      { url: 'https://www.timesofisrael.com/feed/', source: 'Times of Israel' }
    ]
  }
];

function extractImageUrl(item) {
  if (item.thumbnail) return item.thumbnail;
  if (item.enclosure?.url) return item.enclosure.url;
  if (item.mediaContent?.$?.url) return item.mediaContent.$.url;

  const html = `${item.contentEncoded || ''} ${item.content || ''} ${item.description || ''}`;
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? match[1] : null;
}

async function fetchFromSlot(slot) {
  for (const target of slot.feeds) {
    try {
      console.log(`[${slot.category}] Checking: ${target.source}`);
      if (target.isJson) {
        const response = await fetch(target.url);
        const data = await response.json();
        if (data.status === 'ok' && data.items && data.items.length > 0) {
          const item = data.items[0];
          return {
            title: (item.title || '').trim(),
            link: item.link || '',
            snippet: (item.description || '').replace(/<[^>]*>?/gm, '').slice(0, 220).trim(),
            fullContent: (item.content || item.description || '').trim(),
            pubDate: item.pubDate ? new Date(item.pubDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'Today',
            rawImage: item.thumbnail || extractImageUrl(item),
            category: slot.category,
            sourceName: target.source,
          };
        }
      } else {
        const feedData = await parser.parseURL(target.url);
        if (feedData.items && feedData.items.length > 0) {
          const item = feedData.items[0];
          return {
            title: (item.title || '').trim(),
            link: item.link || '',
            snippet: (item.contentSnippet || item.summary || item.content || '').replace(/<[^>]*>?/gm, '').slice(0, 220).trim(),
            fullContent: (item.contentEncoded || item.content || item.contentSnippet || '').trim(),
            pubDate: item.pubDate ? new Date(item.pubDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'Today',
            rawImage: extractImageUrl(item),
            category: slot.category,
            sourceName: target.source,
          };
        }
      }
    } catch (err) {
      console.warn(`Feed failed for ${target.source}: ${err.message}`);
    }
  }
  return null;
}

async function run() {
  try {
    const finalSelected = [];

    // Collect 1 article per category slot
    for (const slot of CATEGORY_SLOTS) {
      const article = await fetchFromSlot(slot);
      if (article) {
        finalSelected.push(article);
      }
    }

    if (finalSelected.length === 0) {
      console.log('No articles fetched. Skipping Firestore sync.');
      return;
    }

    console.log(`Successfully collected ${finalSelected.length}/5 category items. Starting Cloudinary upload...`);
    const processedItems = [];

    for (let i = 0; i < finalSelected.length; i++) {
      const item = finalSelected[i];
      let secureUrl = 'assets/images/carousel/jerusalem.jpg';

      if (item.rawImage) {
        try {
          console.log(`[${i + 1}/${finalSelected.length}] Uploading image for [${item.category}]: "${item.title.slice(0, 30)}..."`);
          const uploadRes = await cloudinary.uploader.upload(item.rawImage, {
            folder: 'whats_new_news',
            transformation: [{ width: 800, height: 450, crop: 'fill', quality: 'auto', fetch_format: 'auto' }],
          });
          secureUrl = uploadRes.secure_url;
        } catch (uploadErr) {
          console.warn(`Fallback image used for slot ${i + 1}: ${uploadErr.message}`);
        }
      }

      processedItems.push({
        order: i + 1,
        title: item.title,
        category: item.category,
        pubDate: item.pubDate,
        imageUrl: secureUrl,
        link: item.link,
        snippet: item.snippet,
        fullContent: item.fullContent,
        sourceName: item.sourceName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const collectionRef = db.collection('whats_new');
    const existing = await collectionRef.get();
    const batch = db.batch();

    existing.docs.forEach((doc) => batch.delete(doc.ref));
    processedItems.forEach((docData) => {
      const newRef = collectionRef.doc();
      batch.set(newRef, docData);
    });

    await batch.commit();
    console.log(`Successfully wrote ${processedItems.length} diverse items to Firestore.`);
    process.exit(0);
  } catch (error) {
    console.error('Fatal execution error:', error);
    process.exit(1);
  }
}

run();
