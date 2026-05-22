const cluster = require('cluster');
const os = require('os');
const path = require('path');

const isProduction = process.env.NODE_ENV === 'production';
const CLUSTER_ENABLED = process.env.CLUSTER_ENABLED !== 'false' && isProduction;
const WORKER_COUNT = parseInt(process.env.WORKER_COUNT || '0', 10) || os.cpus().length;

if (CLUSTER_ENABLED && cluster.isPrimary) {
  const numWorkers = Math.min(WORKER_COUNT, os.cpus().length);
  console.log(`Primary process starting ${numWorkers} workers...`);

  for (let i = 0; i < numWorkers; i++) {
    cluster.fork();
  }

  cluster.on('exit', (worker, code, signal) => {
    console.warn(`Worker ${worker.process.pid} died (code=${code}, signal=${signal}). Restarting...`);
    cluster.fork();
  });

  cluster.on('disconnect', (worker) => {
    console.warn(`Worker ${worker.process.pid} disconnected.`);
  });

  process.on('SIGTERM', () => {
    console.log('Primary received SIGTERM, shutting down workers...');
    for (const id in cluster.workers) {
      cluster.workers[id].kill();
    }
    process.exit(0);
  });

  process.on('SIGINT', () => {
    console.log('Primary received SIGINT, shutting down workers...');
    for (const id in cluster.workers) {
      cluster.workers[id].kill();
    }
    process.exit(0);
  });
} else {
  require('./server');
}
