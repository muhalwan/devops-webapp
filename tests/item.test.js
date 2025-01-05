const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const Item = require('../src/models/Item');
const env = require('../src/config/env');

const { DATABASE_URL } = env;

beforeAll(async () => {
  await mongoose.connect(DATABASE_URL, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
});

afterAll(async () => {
  await mongoose.connection.close();
});

beforeEach(async () => {
  // Clear the database before each test
  await Item.deleteMany({});
});

describe('Item API Endpoints', () => {
  describe('POST /api/items', () => {
    it('should create a new item', async () => {
      const res = await request(app)
        .post('/api/items')
        .send({
          name: 'Test Item',
          description: 'This is a test item',
        });
      expect(res.statusCode).toEqual(201);
      expect(res.body).toHaveProperty('_id');
      expect(res.body.name).toBe('Test Item');
      expect(res.body.description).toBe('This is a test item');
    });

    it('should return validation error if name is missing', async () => {
      const res = await request(app).post('/api/items').send({
        description: 'Missing name field',
      });
      expect(res.statusCode).toEqual(400);
      expect(res.body).toHaveProperty('errors');
      expect(res.body.errors[0].msg).toBe('Name is required');
    });
  });

  describe('GET /api/items', () => {
    it('should retrieve all items', async () => {
      await Item.create([
        { name: 'Item 1', description: 'Description 1' },
        { name: 'Item 2', description: 'Description 2' },
      ]);

      const res = await request(app).get('/api/items');
      expect(res.statusCode).toEqual(200);
      expect(res.body.length).toBe(2);
      expect(res.body[0].name).toBe('Item 1');
      expect(res.body[1].name).toBe('Item 2');
    });
  });

  describe('GET /api/items/:id', () => {
    it('should retrieve a single item by ID', async () => {
      const item = await Item.create({ name: 'Single Item', description: 'Single Description' });
      const res = await request(app).get(`/api/items/${item._id}`);
      expect(res.statusCode).toEqual(200);
      expect(res.body.name).toBe('Single Item');
      expect(res.body.description).toBe('Single Description');
    });

    it('should return 404 if item not found', async () => {
      const nonExistentId = new mongoose.Types.ObjectId();
      const res = await request(app).get(`/api/items/${nonExistentId}`);
      expect(res.statusCode).toEqual(404);
      expect(res.body.message).toBe('Item not found');
    });

    it('should return 500 for invalid ID format', async () => {
      const res = await request(app).get('/api/items/invalid-id');
      expect(res.statusCode).toEqual(500);
      expect(res.body.message).toBe('Internal Server Error');
    });
  });

  describe('PATCH /api/items/:id', () => {
    it('should update an existing item', async () => {
      const item = await Item.create({ name: 'Old Name', description: 'Old Description' });
      const res = await request(app)
        .patch(`/api/items/${item._id}`)
        .send({ name: 'New Name' });
      expect(res.statusCode).toEqual(200);
      expect(res.body.name).toBe('New Name');
      expect(res.body.description).toBe('Old Description');
    });

    it('should return 404 if item to update is not found', async () => {
      const nonExistentId = new mongoose.Types.ObjectId();
      const res = await request(app)
        .patch(`/api/items/${nonExistentId}`)
        .send({ name: 'Updated Name' });
      expect(res.statusCode).toEqual(404);
      expect(res.body.message).toBe('Item not found');
    });

    it('should return validation error for invalid data', async () => {
      const item = await Item.create({ name: 'Valid Name', description: 'Valid Description' });
      const res = await request(app)
        .patch(`/api/items/${item._id}`)
        .send({ name: '' }); // Empty name
      expect(res.statusCode).toEqual(400);
      expect(res.body).toHaveProperty('errors');
      expect(res.body.errors[0].msg).toBe('Name cannot be empty');
    });
  });

  describe('DELETE /api/items/:id', () => {
    it('should delete an existing item', async () => {
      const item = await Item.create({ name: 'Delete Item', description: 'To be deleted' });
      const res = await request(app).delete(`/api/items/${item._id}`);
      expect(res.statusCode).toEqual(200);
      expect(res.body.message).toBe('Item deleted successfully');

      // Verify deletion
      const deletedItem = await Item.findById(item._id);
      expect(deletedItem).toBeNull();
    });

    it('should return 404 if item to delete is not found', async () => {
      const nonExistentId = new mongoose.Types.ObjectId();
      const res = await request(app).delete(`/api/items/${nonExistentId}`);
      expect(res.statusCode).toEqual(404);
      expect(res.body.message).toBe('Item not found');
    });
  });
});