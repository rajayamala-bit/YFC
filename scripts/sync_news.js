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

// Add browser headers so CDNs do not block requests with 403
const parser = new Parser({
  headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
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

// Robust, high-uptime feeds
const RSS_FEEDS = [
  { url: 'https://www.jpost.com/rss/rssfeedsisraelnews.aspx', category: 'ISRAEL & NATION', source: 'Jerusalem Post' },
  { url: 'https://www.timesofisrael.com/feed/', category: 'JERUSALEM & FAITH', source: 'Times of Israel' },
  { url: 'https://israel365news.com/feed/', category: 'PROPHECY & FAITH', source: 'Israel365' },
];

function extractImageUrl(item) {
  if (item.enclosure?.url) return item.enclosure.url;
  if (item.mediaContent?.$?.url) return item.mediaContent.$.url;

  const html = `${item.contentEncoded || ''} ${item.content || ''}`;
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? match[1] : null;
}

async function run() {
  try {
    let collectedItems = [];

    for (const feed of RSS_FEEDS) {
      try {
        console.log(`Fetching feed: ${feed.url}`);
        const feedData = await parser.parseURL(feed.url);
        console.log(`-> Received ${feedData.items.length} items from ${feed.source}`);

        for (const item of feedData.items.slice(0, 3)) {
          collectedItems.push({
            title: item.title?.trim() || '',
            link: item.link || '',
            snippet: (item.contentSnippet || item.summary || '').slice(0, 220).trim(),
            fullContent: (item.contentEncoded || item.content || item.contentSnippet || '').trim(),
            pubDate: item.pubDate ? new Date(item.pubDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'Today',
            rawImage: extractImageUrl(item),
            category: feed.category,
            sourceName: feed.source,
          });
        }
      } catch (err) {
        console.warn(`Warning: Failed to parse feed ${feed.url}: ${err.message}`);
      }
    }

    if (collectedItems.length === 0) {
      console.log('No new items retrieved. Exiting without updating Firestore.');
      return;
    }

    const top5 = collectedItems.slice(0, 5);
    const processedItems = [];

    for (let i = 0; i < top5.length; i++) {
      const item = top5[i];
      let secureUrl = '';

      if (item.rawImage) {
        try {
          console.log(`Uploading cover image to Cloudinary for: "${item.title.slice(0, 30)}..."`);
          const uploadRes = await cloudinary.uploader.upload(item.rawImage, {
            folder: 'whats_new_news',
            transformation: [{ width: 800, height: 450, crop: 'fill', quality: 'auto', fetch_format: 'auto' }],
          });
          secureUrl = uploadRes.secure_url;
        } catch (uploadErr) {
          console.warn(`Cloudinary upload failed for item ${i + 1}, using fallback: ${uploadErr.message}`);
          secureUrl = 'assets/images/carousel/jerusalem.jpg';
        }
      } else {
        secureUrl = 'assets/images/carousel/jerusalem.jpg';
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
    console.log(`Successfully synced ${processedItems.length} live articles to Firestore 'whats_new'.`);
    process.exit(0);
  } catch (error) {
    console.error('Fatal sync error:', error);
    process.exit(1);
  }
}

run();
