const express = require('express');
const { postComment, getComments, deleteComment } = require('../controller/comment');
const router = express.Router();


router.post('/createComment/:postId', postComment)
router.get('/getComments/:postId', getComments)
router.delete('/deleteComment/:commentId', deleteComment)

module.exports = router;