const dotenv = require('dotenv');
const Joi = require('joi');

const envFile = process.env.NODE_ENV === 'production'
  ? '.env.production'
  : process.env.NODE_ENV === 'test'
    ? '.env.test'
    : '.env.development';

const result = dotenv.config({ path: envFile });

if (result.error) {
  throw new Error(`Failed to load ${envFile}: ${result.error}`);
}

const envSchema = Joi.object({
  PORT: Joi.number().default(3000),
  DATABASE_URL: Joi.string().uri().required(),
  NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
}).unknown().required();

const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}

module.exports = envVars;