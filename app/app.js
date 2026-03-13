const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head><title>DevSecOps Demo App</title>
      <style>
        body { font-family: Arial, sans-serif; background: #0d1117; color: #58a6ff; 
               display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: #161b22; border: 1px solid #30363d; border-radius: 12px; 
                padding: 40px; text-align: center; max-width: 500px; }
        h1 { color: #f0f6fc; } p { color: #8b949e; }
        .badge { background: #238636; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px; }
      </style>
      </head>
      <body>
        <div class="card">
          <h1>DevSecOps Demo</h1>
          <p>Node.js App running in Docker</p>
          <span class="badge">✅ Secured & Deployed</span>
          <p style="margin-top:20px">Host: ${process.env.HOSTNAME || 'localhost'}</p>
        </div>
      </body>
    </html>
  `);
});

app.get('/health', (req, res) => res.json({ status: 'healthy', timestamp: new Date() }));

app.listen(PORT, () => console.log(`App running on port ${PORT}`));
