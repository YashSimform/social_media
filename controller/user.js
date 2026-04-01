const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const prisma = require('../lib/prisma');

const SALT_ROUNDS = 12;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number'),
});

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

const formatValidationErrors = (error) =>
  error.errors.map((e) => ({ field: e.path.join('.'), message: e.message }));

const generateToken = (userId) =>
  jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

const register = async (req, res) => {
  try {
    const validation = registerSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(422).json({
        error: 'Validation failed',
        details: formatValidationErrors(validation.error),
      });
    }

    const { name, email, password } = validation.data;
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    // Single DB round trip — unique constraint violation handled via P2002
    const user = await prisma.user.create({
      data: { name, email, password: hashedPassword },
      select: { id: true, name: true, email: true, createdAt: true },
    });

    const token = generateToken(user.id);

    return res.status(201).json({
      message: 'User registered successfully.',
      user,
      token,
    });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(409).json({ error: 'Email is already registered.' });
    }
    console.error('Error in register:', error);
    return res.status(500).json({ error: 'An error occurred during registration.' });
  }
};

const login = async (req, res) => {
  try {
    const validation = loginSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(422).json({
        error: 'Validation failed',
        details: formatValidationErrors(validation.error),
      });
    }

    const { email, password } = validation.data;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const token = generateToken(user.id);

    return res.status(200).json({
      message: 'Login successful.',
      user: { id: user.id, name: user.name, email: user.email },
      token,
    });
  } catch (error) {
    console.error('Error in login:', error);
    return res.status(500).json({ error: 'An error occurred during login.' });
  }
};

module.exports = { register, login };
