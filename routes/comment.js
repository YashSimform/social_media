const express = require('express');
const { postComment, getComments, deleteComment } = require('../controller/comment');
const { authenticate } = require('../middleware/auth');
const router = express.Router();

router.post('/:postId', authenticate, postComment);
router.get('/:postId', getComments);
router.delete('/:commentId', authenticate, deleteComment);

module.exports = router;