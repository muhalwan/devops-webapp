const express = require('express');
const { body, validationResult } = require('express-validator');
const itemController = require('../controllers/itemController');

const router = express.Router();

/**
 * @route   POST /api/items
 * @desc    Create a new item
 * @access  Public
 */
router.post(
  '/items',
  [
    body('name')
      .notEmpty()
      .withMessage('Name is required')
      .trim()
      .escape(),
    body('description')
      .optional()
      .isString()
      .withMessage('Description must be a string')
      .trim()
      .escape(),
  ],
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌ Validation Errors:', errors.array());
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  },
  itemController.createItem
);

/**
 * @route   GET /api/items
 * @desc    Get all items
 * @access  Public
 */
router.get('/items', itemController.getAllItems);

/**
 * @route   GET /api/items/:id
 * @desc    Get a single item by ID
 * @access  Public
 */
router.get('/items/:id', itemController.getItemById);

/**
 * @route   PATCH /api/items/:id
 * @desc    Update an item by ID
 * @access  Public
 */
router.patch(
  '/items/:id',
  [
    body('name')
      .optional()
      .notEmpty()
      .withMessage('Name cannot be empty')
      .trim()
      .escape(),
    body('description')
      .optional()
      .isString()
      .withMessage('Description must be a string')
      .trim()
      .escape(),
  ],
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌ Validation Errors:', errors.array());
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  },
  itemController.updateItem
);

/**
 * @route   DELETE /api/items/:id
 * @desc    Delete an item by ID
 * @access  Public
 */
router.delete('/items/:id', itemController.deleteItem);

module.exports = router;
