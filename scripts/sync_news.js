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

// Each category has its own distinct, non-repeating high-res photo
const SLOTS = [
  {
    category: 'BIBLICAL & PROPHECY',
    urls: [
      'https://www.prophecynewswatch.com/rss.xml',
      'https://www.christianpost.com/rss/news.xml',
    ],
    fallbackImage: 'https://images.unsplash.com/photo-1544967082-d9d25d867d66?auto=format&fit=crop&w=800&q=80', // Ancient Jerusalem Mount
    fallback: {
      title: 'Jerusalem and Prophetic Milestones: Understanding the Times',
      link: 'https://israel365news.com',
      snippet: 'Key insights into prophetic declarations, scripture fulfillments, and covenant promises unfolding across the Holy Land.',
      fullContent: 'Exploring ancient biblical scriptures in light of modern geopolitical developments in Jerusalem and the wider Middle East.',
      sourceName: 'Biblical Prophecy Watch',
    }
  },
  {
    category: 'ARCHAEOLOGY & HISTORY',
    urls: [
      'https://www.biblicalarchaeology.org/feed/',
    ],
    fallbackImage: 'https://images.unsplash.com/photo-1579606032834-d17208d270b2?auto=format&fit=crop&w=800&q=80', // Ancient excavated ruins & stone pillars
    fallback: {
      title: 'Excavations in the City of David Uncover Second Temple Structures',
      link: 'https://www.biblicalarchaeology.org',
      snippet: 'Archaeological discoveries in Jerusalem reveal pristine masonry and stone vessels confirming biblical accounts of the ancient temple.',
      fullContent: 'Recent digs near the Gihon Spring and the Pilgrimage Road continue to bring physical confirmation to ancient biblical narratives.',
      sourceName: 'Biblical Archaeology',
    }
  },
  {
    category: 'WAR & REGION UPDATES',
    urls: [
      'https://www.jpost.com/rss/rssfeedsisraelnews.aspx',
    ],
    fallbackImage: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=800&q=80', // Regional security & radar vigilance
    fallback: {
      title: 'IDF and Regional Defense: Northern and Southern Border Monitoring',
      link: 'https://www.jpost.com',
      snippet: 'Security forces maintain high readiness across multiple fronts as regional diplomacy and tactical maneuvers continue.',
      fullContent: 'Comprehensive coverage of regional security measures, defense strategies, and coalition movements in Israel.',
      sourceName: 'Middle East Defense',
    }
  },
  {
    category: 'CHRISTIAN WORLD & FAITH',
    urls: [
      'https://www.jpost.com/rss/rssfeedschristiannews.aspx',
      'https://www.christianpost.com/rss/faith.xml',
    ],
    fallbackImage: 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?auto=format&fit=crop&w=800&q=80', // Sunrise prayer & fellowship olive grove
    fallback: {
      title: 'Believers Unite in Prayer for the Peace of Jerusalem',
      link: 'https://www.jpost.com/christianworld',
      snippet: 'Global fellowships and ministries assemble worldwide to stand with biblical covenants and support communities across the region.',
      fullContent: 'Christian organizations and fellowship leaders worldwide dedicate prayer initiatives focused on Israel and global church renewal.',
      sourceName: 'Christian World News',
    }
  },
  {
    category: 'ISRAEL & NATION',
    urls: [
      'https://www.timesofisrael.com/feed/',
    ],
    fallbackImage: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=800&q=80', // Historic Jerusalem stone gate & modern city
    fallback: {
      title: 'Nationwide Developments Across Jerusalem and the Galilee',
      link: 'https://www.timesofisrael.com',
      snippet: 'Economic innovation, infrastructure progress, and community life thrive across Israel despite ongoing regional complexities.',
      fullContent: 'A direct look into civil updates, technological leadership, and community resilience from Jerusalem to the Golan.',
      sourceName: 'Times of Israel',
    }
  },
];

const BLACKLIST = ['sport', 'game', 'football', 'soccer', 'basketball', 'tennis', 'olympic', 'celebrity', 'hollywood', 'entertainment', 'gaming'];

function isBlacklisted(text) {
  if (!text) return false;
  const lower = text.toLowerCase();
  return BLACKLIST.some(word => lower.includes(word));
}

function extractImageUrl(item) {
  if (item.enclosure?.url) return item.enclosure.url;
  if (item.mediaContent?.$?.url) return item.mediaContent.$.url;

  const html = `${item.contentEncoded || ''} ${item.content || ''} ${item.description || ''}`;
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? match[1] : null;
}

async function fetchSlot(slot, usedImages) {
  for (const url of slot.urls) {
    try {
      console.log(`[${slot.category}] Checking: ${url}`);
      const feedData = await parser.parseURL(url);

      for (const item of feedData.items) {
        const title = (item.title || '').trim();
        const snippet = (item.contentSnippet || item.summary || item.content || '').replace(/<[^>]*>?/gm, '').slice(0, 220).trim();

        if (isBlacklisted(title) || isBlacklisted(snippet)) continue;

        let rawImg = extractImageUrl(item);
        // Avoid repeating identical image URLs across cards
        if (!rawImg || usedImages.has(rawImg)) {
          rawImg = slot.fallbackImage;
        }

        usedImages.add(rawImg);

        return {
          title,
          link: item.link || '',
          snippet,
          fullContent: (item.contentEncoded || item.content || item.contentSnippet || snippet).trim(),
          pubDate: item.pubDate ? new Date(item.pubDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'Today',
          rawImage: rawImg,
          category: slot.category,
          sourceName: feedData.title?.slice(0, 24) || slot.fallback.sourceName,
        };
      }
    } catch (err) {
      console.warn(`[${slot.category}] ${url} skipped: ${err.message}`);
    }
  }

  usedImages.add(slot.fallbackImage);
  return {
    ...slot.fallback,
    rawImage: slot.fallbackImage,
    pubDate: 'Today',
    category: slot.category,
  };
}

async function run() {
  try {
    const finalSelected = [];
    const usedImages = new Set();

    for (const slot of SLOTS) {
      const article = await fetchSlot(slot, usedImages);
      finalSelected.push(article);
    }

    console.log(`Uploading ${finalSelected.length} distinct non-repeating images...`);
    const processedItems = [];

    for (let i = 0; i < finalSelected.length; i++) {
      const item = finalSelected[i];
      let secureUrl = item.rawImage;

      if (item.rawImage && item.rawImage.startsWith('http')) {
        try {
          console.log(`[${i + 1}/5] Cloudinary upload for [${item.category}]: "${item.title.slice(0, 28)}..."`);
          const uploadRes = await cloudinary.uploader.upload(item.rawImage, {
            folder: 'whats_new_news',
            transformation: [{ width: 800, height: 450, crop: 'fill', quality: 'auto', fetch_format: 'auto' }],
          });
          secureUrl = uploadRes.secure_url;
        } catch (uploadErr) {
          console.warn(`Cloudinary fallback for card ${i + 1}: ${uploadErr.message}`);
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
    console.log(`Successfully committed 5 uniquely styled cards to Firestore.`);
    process.exit(0);
  } catch (error) {
    console.error('Fatal execution error:', error);
    process.exit(1);
  }
}

run();
