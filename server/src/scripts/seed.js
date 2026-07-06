require('dotenv').config({ path: '../../.env' });
const mongoose = require('mongoose');
const crypto = require('crypto');
const User = require('../models/User');
const Document = require('../models/Document');
const Annotation = require('../models/Annotation');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/collaborative-docs';

const seedData = async () => {
  console.log('Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected.');

  console.log('Cleaning up existing database records...');
  await Promise.all([
    User.deleteMany({}),
    Document.deleteMany({}),
    Annotation.deleteMany({})
  ]);

  // 1. Create default users
  console.log('Seeding default collaborative users...');

  const hashPassword = (password, salt) => {
    return crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  };

  const generateSalt = () => {
    return crypto.randomBytes(16).toString('hex');
  };

  const usersData = [
    { name: 'Virat', email: 'virat@gmail.com', password: 'virat123' },
    { name: 'Rohit', email: 'rohit@gmail.com', password: 'rohit123' },
    { name: 'Rahul', email: 'rahul@gmail.com', password: 'rahul123' },
    { name: 'Dhoni', email: 'dhoni@gmail.com', password: 'dhoni123' }
  ].map(u => {
    const salt = generateSalt();
    return {
      name: u.name,
      email: u.email,
      salt,
      passwordHash: hashPassword(u.password, salt)
    };
  });

  const users = await User.insertMany(usersData);
  console.log(`Seeded ${users.length} users successfully.`);

  // 2. Create test document
  const textContent = Array(100).fill(
    "The quick brown fox jumps over the lazy dog. Real-time collaborative annotation systems need to be fast and performant. " +
    "This text acts as a placeholder for a large document with more than one thousand annotations. " +
    "Overlapping annotations and indexing are critical performance metrics."
  ).join("\n\n");

  const doc = new Document({
    title: '1000+ Annotations Test Performance Document',
    originalFilename: 'perf-test.txt',
    mimeType: 'text/plain',
    storagePath: 'dummy-path.txt',
    size: Buffer.byteLength(textContent, 'utf8'),
    extractedText: textContent,
    pages: [],
    uploadedBy: users[0]._id // Uploaded by Virat
  });
  await doc.save();
  console.log(`Document created with ID: ${doc._id}, Text Length: ${textContent.length} characters.`);

  // 3. Generate 1000+ annotations
  console.log('Generating 1000 annotations...');
  const annotations = [];
  const start = Date.now();

  for (let i = 0; i < 1000; i++) {
    // Select a random user
    const randomUser = users[Math.floor(Math.random() * users.length)];

    // Distribute startOffsets evenly across text length, but overlap them sometimes
    const startOffset = Math.floor(Math.random() * (textContent.length - 50));
    const length = Math.floor(Math.random() * 30) + 10;
    const endOffset = startOffset + length;
    const selectedText = textContent.substring(startOffset, endOffset);

    annotations.push({
      documentId: doc._id,
      userId: randomUser._id,
      userName: randomUser.name,
      pageNumber: null,
      startOffset,
      endOffset,
      selectedText,
      comment: `Performance testing comment index #${i} by ${randomUser.name}`,
      createdAt: new Date(Date.now() - (1000 - i) * 60000), // Chronological ordering for testing
      updatedAt: new Date(Date.now() - (1000 - i) * 60000)
    });
  }

  // Insert annotations bulk (avoids individual roundtrips, handles indexes!)
  try {
    const result = await Annotation.insertMany(annotations, { ordered: false });
    console.log(`Successfully seeded ${result.length} annotations in ${Date.now() - start}ms.`);
  } catch (err) {
    // ordered: false allows inserting non-duplicates even if some duplicate key collisions happen
    console.log(`Seeding finished. Inserted ${err.insertedDocs?.length || 0} annotations. Errors (e.g. duplicate key collisions): ${err.writeErrors?.length || 0}`);
  }

  // 4. Test Query performance with index
  console.log('Testing query performance with indexing...');
  const qStart = Date.now();
  const fetched = await Annotation.find({ documentId: doc._id }).sort({ startOffset: 1 }).exec();
  const qEnd = Date.now();

  console.log(`Fetched and sorted ${fetched.length} annotations in ${qEnd - qStart}ms!`);

  // Print execution stats
  const explain = await Annotation.find({ documentId: doc._id }).sort({ startOffset: 1 }).explain('executionStats');
  const stage = explain.queryPlanner?.winningPlan?.inputStage?.stage || explain.queryPlanner?.winningPlan?.stage;
  console.log(`Query execution stage: ${stage} (Should be IXSCAN if indexing is utilized)`);

  await mongoose.disconnect();
  console.log('Disconnected.');
};

seedData().catch(err => {
  console.error('Seeding failed:', err);
  mongoose.disconnect();
});
