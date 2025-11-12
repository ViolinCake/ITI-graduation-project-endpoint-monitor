const redis = require('redis');

let redisClient = null;
let isRedisConnected = false;

/**
 * Connect to Redis server
 */
const connectRedis = async () => {
  try {
    const redisConfig = {
      host: process.env.REDIS_HOST || 'localhost',
      port: process.env.REDIS_PORT || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
      db: process.env.REDIS_DB || 0,
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
    };

    console.log(
      `🔌 Connecting to Redis at ${redisConfig.host}:${redisConfig.port}...`
    );

    redisClient = redis.createClient(redisConfig);

    redisClient.on('error', (err) => {
      console.error('❌ Redis Client Error:', err);
      isRedisConnected = false;
    });

    redisClient.on('connect', () => {
      console.log('✅ Redis connected successfully');
      isRedisConnected = true;
    });

    redisClient.on('reconnecting', () => {
      console.log('🔄 Redis reconnecting...');
      isRedisConnected = false;
    });

    redisClient.on('end', () => {
      console.log('🔌 Redis connection closed');
      isRedisConnected = false;
    });

    await redisClient.connect();

    return true;
  } catch (error) {
    console.error('❌ Failed to connect to Redis:', error.message);
    isRedisConnected = false;
    return false;
  }
};

/**
 * Get value from Redis cache
 */
const getCache = async (key) => {
  if (!isRedisConnected || !redisClient) {
    return null;
  }

  try {
    const value = await redisClient.get(key);
    return value ? JSON.parse(value) : null;
  } catch (error) {
    console.error(`❌ Redis GET error for key "${key}":`, error.message);
    return null;
  }
};

/**
 * Set value in Redis cache with optional TTL
 */
const setCache = async (key, value, ttl = 300) => {
  if (!isRedisConnected || !redisClient) {
    return false;
  }

  try {
    const stringValue = JSON.stringify(value);
    if (ttl) {
      await redisClient.setEx(key, ttl, stringValue);
    } else {
      await redisClient.set(key, stringValue);
    }
    return true;
  } catch (error) {
    console.error(`❌ Redis SET error for key "${key}":`, error.message);
    return false;
  }
};

/**
 * Delete value from Redis cache
 */
const deleteCache = async (key) => {
  if (!isRedisConnected || !redisClient) {
    return false;
  }

  try {
    await redisClient.del(key);
    return true;
  } catch (error) {
    console.error(`❌ Redis DELETE error for key "${key}":`, error.message);
    return false;
  }
};

/**
 * Clear all cache (use with caution)
 */
const clearCache = async () => {
  if (!isRedisConnected || !redisClient) {
    return false;
  }

  try {
    await redisClient.flushDb();
    console.log('🧹 Redis cache cleared');
    return true;
  } catch (error) {
    console.error('❌ Redis FLUSH error:', error.message);
    return false;
  }
};

/**
 * Check if Redis is connected and healthy
 */
const checkRedisHealth = async () => {
  if (!isRedisConnected || !redisClient) {
    return { status: 'disconnected', message: 'Redis client not connected' };
  }

  try {
    await redisClient.ping();
    return { status: 'healthy', message: 'Redis is connected and responsive' };
  } catch (error) {
    return { status: 'error', message: error.message };
  }
};

/**
 * Close Redis connection
 */
const closeRedis = async () => {
  if (redisClient) {
    try {
      await redisClient.quit();
      console.log('✅ Redis connection closed gracefully');
    } catch (error) {
      console.error('❌ Error closing Redis connection:', error.message);
    }
  }
};

module.exports = {
  connectRedis,
  getCache,
  setCache,
  deleteCache,
  clearCache,
  checkRedisHealth,
  closeRedis,
  getClient: () => redisClient,
  isConnected: () => isRedisConnected,
};
