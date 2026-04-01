const express = require('express');
const router = express.Router();
const { register, login } = require('../controller/user');

// POST /users/register
router.post('/register', register);

// POST /users/login
router.post('/login', login);

module.exports = router;
