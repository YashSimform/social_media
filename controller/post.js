const { z } = require("zod");
const prisma = require("../lib/prisma");

const createPostSchema = z.object({
  text: z.string().min(1, "Text is required"),
  content: z.string().min(1, "Content is required"),
});


async function createPost(req, res) {
  try {
    const validation = createPostSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(422).json({
        error: "Validation failed",
        details: validation.error.errors.map((e) => ({
          field: e.path.join("."),
          message: e.message,
        })),
      });
    }

    const { text, content } = validation.data;
    const post = await prisma.post.create({
      data: { text, content, userId: req.user.userId },
      select: { id: true, text: true, content: true, createdAt: true },
    });

    return res.status(201).json({
      message: "Post created successfully",
      post,
    });
  } catch (error) {
    console.error("Error creating post:", error);
    return res
      .status(500)
      .json({ error: "An error occurred while creating the post" });
  }
}

const deletePost = async (req, res) => {
  try {
    const { postId } = req.params;

    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { userId: true },
    });

    if (!post) {
      return res.status(404).json({ error: "Post not found." });
    }

    if (post.userId !== req.user.userId) {
      return res
        .status(403)
        .json({ error: "You are not authorized to delete this post." });
    }

    await prisma.post.delete({ where: { id: postId } });

    return res.status(200).json({ message: "Post deleted successfully." });
  } catch (error) {
    console.error("Error deleting post:", error);
    return res
      .status(500)
      .json({ error: "An error occurred while deleting the post." });
  }
};

module.exports = { createPost, deletePost };
