const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { asyncHandler } = require('../middleware/errorHandler');

const JWT_SECRET = process.env.JWT_SECRET || 'fallback_secret_key';

// GET /api/auth/users - list seeded users for frontend dropdown selector
router.get('/users', asyncHandler(async (req, res) => {
  const users = await User.find({}, 'name email');
  res.json(users);
}));

const crypto = require('crypto');

// POST /api/auth/login - authenticate user with email and password
router.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required' });
  }

  const user = await User.findOne({ email });
  if (!user) {
    return res.status(401).json({ message: 'Invalid email or password' });
  }

  const hashPassword = (pass, salt) => {
    return crypto.pbkdf2Sync(pass, salt, 1000, 64, 'sha512').toString('hex');
  };

  const calculatedHash = hashPassword(password, user.salt);
  if (calculatedHash !== user.passwordHash) {
    return res.status(401).json({ message: 'Invalid email or password' });
  }

  const token = jwt.sign(
    { id: user._id, email: user.email, name: user.name },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  res.json({
    token,
    user: {
      id: user._id,
      name: user.name,
      email: user.email
    }
  });
}));

// POST /api/auth/register - register a new user
router.post('/register', asyncHandler(async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ message: 'All fields are required' });
  }

  const existingUser = await User.findOne({ email });
  if (existingUser) {
    return res.status(400).json({ message: 'User already exists' });
  }

  const salt = crypto.randomBytes(16).toString('hex');
  const passwordHash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');

  const newUser = new User({
    name,
    email,
    passwordHash,
    salt
  });

  await newUser.save();

  const token = jwt.sign(
    { id: newUser._id, email: newUser.email, name: newUser.name },
    JWT_SECRET,
    { expiresIn: '7d' }
  );

  res.status(201).json({
    token,
    user: {
      id: newUser._id,
      name: newUser.name,
      email: newUser.email
    }
  });
}));

module.exports = router;
