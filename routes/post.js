const express = require('express');
const { createPost, deletePost } = require('../controller/post');
const { authenticate } = require('../middleware/auth');
const router = express.Router();

router.post('/', authenticate, createPost);
router.delete('/:postId', authenticate, deletePost);

module.exports = router;