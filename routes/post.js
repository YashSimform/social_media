const express = require('express');
const { createPost } = require('../controller/post');
const router = express.Router();


router.post('/createPost', createPost)


module.exports = router;