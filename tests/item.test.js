const request = require('supertest');
const app = require('../src/app');
const Item = require('../src/models/Item');
const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');

let mongoServer;

// Mock console.error to suppress validation and error logs during tests
beforeAll(async () => {
  jest.spyOn(console, 'error').mockImplementation(() => {});
  mongoServer = await MongoMemoryServer.create();
  const uri = mongoServer.getUri();
  await mongoose.connect(uri, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
});

// Restore console.error and disconnect from the database after tests
afterAll(async () => {
  console.error.mockRestore();
  await mongoose.disconnect();
  await mongoServer.stop();
});

describe('Item API Endpoints', () => {
  // Clear the database before each test
  beforeEach(async () => {
    await Item.deleteMany({});
  });

  /**
   * Test POST /api/items
   */
  describe('POST /api/items', () => {
    it('should create a new item', async () => {
      const newItem = {
        name: 'Test Item',
        description: 'This is a test item.',
      };

      const res = await request(app)
          .post('/api/items')
          .send(newItem)
          .expect(201);

      expect(res.body).toHaveProperty('_id');
      expect(res.body.name).toBe(newItem.name);
      expect(res.body.description).toBe(newItem.description);
    }, 30000); // Increase timeout to 30 seconds

    it('should return validation error if name is missing', async () => {
      const newItem = {
        description: 'Missing name field.',
      };

      const res = await request(app)
          .post('/api/items')
          .send(newItem)
          .expect(400);

      expect(res.body.errors).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              msg: 'Name is required',
              path: 'name',
            }),
          ])
      );
    }, 30000); // Increase timeout to 30 seconds
  });

  /**
   * Test GET /api/items
   */
  describe('GET /api/items', () => {
    it('should retrieve all items', async () => {
      const items = [
        { name: 'Item 1', description: 'Description 1' },
        { name: 'Item 2', description: 'Description 2' },
      ];

      await Item.insertMany(items);

      const res = await request(app)
          .get('/api/items')
          .expect(200);

      expect(res.body.length).toBe(2);
      expect(res.body[0].name).toBe(items[0].name);
      expect(res.body[1].name).toBe(items[1].name);
    }, 30000); // Increase timeout to 30 seconds
  });

  /**
   * Test GET /api/items/:id
   */
  describe('GET /api/items/:id', () => {
    it('should retrieve a single item by ID', async () => {
      const item = new Item({ name: 'Single Item', description: 'Single Description' });
      await item.save();

      const res = await request(app)
          .get(`/api/items/${item._id}`)
          .expect(200);

      expect(res.body.name).toBe(item.name);
      expect(res.body.description).toBe(item.description);
    }, 30000); // Increase timeout to 30 seconds

    it('should return 404 if item not found', async () => {
      const nonExistentId = '507f1f77bcf86cd799439011'; // Valid ObjectId format

      const res = await request(app)
          .get(`/api/items/${nonExistentId}`)
          .expect(404);

      expect(res.body).toHaveProperty('message', 'Item not found');
    }, 30000); // Increase timeout to 30 seconds

    it('should return 500 for invalid ID format', async () => {
      const invalidId = 'invalid-id';

      const res = await request(app)
          .get(`/api/items/${invalidId}`)
          .expect(500);

      expect(res.body).toHaveProperty('message', 'Internal Server Error');
    }, 30000); // Increase timeout to 30 seconds
  });

  /**
   * Test PATCH /api/items/:id
   */
  describe('PATCH /api/items/:id', () => {
    it('should update an existing item', async () => {
      const item = new Item({ name: 'Old Name', description: 'Old Description' });
      await item.save();

      const updatedData = { name: 'New Name' };

      const res = await request(app)
          .patch(`/api/items/${item._id}`)
          .send(updatedData)
          .expect(200);

      expect(res.body.name).toBe(updatedData.name);
      expect(res.body.description).toBe(item.description); // Unchanged
    }, 30000); // Increase timeout to 30 seconds

    it('should return 404 if item to update is not found', async () => {
      const nonExistentId = '507f1f77bcf86cd799439011';

      const res = await request(app)
          .patch(`/api/items/${nonExistentId}`)
          .send({ name: 'Updated Name' })
          .expect(404);

      expect(res.body).toHaveProperty('message', 'Item not found');
    }, 30000); // Increase timeout to 30 seconds

    it('should return validation error for invalid data', async () => {
      const item = new Item({ name: 'Valid Name', description: 'Valid Description' });
      await item.save();

      const res = await request(app)
          .patch(`/api/items/${item._id}`)
          .send({ name: '' }) // Empty name
          .expect(400);

      expect(res.body.errors).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              msg: 'Name cannot be empty',
              path: 'name',
            }),
          ])
      );
    }, 30000); // Increase timeout to 30 seconds
  });

  /**
   * Test DELETE /api/items/:id
   */
  describe('DELETE /api/items/:id', () => {
    it('should delete an existing item', async () => {
      const item = new Item({ name: 'To Be Deleted', description: 'To Be Deleted Description' });
      await item.save();

      const res = await request(app)
          .delete(`/api/items/${item._id}`)
          .expect(200);

      expect(res.body).toHaveProperty('message', 'Item deleted successfully');

      // Verify deletion
      const foundItem = await Item.findById(item._id);
      expect(foundItem).toBeNull();
    }, 30000); // Increase timeout to 30 seconds

    it('should return 404 if item to delete is not found', async () => {
      const nonExistentId = '507f1f77bcf86cd799439011';

      const res = await request(app)
          .delete(`/api/items/${nonExistentId}`)
          .expect(404);

      expect(res.body).toHaveProperty('message', 'Item not found');
    }, 30000); // Increase timeout to 30 seconds
  });
});