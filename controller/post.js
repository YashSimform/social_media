const prisma = require('../lib/prisma');

const createPost = async (req, res) => {
  try {
    const { text, content } = req.body;
    if (!text || !content) {
      return res.status(400).json({ error: "Text and content are required" });
    }
    const post = await prisma.post.create({
      data: {
        text,
        content,
      },
    });
    res.status(201).json({
      message: "Post created successfully",
      post,
    });
  } catch (error) {
    console.error("Error creating post:", error);
    res
      .status(500)
      .json({ error: "An error occurred while creating the post" });
  }
};

module.exports = { createPost };
