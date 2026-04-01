const prisma = require("../lib/prisma");

const postComment = async (req, res) => {
  try {
    const { postId } = req.params;
    const { content, parentId } = req.body;
    if (!content) {
      return res.status(400).json({ error: "Content is required" });
    }

    const comment = await prisma.comment.create({
      data: {
        content,
        postId,
        userId: req.user.userId,
        parentId: parentId || null,
      },
    });

    res.status(201).json({
      message: "Comment added successfully",
      comment,
    });
  } catch (error) {
    console.error("Error adding comment:", error);
    res
      .status(500)
      .json({ error: "An error occurred while adding the comment" });
  }
};

const getComments = async (req, res) => {
  try {
    const { postId } = req.params;

    const comments = await prisma.comment.findMany({
      where: { postId },
      orderBy: { createdAt: "asc" },
    });

    const commentMap = new Map();
    const rootComments = [];

    // Single pass: build map and tree simultaneously
    for (const comment of comments) {
      commentMap.set(comment.id, { ...comment, replies: [] });
    }
    for (const comment of comments) {
      const node = commentMap.get(comment.id);
      if (comment.parentId) {
        commentMap.get(comment.parentId)?.replies.push(node);
      } else {
        rootComments.push(node);
      }
    }

    res.status(200).json({
      message: "Comments retrieved successfully",
      comments: rootComments,
      totalCount: comments.length,
    });
  } catch (error) {
    console.error("Error retrieving comments:", error);
    res
      .status(500)
      .json({ error: "An error occurred while retrieving comments" });
  }
};

const deleteComment = async (req, res) => {
  try {
    const { commentId } = req.params;

    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      select: { userId: true },
    });

    if (!comment) {
      return res.status(404).json({ error: 'Comment not found.' });
    }

    if (comment.userId !== req.user.userId) {
      return res.status(403).json({ error: 'You are not authorized to delete this comment.' });
    }

    await prisma.comment.delete({ where: { id: commentId } });

    res.status(200).json({
      message: "Comment and its replies deleted successfully",
    });
  } catch (error) {
    console.error("Error deleting comment:", error);
    res
      .status(500)
      .json({ error: "An error occurred while deleting the comment" });
  }
};

module.exports = { postComment, getComments, deleteComment };
